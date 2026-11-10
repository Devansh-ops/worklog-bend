import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const help = `Opt-in live Worklog Bend persistence test.
Usage: node scripts/test-live-github.mjs --allow-github-writes [--cleanup]
Creates a fresh PRIVATE repository with synthetic data under the authenticated
personal gh account. Real credentials stay in Node memory, outside the browser.
Only this newly created repository is writable. --cleanup attempts to delete it
after a successful test; insufficient existing permissions leave it private.
Reports are written under ignored tmp/. No traces, HAR, video or screenshots.
This tests live persistence through a credential relay, not direct browser CORS.`;
if (process.argv.includes('--help')) { console.log(help); process.exit(0); }
assert.ok(process.argv.includes('--allow-github-writes'), help);
for (const arg of process.argv.slice(2)) assert.ok(['--allow-github-writes', '--cleanup'].includes(arg), 'Unknown test argument');
const cleanup = process.argv.includes('--cleanup');
const root = fileURLToPath(new URL('../', import.meta.url));
const site = new URL('https://devansh-ops.github.io/worklog-bend/');
const apiRoot = 'https://api.github.com';
const sentinel = 'SYNTHETIC_BROWSER_CREDENTIAL_RELAY';
const ghEnv = { ...process.env, GH_PROMPT_DISABLED: '1' };
delete ghEnv.GH_DEBUG;
const captured = spawnSync('gh', ['auth', 'token', '--hostname', 'github.com'], { env: ghEnv, encoding: 'utf8', timeout: 30000, windowsHide: true });
assert.equal(captured.status, 0, 'Existing gh authentication is required; no credentials were printed.');
let credential = captured.stdout.trim();
captured.stdout = '';
assert.ok(credential, 'Existing gh authentication is empty.');
const sanitize = text => String(text).replaceAll(credential, '[REDACTED]');
let browser, owned, slug, branch, prefix;
const calls = [], guards = [], commits = [];
const evidence = { started: new Date().toISOString(), transport: 'Actual GitHub API through an in-memory credential relay; no real browser token/CORS claim', checks: [] };
const reportPath = resolve(root, 'tmp/live-github-' + Date.now() + '.json');
async function api(method, path, body) {
  assert.ok(path.startsWith('/') && !path.startsWith('//'));
  const url = new URL(path, apiRoot);
  assert.equal(url.origin, apiRoot);
  const response = await fetch(url, {
    method, redirect: 'error', signal: AbortSignal.timeout(45000),
    headers: { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
      Authorization: 'Bearer ' + credential, 'User-Agent': 'worklog-bend-live-persistence',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await response.text();
  return { status: response.status, text, value: text ? JSON.parse(text) : null };
}
async function ok(method, path, body) {
  const result = await api(method, path, body);
  assert.ok(result.status >= 200 && result.status < 300, `GitHub ${method} ${path}: ${result.status} ${sanitize(result.value?.message || '')}`);
  return result.value;
}
async function assertOwned() {
  const repo = await ok('GET', prefix);
  assert.equal(repo.id, owned.id); assert.equal(repo.private, true);
  assert.equal(repo.full_name.toLowerCase(), slug.toLowerCase());
  assert.equal(repo.description, owned.description);
}
async function snapshot() {
  const ref = await ok('GET', prefix + '/git/ref/heads/' + encodeURIComponent(branch));
  return snapshotAt(ref.object.sha);
}
async function snapshotAt(sha) {
  const commit = await ok('GET', prefix + '/git/commits/' + sha);
  const tree = await ok('GET', prefix + '/git/trees/' + commit.tree.sha + '?recursive=1');
  assert.equal(tree.truncated, false);
  return { sha, commit, entries: new Map(tree.tree.map(entry => [entry.path, entry])) };
}
async function textAt(snap, path) {
  const entry = snap.entries.get(path); assert.ok(entry && entry.type === 'blob', path);
  const blob = await ok('GET', prefix + '/git/blobs/' + entry.sha);
  assert.equal(blob.sha, entry.sha); assert.equal(blob.encoding, 'base64');
  return Buffer.from(blob.content, 'base64').toString('utf8');
}
function pass(name) { evidence.checks.push(name); console.log('PASS ' + name); }
const mutationCount = () => calls.filter(call => call.method !== 'GET').length;
async function pending(page) {
  return page.evaluate(key => JSON.parse(localStorage.getItem(key) || '[]'), `worklog.pending.${slug}#${encodeURIComponent(branch)}`);
}
async function preview(page) {
  await page.getByRole('button', { name: 'Publish', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Publish to GitHub?', exact: true }); await dialog.waitFor();
  const files = await dialog.locator('details').evaluateAll(nodes => nodes.map(node => ({ path: node.querySelector('summary').textContent, text: node.querySelector('pre').textContent })));
  const message = await dialog.locator('pre.commit-preview').first().textContent();
  const base = (await dialog.innerText()).match(/Base revision:\s*([0-9a-f]{40})/)[1];
  return { dialog, files, message, base, events: await pending(page) };
}
async function approve(page, plan, expectedPending = 0) {
  await plan.dialog.getByRole('button', { name: 'Push this commit', exact: true }).click();
  await page.waitForFunction(({ key, count }) => JSON.parse(localStorage.getItem(key) || '[]').length === count,
    { key: `worklog.pending.${slug}#${encodeURIComponent(branch)}`, count: expectedPending }, { timeout: 90000 });
  await page.getByRole('dialog', { name: 'Publishing', exact: true }).waitFor({ state: 'detached', timeout: 90000 });
}
async function verifyPlan(plan, originalReadme) {
  const snap = await snapshot();
  const parent = await snapshotAt(plan.base);
  assert.equal(snap.commit.message, plan.message);
  assert.deepEqual(snap.commit.parents.map(parent => parent.sha), [plan.base]);
  for (const file of plan.files) assert.equal(await textAt(snap, file.path), file.text, file.path);
  const writes = new Set(plan.files.map(file => file.path)), deletions = new Set(plan.deletions || []);
  for (const path of new Set([...parent.entries.keys(), ...snap.entries.keys()])) {
    const before = parent.entries.get(path), after = snap.entries.get(path);
    if (before?.type === 'tree' || after?.type === 'tree') continue;
    if (writes.has(path)) { assert.equal(after?.type, 'blob', path); assert.equal(after?.mode, '100644', path); }
    else if (deletions.has(path)) assert.equal(after, undefined, path);
    else assert.deepEqual(after, before, 'Unapproved tree difference: ' + path);
  }
  assert.equal(await textAt(snap, 'README.md'), originalReadme);
  commits.push(snap.sha);
  return snap;
}
async function edit(page, note, status) {
  await page.getByRole('button', { name: /^Synthetic live task, / }).click();
  const dialog = page.getByRole('dialog', { name: 'Task', exact: true });
  if (status) await dialog.getByRole('combobox', { name: 'Status', exact: true }).selectOption(status);
  await dialog.getByRole('textbox', { name: 'Add a note', exact: true }).fill(note);
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
}
try {
  await mkdir(resolve(root, 'tmp'), { recursive: true });
  const me = await ok('GET', '/user');
  assert.equal(me.type, 'User'); assert.match(me.login, /^[a-z0-9-]+$/i);
  const deployed = await ok('GET', '/repos/Devansh-ops/worklog-bend/pages/builds/latest');
  assert.equal(deployed.status, 'built'); evidence.deployedSource = deployed.commit;
  const checkout = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8', windowsHide: true });
  assert.equal(checkout.status, 0); evidence.checkoutSource = checkout.stdout.trim();
  assert.equal(deployed.commit, evidence.checkoutSource, 'Wait for Pages to deploy this checkout before a live write test');
  for (const file of ['js/app.js', 'js/store.js', 'js/bootstrap.js', 'js/domain.js', 'js/github.js', 'js/codec.js', 'js/source-index.js', 'js/source-cache.js']) {
    const response = await fetch(new URL(file, site), { redirect: 'error', signal: AbortSignal.timeout(30000) });
    assert.equal(response.status, 200);
    assert.equal((await response.text()).replaceAll('\r\n', '\n'), (await readFile(resolve(root, file), 'utf8')).replaceAll('\r\n', '\n'), 'Hosted source mismatch: ' + file);
  }
  const name = 'worklog-bend-smoke-' + new Date().toISOString().replace(/\D/g, '').slice(0, 14) + '-' + randomUUID().slice(0, 8);
  const description = 'Temporary synthetic Worklog Bend live persistence test ' + name;
  owned = await ok('POST', '/user/repos', { name, private: true, auto_init: true, has_issues: false, has_wiki: false, description });
  slug = me.login + '/' + name; prefix = '/repos/' + slug; branch = owned.default_branch;
  assert.match(branch, /^[a-z0-9._-]+$/i);
  await assertOwned();
  evidence.repository = { id: owned.id, slug, private: true, branch };
  const initial = await snapshot(), originalReadme = await textAt(initial, 'README.md');
  const playwright = process.env.PLAYWRIGHT_MODULE ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
  browser = await playwright.chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}) });
  let heldPatch = null;
  async function newContext() {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    await context.addInitScript(({ owner, repo, branch, sentinel, origin, basePath }) => {
      if (location.origin !== origin || !location.pathname.startsWith(basePath)) return;
      if (!localStorage.getItem('worklog.config.v1')) localStorage.setItem('worklog.config.v1', JSON.stringify({ owner, repo, branch, provider: 'none', panes: ['board'], reminderAt: '' }));
      localStorage.setItem('worklog.tokens.v1', JSON.stringify({ locked: false, secrets: { githubToken: sentinel, aiTokens: {} } }));
    }, { owner: me.login, repo: name, branch, sentinel, origin: site.origin, basePath: site.pathname });
    context.on('page', page => page.on('pageerror', error => guards.push('page error: ' + sanitize(error.message))));
    await context.route('**/*', async route => {
      try {
        const request = route.request(), url = new URL(request.url());
        if (url.origin === site.origin && url.pathname.startsWith(site.pathname)) return route.continue();
        const method = request.method();
        assert.equal(url.origin, apiRoot, 'Unexpected external origin');
        for (const segment of url.pathname.slice(1).split('/')) {
          const decoded = decodeURIComponent(segment);
          assert.ok(/^[a-z0-9_.-]+$/i.test(decoded) && decoded !== '.' && decoded !== '..', 'Unsafe API path segment');
        }
        for (const [key, value] of url.searchParams) {
          assert.ok(key === 'ref' && /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/.test(value) || key === 'recursive' && value === '1', 'Unexpected API query');
        }
        assert.ok(url.pathname === prefix || url.pathname.startsWith(prefix + '/'), 'Out-of-scope API path');
        const suffix = url.pathname.slice(prefix.length);
        const getAllowed = method === 'GET' && (suffix === '' || /^\/(?:contents\/|git\/(?:ref\/heads\/|commits\/|trees\/|blobs\/))/.test(suffix));
        const postAllowed = method === 'POST' && ['/git/trees', '/git/commits', '/git/blobs'].includes(suffix);
        const patchAllowed = method === 'PATCH' && suffix === '/git/refs/heads/' + branch;
        assert.ok(getAllowed || postAllowed || patchAllowed, 'Forbidden API operation');
        assert.equal((await request.allHeaders()).authorization, 'Bearer ' + sentinel);
        const body = request.postData() ? JSON.parse(request.postData()) : undefined;
        if (method !== 'GET') await assertOwned();
        if (patchAllowed) assert.equal(body.force, false);
        if (postAllowed && suffix === '/git/trees') for (const entry of body.tree) {
          assert.ok(entry.path.startsWith('data/') || entry.path === 'CHANGELOG.md');
          for (const segment of entry.path.split('/')) assert.ok(/^[a-z0-9_.-]+$/i.test(segment) && segment !== '.' && segment !== '..', 'Unsafe tree path');
          assert.equal(entry.mode, '100644'); assert.equal(entry.type, 'blob');
        }
        if (patchAllowed && heldPatch) { const hold = heldPatch; heldPatch = null; hold.entered(); await hold.wait; }
        const result = await api(method, url.pathname + url.search, body);
        calls.push({ method, path: suffix, status: result.status });
        await route.fulfill({ status: result.status, contentType: 'application/json', body: result.text });
      } catch (error) { guards.push(sanitize(error.message)); await route.abort(); }
    });
    return context;
  }
  const aContext = await newContext(), a = await aContext.newPage();
  await a.goto(site.href);
  const setup = a.getByRole('dialog', { name: 'Set up this repo?', exact: true }); await setup.waitFor({ timeout: 60000 });
  await setup.getByRole('checkbox').uncheck();
  await a.waitForFunction(() => [...document.querySelectorAll('dialog details pre')].some(node => node.textContent.includes('"count": 0')));
  const setupPlan = {
    files: await setup.locator('details').evaluateAll(nodes => nodes.map(node => ({ path: node.querySelector('summary').textContent, text: node.querySelector('pre').textContent }))),
    message: await setup.locator('pre.commit-preview').first().textContent(),
    base: (await setup.innerText()).match(/Base revision:\s*([0-9a-f]{40})/)[1],
  };
  await setup.getByRole('button', { name: 'Commit starter files', exact: true }).click();
  await a.getByRole('button', { name: '+ Task', exact: true }).waitFor({ timeout: 90000 });
  await a.waitForFunction(() => !document.querySelector('[data-action="new-task"]').disabled);
  await verifyPlan(setupPlan, originalReadme);
  pass('real private repository bootstrap preserved the unrelated README');
  const beforeStage = await snapshot(), beforeCalls = mutationCount();
  await a.getByRole('button', { name: '+ Task', exact: true }).click();
  const add = a.getByRole('dialog', { name: 'New task', exact: true });
  await add.getByRole('textbox', { name: 'Title', exact: true }).fill('Synthetic live task');
  await add.getByRole('textbox', { name: 'Title', exact: true }).press('Enter');
  await a.getByRole('button', { name: 'Synthetic live task, To Do', exact: true }).waitFor();
  let plan = await preview(a);
  await plan.dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
  assert.equal((await snapshot()).sha, beforeStage.sha); assert.equal(mutationCount(), beforeCalls);
  pass('local staging and Cancel left the real GitHub ref unchanged');
  plan = await preview(a); await approve(a, plan); await verifyPlan(plan, originalReadme);
  pass('approved publication matched actual GitHub file bytes, message and parent');
  const bContext = await newContext(), b = await bContext.newPage(); await b.goto(site.href);
  await b.getByRole('button', { name: 'Synthetic live task, To Do', exact: true }).waitFor({ timeout: 60000 });
  await edit(a, 'SYNTHETIC_NOTE_FROM_A');
  const stale = await preview(a);
  await edit(b, 'SYNTHETIC_NOTE_FROM_B', 'done');
  const peer = await preview(b); await approve(b, peer); await verifyPlan(peer, originalReadme);
  const peerHead = (await snapshot()).sha, beforeStale = mutationCount();
  await stale.dialog.getByRole('button', { name: 'Push this commit', exact: true }).click();
  const rejected = a.getByRole('dialog', { name: 'Not published', exact: true }); await rejected.waitFor({ timeout: 90000 });
  assert.ok((await rejected.innerText()).includes('Review a new preview'));
  assert.equal((await snapshot()).sha, peerHead); assert.equal(mutationCount(), beforeStale);
  assert.ok((await pending(a)).some(event => event.text === 'SYNTHETIC_NOTE_FROM_A'));
  await rejected.getByRole('button', { name: 'Close', exact: true }).click();
  pass('genuine peer advance rejected stale approval without remote mutation or lost pending data');
  const sibling = await aContext.newPage(); await sibling.goto(site.href);
  await sibling.getByRole('button', { name: 'Synthetic live task, Done', exact: true }).waitFor({ timeout: 60000 });
  const mergedPlan = await preview(a);
  let entered, release;
  const enteredPromise = new Promise(done => { entered = done; });
  const wait = new Promise(done => { release = done; }); heldPatch = { entered, wait };
  const approval = approve(a, mergedPlan, 1);
  let deadline;
  try {
    await Promise.race([enteredPromise, new Promise((_, reject) => {
      deadline = setTimeout(() => reject(new Error('Timed out waiting for controlled ref update')), 90000);
    })]);
    await edit(sibling, 'SYNTHETIC_NOTE_DURING_PUBLISH');
  } finally {
    clearTimeout(deadline);
    release();
  }
  await approval;
  await verifyPlan(mergedPlan, originalReadme);
  const remaining = await pending(a);
  assert.equal(remaining.length, 1); assert.equal(remaining[0].text, 'SYNTHETIC_NOTE_DURING_PUBLISH');
  await a.reload(); await a.getByRole('button', { name: 'Synthetic live task, Done', exact: true }).waitFor({ timeout: 60000 });
  assert.equal((await pending(a))[0].text, 'SYNTHETIC_NOTE_DURING_PUBLISH');
  pass('new preview preserved both peers and in-flight peer edit remained pending across reload');
  plan = await preview(a); await approve(a, plan); const final = await verifyPlan(plan, originalReadme);
  await aContext.close(); await bContext.close();
  const fresh = await newContext(), page = await fresh.newPage(); await page.goto(site.href);
  await page.getByRole('button', { name: 'Synthetic live task, Done', exact: true }).waitFor({ timeout: 60000 });
  await page.getByRole('button', { name: 'Synthetic live task, Done', exact: true }).click();
  const detail = page.getByRole('dialog', { name: 'Task', exact: true });
  for (const note of ['SYNTHETIC_NOTE_FROM_A', 'SYNTHETIC_NOTE_FROM_B', 'SYNTHETIC_NOTE_DURING_PUBLISH']) assert.ok((await detail.innerText()).includes(note));
  assert.deepEqual(await pending(page), []);
  const events = [];
  for (const [path] of final.entries) if (/^data\/log\/\d{4}\/\d{2}\.json$/.test(path)) events.push(...JSON.parse(await textAt(final, path)).events);
  assert.equal(new Set(events.map(event => event.id)).size, events.length);
  assert.equal(events.filter(event => event.type === 'task.create').length, 1);
  assert.equal(events.filter(event => event.type === 'task.note').length, 3);
  assert.equal(events.length, 5);
  assert.deepEqual(events.filter(event => event.type === 'task.note').map(event => event.text).sort(),
    ['SYNTHETIC_NOTE_FROM_A', 'SYNTHETIC_NOTE_FROM_B', 'SYNTHETIC_NOTE_DURING_PUBLISH'].sort());
  assert.ok(events.some(event => event.type === 'task.status' && event.to === 'done'));
  assert.deepEqual(guards, []);
  pass('fresh independent browser reconstructed every published event and all three distinct notes');
  await fresh.close();
  evidence.browser = await browser.version(); evidence.finalCommit = final.sha;
  evidence.publications = commits; evidence.apiCalls = calls.length; evidence.passed = true;
  if (cleanup) {
    await assertOwned();
    const deleted = await api('DELETE', prefix);
    evidence.cleanup = deleted.status === 204 ? 'deleted fresh synthetic repository' : 'retained private; existing credential could not delete (HTTP ' + deleted.status + ')';
    assert.ok([204, 403, 404].includes(deleted.status), 'Unexpected cleanup result');
  } else evidence.cleanup = 'retained private for inspection';
  console.log('Live persistence checks passed. ' + evidence.cleanup + '.');
} catch (error) {
  evidence.passed = false; evidence.error = sanitize(error.message);
  process.exitCode = 1; console.error('Live persistence failed: ' + sanitize(error.message));
} finally {
  await browser?.close();
  evidence.finished = new Date().toISOString();
  await mkdir(resolve(root, 'tmp'), { recursive: true });
  await writeFile(reportPath, JSON.stringify(evidence, null, 2) + '\n');
  credential = '';
  console.log('Local evidence: ' + reportPath.slice(root.length).replaceAll('\\', '/'));
}
