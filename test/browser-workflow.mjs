import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const appRoot = process.env.WORKLOG_APP_ROOT || fileURLToPath(new URL('../', import.meta.url));
const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
const blob = text => createHash('sha1').update(`blob ${Buffer.byteLength(text)}\0`).update(text).digest('hex');
const hash = text => createHash('sha1').update(text).digest('hex');
const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const month = today.slice(0, 7);
const monthPath = `data/log/${month.slice(0, 4)}/${month.slice(5)}.json`;
const initial = { id: 'synthetic-base', ts: new Date(Date.now() - 30000).toISOString(), type: 'task.create', taskId: 'T-aaa111', title: 'Synthetic base', status: 'todo', tags: ['browser'] };

class Repository {
  constructor() {
    this.files = new Map([
      ['data/manifest.json', JSON.stringify({ schema: 2, months: [month] })],
      [monthPath, JSON.stringify({ month, events: [initial] })],
      ['README.md', 'UNRELATED_README_CANARY'],
    ]);
    this.revision = hash('initial'); this.snapshots = new Map(); this.trees = new Map(); this.candidates = new Map();
    this.calls = []; this.patches = 0; this.serial = 0; this.snapshot();
  }
  snapshot() { this.snapshots.set(this.revision, new Map(this.files)); }
  advance() { this.revision = hash(`peer-${++this.serial}`); this.snapshot(); }
  events() { return JSON.parse(this.files.get(monthPath)).events; }
  async route(route) {
    const request = route.request(), url = new URL(request.url()), method = request.method();
    const body = request.postData() ? JSON.parse(request.postData()) : null;
    this.calls.push({ path: url.pathname, method, body });
    const send = (value, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(value) });
    const path = url.pathname.replace(/^\/repos\/synthetic\/data/, '');
    if (path === '') return send({ private: true, default_branch: 'main', permissions: { push: true }, html_url: 'https://synthetic.invalid/data' });
    if (path === '/git/ref/heads/main') return send({ object: { sha: this.revision } });
    if (path.startsWith('/contents/')) {
      const filePath = decodeURIComponent(path.slice('/contents/'.length));
      const files = this.snapshots.get(url.searchParams.get('ref')) || this.files;
      const text = files.get(filePath);
      return text === undefined ? send({ message: 'Not Found' }, 404) : send({ encoding: 'base64', content: Buffer.from(text).toString('base64'), sha: blob(text), size: Buffer.byteLength(text) });
    }
    if (method === 'GET' && path.startsWith('/git/commits/')) {
      const revision = path.split('/').at(-1);
      if (!this.snapshots.has(revision)) return send({ message: 'unknown commit' }, 404);
      return send({ sha: revision, tree: { sha: hash(`root:${revision}`) } });
    }
    if (method === 'GET' && path.startsWith('/git/trees/')) {
      const sha = path.split('/').at(-1);
      for (const [revision, files] of this.snapshots) {
        if (sha === hash(`root:${revision}`)) return send({ sha, truncated: false, tree: [{ path: 'data', type: 'tree', mode: '040000', sha: hash(`data:${revision}`) }] });
        if (sha === hash(`data:${revision}`)) return send({ sha, truncated: false, tree: [...files].filter(([name]) => name.startsWith('data/')).map(([name, text]) => ({ path: name.slice(5), mode: '100644', type: 'blob', sha: blob(text), size: Buffer.byteLength(text) })) });
      }
    }
    if (method === 'POST' && path === '/git/trees') {
      const revision = [...this.snapshots.keys()].find(value => hash(`root:${value}`) === body.base_tree);
      assert.ok(revision, 'tree must extend an approved existing base');
      const files = new Map(this.snapshots.get(revision));
      for (const file of body.tree) file.sha === null ? files.delete(file.path) : files.set(file.path, file.content);
      const sha = hash(`tree-${++this.serial}`); this.trees.set(sha, files); return send({ sha });
    }
    if (method === 'POST' && path === '/git/commits') {
      assert.equal(body.parents.length, 1);
      const sha = hash(`commit-${++this.serial}`); this.candidates.set(sha, { files: this.trees.get(body.tree), parent: body.parents[0] }); return send({ sha });
    }
    if (method === 'PATCH' && path === '/git/refs/heads/main') {
      assert.equal(body.force, false); const candidate = this.candidates.get(body.sha);
      if (candidate.parent !== this.revision) return send({ message: 'not a fast forward' }, 422);
      this.files = candidate.files; this.revision = body.sha; this.snapshot(); this.patches++; return send({ object: { sha: this.revision } });
    }
    throw new Error(`Unexpected synthetic GitHub request: ${method} ${url.pathname}`);
  }
}

const child = spawn(process.execPath, ['bin/worklog.mjs', '--no-open', '--port', '0'], { cwd: appRoot, stdio: ['ignore', 'pipe', 'pipe'] });
let browser;
try {
  const url = await new Promise((done, reject) => {
    let output = ''; const timeout = setTimeout(() => reject(new Error(`CLI startup timeout: ${output}`)), 10000);
    child.once('error', error => { clearTimeout(timeout); reject(error); });
    child.stdout.on('data', chunk => { output += chunk; const match = output.match(/http:\/\/127\.0\.0\.1:\d+\//); if (match) { clearTimeout(timeout); done(match[0]); } });
    child.stderr.on('data', chunk => { output += chunk; });
  });
  browser = await playwright.chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}) });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, timezoneId: 'Asia/Kolkata' });
  const repo = new Repository(), outside = [], routeErrors = [];
  await context.route('**/*', async route => {
    const target = new URL(route.request().url());
    if (target.origin === new URL(url).origin) return route.continue();
    if (target.origin === 'https://api.github.com' && target.pathname.startsWith('/repos/synthetic/data')) {
      try { return await repo.route(route); } catch (error) { routeErrors.push(error.message); return route.abort(); }
    }
    outside.push(target.href); return route.abort();
  });
  await context.addInitScript(() => {
    if (!localStorage.getItem('worklog.config.v1')) localStorage.setItem('worklog.config.v1', JSON.stringify({ owner: 'synthetic', repo: 'data', branch: 'main', provider: 'rules', panes: ['board'], reminderAt: '' }));
    if (!localStorage.getItem('worklog.tokens.v1')) localStorage.setItem('worklog.tokens.v1', JSON.stringify({ locked: false, secrets: { githubToken: 'FAKE_BROWSER_TOKEN', aiTokens: {} } }));
    window.clipboardMode = 'ok'; window.copiedText = null;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async text => {
      if (window.clipboardMode === 'fail') throw new Error('Synthetic clipboard failure'); window.copiedText = text;
    } } });
    document.execCommand = () => false;
  });
  const page = await context.newPage(), pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  page.on('dialog', dialog => dialog.accept());
  await page.goto(url);
  await page.getByRole('button', { name: 'Synthetic base, To Do', exact: true }).waitFor();
  const pending = () => page.evaluate(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]'));
  const nav = async name => {
    const region = page.getByRole('region', { name, exact: true });
    if (!await region.count()) await page.getByRole('tab').filter({ hasText: name }).click();
    await region.waitFor(); return region;
  };
  const mutationCount = () => repo.calls.filter(call => call.method !== 'GET').length;

  // Real setup dialog; injected repository effects are synthetic and separate
  // from the full GitHub API transport exercised by publication below.
  await page.evaluate(async () => {
    const { offerScaffold } = await import('/js/ui/setup.js');
    window.setupCalls = []; window.setupDone = false;
    window.runSetup = () => {
      window.setupDone = false;
      const repo = { slug: 'synthetic/setup', owner: 'synthetic', repo: 'setup', branch: 'main',
        createRepo: async options => window.setupCalls.push({ kind: 'create', options }),
        initialCommit: async (files, message) => window.setupCalls.push({ kind: 'commit', files, message }) };
      offerScaffold({}, repo, 'missing').then(result => { window.setupResult = result; window.setupDone = true; });
    };
    window.runSetup();
  });
  let setup = page.getByRole('dialog', { name: 'Create your data repo?', exact: true });
  await setup.waitFor();
  await setup.getByRole('button', { name: 'Not now', exact: true }).click();
  await page.waitForFunction(() => window.setupDone);
  assert.equal(await page.evaluate(() => window.setupCalls.length), 0);
  await page.evaluate(() => window.runSetup()); await setup.waitFor();
  await setup.getByRole('checkbox').uncheck();
  await page.waitForFunction(() => [...document.querySelectorAll('dialog details')].some(node => node.querySelector('summary')?.textContent.includes('/log/') && node.querySelector('pre')?.textContent.includes('"count": 0')));
  const preview = await setup.locator('details').evaluateAll(nodes => nodes.map(node => ({ path: node.querySelector('summary').textContent, text: node.querySelector('pre').textContent })));
  await setup.getByRole('button', { name: 'Create repo and commit', exact: true }).click();
  await page.waitForFunction(() => window.setupDone);
  const setupCalls = await page.evaluate(() => window.setupCalls);
  assert.equal(setupCalls[0].options.private, true); assert.deepEqual(setupCalls[1].files, preview);
  console.log('PASS real setup Cancel, option regeneration, private default and exact approved files');

  const beforeManual = repo.calls.length;
  await page.getByRole('button', { name: '+ Task', exact: true }).click();
  let dialog = page.getByRole('dialog', { name: 'New task', exact: true });
  await dialog.getByRole('textbox', { name: 'Title', exact: true }).fill('Workflow target');
  await dialog.getByRole('textbox', { name: 'Title', exact: true }).press('Enter');
  await page.getByRole('button', { name: 'Workflow target, To Do', exact: true }).waitFor();
  await page.getByRole('button', { name: 'Workflow target, To Do', exact: true }).click();
  dialog = page.getByRole('dialog', { name: 'Task', exact: true });
  await dialog.getByRole('combobox', { name: 'Status', exact: true }).selectOption('done');
  await dialog.getByRole('combobox', { name: 'Priority', exact: true }).selectOption('high');
  await dialog.getByRole('textbox', { name: 'Tags', exact: true }).fill('browser, keyboard');
  await dialog.getByRole('textbox', { name: 'Add a note', exact: true }).fill('Keyboard note for browser workflow.');
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await page.getByRole('button', { name: 'Workflow target, Done', exact: true }).waitFor().catch(async error => { console.log('EDIT_FAILURE', await page.locator('body').innerText(), JSON.stringify(await pending())); throw error; });
  assert.equal(repo.calls.length, beforeManual, 'staging must not perform HTTP');
  assert.ok((await pending()).some(event => event.type === 'task.note'));
  await page.getByRole('textbox', { name: 'Search tasks', exact: true }).fill('keyboard note');
  assert.equal(await page.getByRole('button', { name: 'Synthetic base, To Do', exact: true }).count(), 0);
  await page.getByRole('textbox', { name: 'Search tasks', exact: true }).fill('');
  console.log('PASS keyboard creation, status/priority/tags/note edits, search and local-only staging');

  // Explicit preview/cancel and peer revision before the write are UI paths.
  await page.getByRole('button', { name: 'Publish', exact: true }).click();
  let publish = page.getByRole('dialog', { name: 'Publish to GitHub?', exact: true }); await publish.waitFor();
  assert.ok(await publish.locator('details').count());
  await publish.getByRole('button', { name: 'Cancel', exact: true }).click();
  assert.equal(mutationCount(), 0);
  await page.getByRole('button', { name: 'Publish', exact: true }).click(); await publish.waitFor();
  repo.advance();
  await publish.getByRole('button', { name: 'Push this commit', exact: true }).click();
  const failed = page.getByRole('dialog', { name: 'Not published', exact: true }); await failed.waitFor();
  assert.ok((await failed.innerText()).includes('Review a new preview'));
  assert.equal(mutationCount(), 0); assert.ok((await pending()).length);
  await failed.getByRole('button', { name: 'Close', exact: true }).click();
  await page.getByRole('button', { name: 'Publish', exact: true }).click(); await publish.waitFor();
  const publishedFiles = await publish.locator('details').evaluateAll(nodes => nodes.map(node => ({ path: node.querySelector('summary').textContent, text: node.querySelector('pre').textContent })));
  await publish.getByRole('button', { name: 'Push this commit', exact: true }).click();
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]').length === 0);
  assert.equal(repo.patches, 1);
  for (const file of publishedFiles) assert.equal(repo.files.get(file.path), file.text);
  assert.equal(repo.files.get('README.md'), 'UNRELATED_README_CANARY');
  await page.reload(); await page.getByRole('button', { name: 'Workflow target, Done', exact: true }).waitFor().catch(async error => { console.log('EDIT_FAILURE', await page.locator('body').innerText(), JSON.stringify(await pending())); throw error; });
  console.log('PASS publish Cancel, stale-parent refusal, new approval, exact atomic files, unrelated preservation and reload');

  const brain = await nav('Brain dump');
  await brain.getByRole('textbox', { name: 'Your update', exact: true }).fill('New: cultivate saffron seedlings.\nNew: purchase violet umbrellas.');
  await brain.getByRole('button', { name: 'Interpret this', exact: true }).click();
  await brain.getByRole('heading', { name: 'Proposed changes', exact: true }).waitFor();
  assert.equal((await pending()).length, 0, 'interpretation must not stage anything');
  await brain.getByRole('checkbox').nth(1).uncheck();
  await brain.getByRole('button', { name: 'Apply 1 change', exact: true }).click();
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]').some(event => event.type === 'task.create'));
  assert.equal((await pending()).filter(event => event.type === 'task.create').length, 1);
  assert.ok(!(await pending()).some(event => String(event.title).includes('violet umbrellas')));
  console.log('PASS rules proposals require explicit selected application');

  const summary = await nav('Summary');
  await summary.getByRole('button', { name: 'Evening summary', exact: true }).click();
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]').some(event => event.type === 'summary.set'));
  const standup = await nav('Standup');
  await standup.getByRole('textbox', { name: 'Your report', exact: true }).fill('Exact edited browser report');
  const beforeCopy = (await pending()).length;
  await page.evaluate(() => { window.clipboardMode = 'fail'; });
  await standup.getByRole('button', { name: 'Copy', exact: true }).click();
  await page.getByRole('status').filter({ hasText: 'would not let' }).waitFor();
  assert.equal((await pending()).length, beforeCopy);
  await page.evaluate(() => { window.clipboardMode = 'ok'; });
  await standup.getByRole('button', { name: 'Copy', exact: true }).click();
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]').some(event => event.type === 'standup.set'));
  const recorded = (await pending()).filter(event => event.type === 'standup.set').at(-1);
  assert.equal(recorded.text, await page.evaluate(() => window.copiedText)); assert.equal(recorded.text, 'Exact edited browser report');
  console.log('PASS rules summary and edited report clipboard failure/success recording');

  // Close excess panes via actual tabs/close controls before narrowing.
  await page.setViewportSize({ width: 400, height: 900 });
  const wiki = await nav('Wiki');
  await wiki.getByRole('button', { name: 'Tasks', exact: true }).click();
  await wiki.getByRole('button', { name: 'Workflow target', exact: true }).click();
  assert.ok((await wiki.innerText()).includes('Keyboard note for browser workflow'));
  await wiki.getByRole('button', { name: '← Back', exact: true }).click();
  await wiki.getByRole('button', { name: 'Tags', exact: true }).click();
  await wiki.getByRole('button').filter({ hasText: /^browser ·/ }).click();
  assert.ok((await wiki.innerText()).includes('Workflow target'));
  await page.getByRole('tab').filter({ hasText: 'Board' }).click();
  await page.getByRole('button', { name: 'Workflow target, Done', exact: true }).click();
  dialog = page.getByRole('dialog', { name: 'Task', exact: true });
  await dialog.getByRole('checkbox').check();
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await page.getByRole('button', { name: 'Workflow target, Done', exact: true }).click();
  dialog = page.getByRole('dialog', { name: 'Task', exact: true });
  await dialog.getByRole('button', { name: 'Delete', exact: true }).click();
  const remove = page.getByRole('dialog', { name: 'Remove this task?', exact: true });
  await remove.getByRole('button', { name: 'Remove', exact: true }).click();
  await page.getByRole('button', { name: 'Workflow target, Done', exact: true }).waitFor({ state: 'detached' });
  assert.ok((await pending()).some(event => event.type === 'task.delete'));
  const afterDeletion = [...repo.events(), ...await pending()];
  const disclosed = await page.evaluate(async events => {
    const { eligibleContext } = await import('/js/domain.js');
    return JSON.stringify(eligibleContext(events, true));
  }, afterDeletion);
  assert.ok(!disclosed.includes('Workflow target'));
  assert.ok(!disclosed.includes('Keyboard note for browser workflow'));
  console.log('PASS 400px wiki task/tag history and private task deletion confirmation');

  await page.getByRole('button', { name: 'Publish', exact: true }).click(); await publish.waitFor();
  await publish.getByRole('button', { name: 'Push this commit', exact: true }).click();
  await page.waitForFunction(() => JSON.parse(localStorage.getItem('worklog.pending.synthetic/data#main') || '[]').length === 0);
  assert.equal(repo.patches, 2);
  assert.equal(repo.events().filter(event => event.type === 'standup.set').at(-1).text, 'Exact edited browser report');
  await page.reload(); await page.getByRole('button', { name: 'Synthetic base, To Do', exact: true }).waitFor();
  const persistedReport = await nav('Standup');
  await persistedReport.getByText(/^Recorded /).waitFor();
  const copiedDetails = persistedReport.locator('details[data-last-copied]');
  await copiedDetails.getByText('Last copied today', { exact: true }).click();
  assert.equal(await copiedDetails.locator('pre').innerText(), 'Exact edited browser report');
  console.log('PASS copied report and summary publish atomically and exact last-copied text remains retrievable after reload');

  await page.getByRole('tab').filter({ hasText: 'Board' }).click();
  await page.getByRole('button', { name: '+ Task', exact: true }).click();
  dialog = page.getByRole('dialog', { name: 'New task', exact: true });
  await dialog.getByRole('textbox', { name: 'Title', exact: true }).fill('Reminder pending item');
  await dialog.getByRole('textbox', { name: 'Title', exact: true }).press('Enter');
  await page.getByRole('button', { name: 'Reminder pending item, To Do', exact: true }).waitFor();
  await page.evaluate(() => {
    const settings = JSON.parse(localStorage.getItem('worklog.config.v1'));
    settings.reminderAt = '00:00'; settings.reminderLastFired = '';
    localStorage.setItem('worklog.config.v1', JSON.stringify(settings));
  });
  await page.clock.install({ time: new Date() });
  await page.reload(); await page.getByRole('button', { name: 'Reminder pending item, To Do', exact: true }).waitFor();
  await page.clock.fastForward(4500);
  const reminder = page.getByRole('dialog', { name: 'End of the day', exact: true }); await reminder.waitFor();
  assert.ok((await reminder.innerText()).includes('staged in this browser'));
  await reminder.getByRole('button', { name: 'Not now', exact: true }).click();
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('worklog.config.v1')).reminderLastFired), today);
  await page.reload(); await page.getByRole('button', { name: 'Reminder pending item, To Do', exact: true }).waitFor();
  await page.clock.fastForward(4500);
  assert.equal(await reminder.count(), 0);
  console.log('PASS actual scheduled reminder and once-per-local-day acknowledgement across reload');
  assert.deepEqual(routeErrors, []); assert.deepEqual(outside, []); assert.deepEqual(pageErrors, []);
  console.log(`Chromium ${await browser.version()}: browser workflow acceptance passed with synthetic GitHub only; no external requests`);
} finally {
  await browser?.close();
  if (child.exitCode === null) { const exit = new Promise(done => child.once('exit', done)); child.kill(); await exit; }
}
