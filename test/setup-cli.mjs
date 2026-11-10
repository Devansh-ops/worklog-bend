import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import { resolve, join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runSetup, parseArgs, execute } from '../scripts/setup.mjs';
const root = fileURLToPath(new URL('../', import.meta.url)), parent = join(root, 'tmp');
await fs.mkdir(parent, { recursive: true });
const testRoot = await fs.mkdtemp(join(parent, 'setup-cli-'));
const git = (args, cwd, input) => {
  const r = execute('git', args, { cwd, ...(input === undefined ? {} : { input }) });
  assert.equal(r.status, 0, r.stdout + r.stderr); return r.stdout;
};
let number = 0, checks = 0;
async function fixture(existing = false, files = { 'README.md': 'UNRELATED_README\n' }) {
  const folder = join(testRoot, String(++number)); await fs.mkdir(folder);
  const remote = join(folder, 'remote.git'), seed = join(folder, 'seed');
  git(['init', '--bare', '--quiet', '--initial-branch=main', remote], folder);
  const seedCommit = async additions => {
    if (!await fs.stat(seed).catch(() => null)) git(['clone', '--quiet', remote, seed], folder);
    else git(['pull', '--quiet', '--ff-only'], seed);
    for (const [path, text] of Object.entries(additions)) { await fs.mkdir(resolve(seed, path, '..'), { recursive: true }); await fs.writeFile(join(seed, path), text); }
    git(['add', '-A'], seed); git(['-c', 'user.name=Synthetic', '-c', 'user.email=synthetic@example.invalid', 'commit', '--quiet', '-m', 'synthetic'], seed); git(['push', '--quiet', 'origin', 'main'], seed);
    return git(['rev-parse', 'HEAD'], seed).trim();
  };
  const base = existing === true ? await seedCommit(files) : null;
  const commands = [], output = []; let exists = existing, createBody = null, failPush = false, failInspect = false;
  const run = (command, args, options = {}) => {
    commands.push({ command, args });
    if (command === 'gh') {
      if (args.at(-1) === 'user') return { status: 0, stdout: '{"login":"synthetic","type":"User"}', stderr: '' };
      if (args.includes('--include')) {
        if (failInspect) return { status: 1, stdout: '', stderr: 'synthetic network failure' };
        return { status: exists ? 0 : 1, stdout: `HTTP/2.0 ${exists ? 200 : 404} Test\n\n${JSON.stringify(exists ? { full_name: 'synthetic/data', default_branch: 'main', private: true } : { message: 'Not Found' })}`, stderr: '' };
      }
      assert.ok(args.includes('user/repos')); createBody = JSON.parse(options.input); exists = true;
      return { status: 0, stdout: JSON.stringify({ full_name: 'synthetic/data', private: createBody.private }), stderr: '' };
    }
    assert.equal(command, 'git');
    if (args.includes('get-url')) return { status: 0, stdout: 'https://github.com/synthetic/data.git\n', stderr: '' };
    if (args.includes('push') && failPush) return { status: 1, stdout: '', stderr: 'synthetic transport failure' };
    return execute('git', args.map(a => {
      if (a.startsWith('https://github.com/')) { assert.equal(a, 'https://github.com/synthetic/data.git'); return remote; }
      return a;
    }), options);
  };
  return { folder, remote, base, commands, output, seedCommit, setFailPush: v => { failPush = v; }, setFailInspect: v => { failInspect = v; },
    get created() { return createBody; }, deps: { run, print: text => output.push(text), tempRoot: join(folder, 'temp'), identity: { name: 'Synthetic', email: 'synthetic@example.invalid' } } };
}
const check = async (name, fn) => { await fn(); checks++; console.log(`PASS ${name}`); };
const show = (fixture, path) => git(['--git-dir', fixture.remote, 'show', `main:${path}`], fixture.folder);
try {
  await check('strict arguments and actual Node scaffolder/help run without shell module flags', async () => {
    for (const args of [['--repo'], ['--app-url'], ['--repo=../bad'], ['--repo=me/..'], ['--repoevil=x'], ['--app-url=https://user:secret@host/']]) assert.throws(() => parseArgs(args));
    const help = execute(process.execPath, ['scripts/setup.mjs', '--help'], { cwd: root }); assert.equal(help.status, 0); assert.match(help.stdout, /No force push/);
    const scaffold = execute(process.execPath, ['scripts/scaffold.mjs', '--', 'synthetic/data', 'http://localhost:8765/', '0'], { cwd: root });
    assert.equal(scaffold.status, 0, scaffold.stderr); assert.match(scaffold.stdout, /^data\/manifest.json\t/);
    const bash = process.env.WORKLOG_TEST_BASH || (process.platform === 'win32'
      ? resolve(git(['--exec-path'], root).trim(), '../../../bin/bash.exe') : 'bash');
    const shell = execute(bash, ['scripts/setup.sh', '--help'], { cwd: root });
    assert.equal(shell.status, 0, shell.stderr); assert.match(shell.stdout, /Node 18/);
  });
  await check('dry run and Cancel print exact immutable payload and perform no remote write', async () => {
    for (const dry of [true, false]) {
      const f = await fixture();
      const result = await runSetup(['--repo', 'synthetic/data', '--no-examples', ...(dry ? ['--dry-run', '--yes'] : [])], { ...f.deps, approve: async plan => { assert.ok(Object.isFrozen(plan.files[0])); return false; } });
      assert.ok(result.dryRun || result.cancelled); assert.equal(f.created, null);
      assert.ok(!f.commands.some(c => c.args.includes('push')));
      for (const file of result.plan.files) assert.ok(f.output.some(line => line === `===== ${file.path} =====\n${file.text}`));
    }
  });
  await check('private/new setup pushes one commit containing exactly the approved bytes and message', async () => {
    const f = await fixture(); const r = await runSetup(['--repo=synthetic/data', '--no-examples', '--yes'], f.deps);
    assert.equal(f.created.private, true); assert.equal(f.created.auto_init, false);
    for (const file of r.plan.files) assert.equal(show(f, file.path), file.text);
    assert.ok(show(f, 'README.md').includes('https://devansh-ops.github.io/worklog-bend/'), 'New data README must link to the hosted app by default');
    const commit = git(['--git-dir', f.remote, 'cat-file', 'commit', r.commit], f.folder);
    assert.equal(commit.slice(commit.indexOf('\n\n') + 2), r.plan.message);
    assert.equal(git(['--git-dir', f.remote, 'rev-list', '--count', 'main'], f.folder).trim(), '1');
  });
  await check('an existing empty repository receives one root commit without repository creation', async () => {
    const f = await fixture('empty'); const r = await runSetup(['--repo=synthetic/data', '--yes', '--no-examples'], f.deps);
    assert.equal(r.plan.base, null); assert.equal(r.plan.create, false); assert.equal(f.created, null);
    assert.equal(git(['--git-dir', f.remote, 'rev-list', '--count', 'main'], f.folder).trim(), '1');
    const wrongOwner = await fixture();
    await assert.rejects(() => runSetup(['--repo=another/data', '--yes'], wrongOwner.deps), /personal owner/);
    assert.equal(wrongOwner.created, null);
  });
  await check('public option is explicit and existing README/unrelated attributes are preserved', async () => {
    const created = await fixture(); await runSetup(['--repo=synthetic/data', '--public', '--yes', '--no-examples'], created.deps); assert.equal(created.created.private, false);
    const f = await fixture(true, { 'README.md': 'UNRELATED_README\n', '.gitattributes': '*.json text eol=crlf\n' });
    const r = await runSetup(['--repo=synthetic/data', '--yes', '--no-examples'], f.deps);
    assert.deepEqual(r.plan.retained, ['README.md']); assert.equal(r.plan.base, f.base); assert.equal(f.created, null);
    assert.equal(show(f, 'README.md'), 'UNRELATED_README\n'); assert.equal(show(f, '.gitattributes'), '*.json text eol=crlf\n');
    for (const file of r.plan.files) assert.equal(show(f, file.path), file.text);
    const parents = git(['--git-dir', f.remote, 'rev-list', '--parents', '-n', '1', 'main'], f.folder).trim().split(' '); assert.deepEqual(parents, [r.commit, f.base]);
  });
  await check('unindexed historical partial data refuses before any new write', async () => {
    const f = await fixture(true, { 'README.md': 'keep', 'data/log/2020/01.json': '{"events":[]}' });
    await assert.rejects(() => runSetup(['--repo=synthetic/data', '--yes'], f.deps), /partial log/);
    assert.equal(f.created, null); assert.ok(!f.commands.some(c => c.args.includes('push')));
    assert.equal(git(['--git-dir', f.remote, 'rev-parse', 'main'], f.folder).trim(), f.base);
  });
  await check('peer advance rejects normal push and retains the completed local checkout', async () => {
    const f = await fixture(true); let peer;
    let failure;
    try { await runSetup(['--repo=synthetic/data', '--no-examples'], { ...f.deps, approve: async () => { peer = await f.seedCommit({ 'peer.txt': 'PEER' }); return true; } }); } catch (e) { failure = e; }
    assert.match(failure?.message || '', /preserved at/); assert.equal(git(['--git-dir', f.remote, 'rev-parse', 'main'], f.folder).trim(), peer);
    const checkout = failure.message.match(/preserved at (.+)\. Inspect/)[1];
    assert.ok(await fs.stat(join(checkout, 'data/manifest.json')));
    assert.ok(!f.commands.some(c => c.args.some(a => a === '--force' || a === '--force-with-lease' || a === 'rebase')));
    assert.equal(git(['rev-parse', 'HEAD^'], checkout).trim(), f.base);
  });
  await check('network inspection errors are not missing repositories; push failure retains recoverable data', async () => {
    const inspect = await fixture(); inspect.setFailInspect(true); await assert.rejects(() => runSetup(['--repo=synthetic/data', '--yes'], inspect.deps), /inspection failed/); assert.equal(inspect.created, null);
    const f = await fixture(); f.setFailPush(true); let failure;
    try { await runSetup(['--repo=synthetic/data', '--yes', '--no-examples'], f.deps); } catch (e) { failure = e; }
    assert.match(failure?.message || '', /preserved at/); const checkout = failure.message.match(/preserved at (.+)\. Inspect/)[1];
    assert.ok(await fs.stat(join(checkout, '.git'))); assert.match(git(['show', 'HEAD:data/manifest.json'], checkout), /"schema": 2/);
    const redirected = await fixture(); const originalRun = redirected.deps.run;
    redirected.deps.run = (command, args, options) => command === 'git' && args.includes('get-url')
      ? { status: 0, stdout: 'https://github.com/unrelated/destination.git\n', stderr: '' } : originalRun(command, args, options);
    await assert.rejects(() => runSetup(['--repo=synthetic/data', '--yes'], redirected.deps), /effective Git destination/);
    assert.equal(redirected.created, null);
    const scoped = execute('git', ['-c', `safe.directory=${root}`, 'rev-parse', '--show-toplevel'], { cwd: root, env: { GIT_DIR: f.remote, GIT_WORK_TREE: checkout } });
    assert.equal(scoped.status, 0, scoped.stderr); assert.equal(resolve(scoped.stdout.trim()), resolve(root));
  });
  console.log(`${checks} setup CLI checks passed using fake gh and real isolated local Git repositories. No GitHub write occurred.`);
} finally {
  const actual = await fs.realpath(testRoot), suffix = relative(await fs.realpath(parent), actual);
  assert.ok(suffix.startsWith('setup-cli-') && !suffix.includes(sep));
  await fs.rm(actual, { recursive: true, force: true });
}
