#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, relative, isAbsolute, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createInterface } from 'node:readline/promises';
import { webcrypto } from 'node:crypto';
import { immutableJSON, canonicalJSON } from '../js/codec.js';
import publication from '../js/generated/publication.mjs';
const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SHA = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const HELP = `Worklog data setup. Requires Node 18+, Git and authenticated gh.
Usage: node scripts/setup.mjs [options]
  --repo owner/name   Default: authenticated user/worklog-data
  --private          New repository is private (default)
  --public           New repository is public
  --no-examples      Omit synthetic starter tasks
  --app-url URL      Default: https://devansh-ops.github.io/worklog-bend/
  --dry-run          Inspect/print exact files, without remote writes
  --yes, -y          Explicitly approve the printed plan without prompting
  --help, -h         Show help
No force push or automatic rebase. Failed writes preserve local work.`;

export function parseArgs(argv) {
  const o = { private: true, examples: true, yes: false, dryRun: false, appUrl: 'https://devansh-ops.github.io/worklog-bend/' };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') o.help = true;
    else if (a === '--private') o.private = true;
    else if (a === '--public') o.private = false;
    else if (a === '--no-examples') o.examples = false;
    else if (a === '--yes' || a === '-y') o.yes = true;
    else if (a === '--dry-run') o.dryRun = true;
    else if (a === '--repo' || a === '--app-url') {
      const value = argv[++i];
      if (!value || value.startsWith('-')) throw new Error(`${a} needs a value.`);
      o[a === '--repo' ? 'repo' : 'appUrl'] = value;
    } else if (a.startsWith('--repo=')) o.repo = a.slice(7);
    else if (a.startsWith('--app-url=')) o.appUrl = a.slice(10);
    else throw new Error(`Unknown option: ${a}`);
  }
  if (o.repo !== undefined && !/^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}$/.test(o.repo)) throw new Error('--repo needs owner/name.');
  if (o.repo && ['.', '..'].includes(o.repo.split('/')[1])) throw new Error('Invalid repository name.');
  let url; try { url = new URL(o.appUrl); } catch { throw new Error('--app-url needs an HTTP(S) URL.'); }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) throw new Error('--app-url must be a static HTTP(S) URL without credentials, query or fragment.');
  o.appUrl = url.href;
  return Object.freeze(o);
}
export function execute(command, args, options = {}) {
  const env = { ...process.env, ...options.env, GIT_TERMINAL_PROMPT: '0', GH_DEBUG: '' };
  if (command === 'git') for (const key of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES']) delete env[key];
  if (command === 'git') for (const key of Object.keys(env)) if (key.startsWith('GIT_TRACE') || key === 'GIT_CURL_VERBOSE') delete env[key];
  const r = spawnSync(command, args, { encoding: 'utf8', timeout: 120000, ...options, env });
  if (r.error) throw r.error;
  return { status: r.status, stdout: r.stdout || '', stderr: r.stderr || '' };
}
async function cleanup(container, parent) {
  const actual = await fs.realpath(container), base = await fs.realpath(parent), suffix = relative(base, actual);
  if (!suffix || isAbsolute(suffix) || suffix.includes(sep) || !suffix.startsWith('worklog-setup-')) throw new Error('Refusing cleanup outside the owned setup directory.');
  await fs.rm(actual, { recursive: true, force: true });
}
async function parents(checkout, path) {
  const parts = path.split('/');
  if (parts.some(p => !p || p === '.' || p === '..') || path.includes('\\')) throw new Error('Invalid scaffold path.');
  let current = checkout;
  for (const part of parts.slice(0, -1)) {
    current = join(current, part);
    try { const st = await fs.lstat(current); if (!st.isDirectory() || st.isSymbolicLink()) throw new Error('Scaffold parent must be an ordinary directory.'); }
    catch (e) { if (e.code !== 'ENOENT') throw e; }
  }
}

export async function runSetup(argv, deps = {}) {
  const o = parseArgs(argv), print = deps.print || console.log;
  if (o.help) { print(HELP); return { help: true }; }
  const run = deps.run || execute;
  const call = async (cmd, args, opts = {}, allow = false) => {
    const r = await run(cmd, args, opts);
    if (r.status !== 0 && !allow) throw new Error(`${cmd} failed (exit ${r.status}). ${r.stderr || r.stdout}`.trim());
    return r;
  };
  const gh = (args, input, allow = false) => call('gh', ['api', '--hostname', 'github.com', ...args], input === undefined ? {} : { input }, allow);
  const user = JSON.parse((await gh(['user'])).stdout);
  if (user.type !== 'User' || !/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(user.login || '')) throw new Error('A personal GitHub account is required.');
  const slug = o.repo || `${user.login}/worklog-data`;
  const inspected = await gh(['--include', '--method', 'GET', `repos/${slug}`], undefined, true);
  const status = Number(inspected.stdout.match(/^HTTP\/\S+\s+(\d{3})\b/)?.[1]);
  if (![200, 404].includes(status)) throw new Error(`GitHub inspection failed (${Number.isInteger(status) ? `HTTP ${status}` : 'network/no HTTP response'}). No write was attempted.`);
  const split = inspected.stdout.search(/\r?\n\r?\n/);
  if (split < 0) throw new Error('Invalid GitHub response.');
  const metadata = status === 200 ? JSON.parse(inspected.stdout.slice(split).trim()) : null;
  if (metadata && metadata.full_name?.toLowerCase() !== slug.toLowerCase()) throw new Error('Inspected destination does not match the request.');
  if (metadata && typeof metadata.private !== 'boolean') throw new Error('Repository visibility could not be inspected.');
  if (metadata && (typeof metadata.default_branch !== 'string' || !metadata.default_branch)) throw new Error('Repository default branch could not be inspected.');
  if (!metadata && slug.split('/')[0].toLowerCase() !== user.login.toLowerCase()) throw new Error('New repositories require the authenticated personal owner.');
  const parent = resolve(deps.tempRoot || tmpdir());
  await fs.mkdir(parent, { recursive: true });
  const container = await fs.mkdtemp(join(parent, 'worklog-setup-')), checkout = join(container, 'checkout');
  let retain = false;
  const git = (args, input, allow = false, cwd = checkout) => call('git', ['-c', `safe.directory=${checkout}`, '-c', 'credential.helper=', '-c', 'credential.https://github.com.helper=!gh auth git-credential', ...args], { cwd, ...(input === undefined ? {} : { input }) }, allow);
  try {
    const url = `https://github.com/${slug}.git`, branch = metadata?.default_branch || 'main';
    let base = null;
    if (metadata) {
      await git(['clone', '--quiet', '--', url, checkout], undefined, false, container);
      const head = await git(['rev-parse', '--verify', 'HEAD'], undefined, true);
      if (head.status === 0) {
        base = head.stdout.trim(); if (!SHA.test(base)) throw new Error('Invalid cloned revision.');
        if ((await git(['symbolic-ref', '--short', 'HEAD'])).stdout.trim() !== branch) throw new Error('Cloned branch differs from inspected default.');
        const paths = (await git(['ls-tree', '-r', '--name-only', '-z', 'HEAD', '--', 'data'])).stdout.split('\0');
        if (paths.some(p => p === 'data' || p === 'data/log' || p === 'data/manifest.json' || p === 'data/board.json' || /^data\/log\/(?:.*\.json|\d{4})$/.test(p))) throw new Error('Existing or partial log data must be recovered in the app. Setup refused.');
      } else await git(['symbolic-ref', 'HEAD', `refs/heads/${branch}`]);
    } else {
      await fs.mkdir(checkout); await git(['init', '--quiet', '--initial-branch=main']); await git(['remote', 'add', 'origin', url]);
    }
    await git(['check-ref-format', `refs/heads/${branch}`]);
    const verifyRemote = async () => {
      for (const flags of [[], ['--push']]) {
        const urls = (await git(['remote', 'get-url', ...flags, '--all', 'origin'])).stdout.trim().split(/\r?\n/);
        if (urls.length !== 1 || urls[0] !== url) throw new Error('The effective Git destination differs from the approved GitHub repository. Review URL rewrites and push URLs.');
      }
    };
    await verifyRemote();
    if (!globalThis.crypto?.getRandomValues) globalThis.crypto = webcrypto;
    const { scaffoldFiles } = await import('../js/bootstrap.js');
    const candidate = scaffoldFiles({ slug, appUrl: o.appUrl, withExamples: o.examples }), files = [], retained = [];
    for (const file of candidate.files) {
      await parents(checkout, file.path);
      try { await fs.lstat(join(checkout, file.path)); if (file.path !== 'README.md') throw new Error(`Existing ${file.path} must be preserved.`); retained.push(file.path); }
      catch (e) { if (e.code !== 'ENOENT') throw e; files.push(file); }
    }
    const plan = immutableJSON({ target: slug, branch, base, create: !metadata, private: metadata ? metadata.private : o.private, message: 'worklog: initialise data repo\n\nScaffolding created by the work log app.\n', files, retained });
    print(`Destination: ${slug} on ${branch}\nBase: ${base || 'new root commit'}\nVisibility: ${plan.private ? 'private' : 'public'}\nCreate: ${plan.create ? 'yes' : 'existing repository'}\nMessage:\n${plan.message}`);
    for (const f of plan.files) print(`===== ${f.path} =====\n${f.text}`);
    if (plan.retained.length) print(`Unchanged existing files: ${plan.retained.join(', ')}`);
    if (o.dryRun) { print('Dry run: no repository was created or pushed.'); return { dryRun: true, plan }; }
    let yes = o.yes;
    if (!yes) {
      if (deps.approve) yes = await deps.approve(plan);
      else { const prompt = createInterface({ input: process.stdin, output: process.stdout }); try { yes = /^(y|yes)$/i.test((await prompt.question('Create and commit this exact plan? [y/N] ')).trim()); } finally { prompt.close(); } }
    }
    if (!yes) { print('Cancelled. No remote write occurred.'); return { cancelled: true, plan }; }
    if (!publication.approved({ $: 'Nil' }, canonicalJSON(plan), canonicalJSON({ ...plan, target: slug, branch, base }))) throw new Error('Approved plan changed.');
    if (base && (await git(['rev-parse', 'HEAD'])).stdout.trim() !== base) throw new Error('Local base changed after preview.');
    if ((await git(['status', '--porcelain', '-z'])).stdout) throw new Error('Prepared checkout changed after preview.');
    retain = true;
    for (const f of plan.files) {
      await parents(checkout, f.path); await fs.mkdir(dirname(join(checkout, f.path)), { recursive: true }); await fs.writeFile(join(checkout, f.path), f.text);
      const blob = (await git(['hash-object', '-w', '--stdin'], f.text)).stdout.trim();
      await git(['update-index', '--add', '--cacheinfo', '100644', blob, f.path]);
    }
    const tree = (await git(['write-tree'])).stdout.trim();
    const name = deps.identity?.name || (await call('git', ['-C', project, 'config', 'user.name'], {}, true)).stdout.trim() || 'worklog';
    const email = deps.identity?.email || (await call('git', ['-C', project, 'config', 'user.email'], {}, true)).stdout.trim() || 'worklog@localhost';
    const commit = (await git(['-c', `user.name=${name}`, '-c', `user.email=${email}`, 'commit-tree', tree, ...(base ? ['-p', base] : [])], plan.message)).stdout.trim();
    if (!SHA.test(commit)) throw new Error('Git returned an invalid commit.');
    await git(['update-ref', `refs/heads/${branch}`, commit, base || '0'.repeat(commit.length)]);
    if (plan.create) {
      const created = JSON.parse((await gh(['--method', 'POST', 'user/repos', '--input', '-'], JSON.stringify({ name: slug.split('/')[1], private: plan.private, auto_init: false, description: 'Personal work log data' }))).stdout);
      if (created.full_name?.toLowerCase() !== slug.toLowerCase() || created.private !== plan.private) throw new Error('Created repository differs from the approved destination/visibility. No push attempted.');
    }
    await verifyRemote();
    await git(['push', '--set-upstream', 'origin', `refs/heads/${branch}:refs/heads/${branch}`]);
    print(`Pushed ${commit} to https://github.com/${slug} on ${branch}.`); retain = false; return { commit, plan };
  } catch (e) { if (retain) e.message += `\nCompleted local work is preserved at ${checkout}. Inspect the destination before retrying; do not force-push.`; throw e; }
  finally { if (!retain) await cleanup(container, parent); }
}
if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) runSetup(process.argv.slice(2)).catch(e => { console.error(`setup: ${e.message}`); process.exitCode = 1; });
