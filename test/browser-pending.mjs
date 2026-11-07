import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = process.env.WORKLOG_APP_ROOT || fileURLToPath(new URL('../', import.meta.url));
const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
const server = spawn(process.execPath, ['bin/worklog.mjs', '--no-open', '--port', '0'], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
let browser;
try {
  const url = await new Promise((done, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error('CLI startup timeout: ' + output)), 10000);
    server.once('error', error => { clearTimeout(timer); reject(error); });
    server.stdout.on('data', chunk => {
      output += chunk;
      const match = output.match(/http:\/\/127\.0\.0\.1:\d+\//);
      if (match) { clearTimeout(timer); done(match[0]); }
    });
    server.stderr.on('data', chunk => { output += chunk; });
  });
  browser = await playwright.chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  const context = await browser.newContext();
  const errors = [], external = [];
  context.on('page', page => page.on('pageerror', error => errors.push(error.message)));
  await context.route('**/*', route => {
    const target = new URL(route.request().url());
    if (target.origin !== new URL(url).origin) { external.push(target.href); return route.abort(); }
    if (target.pathname === '/pending-fixture.html') return route.fulfill({ contentType: 'text/html', body: '<!doctype html><title>Synthetic pending fixture</title>' });
    return route.continue();
  });
  async function tab(clear = false) {
    const page = await context.newPage(); await page.goto(url + 'pending-fixture.html');
    await page.evaluate(async clear => {
      if (clear) localStorage.clear();
      const { Store, PATHS } = await import('/js/store.js');
      window.Store = Store;
      window.makeRepo = (branch = 'main') => ({
        owner: 'synthetic', repo: 'pending-tabs', branch, slug: 'synthetic/pending-tabs',
        files: new Map(), readRevision: 'a'.repeat(40),
        async pinRevision() { return this.readRevision; },
        async getFile(path) { const text = this.files.get(path); return text === undefined ? null : { text }; },
        async commitFiles(files, _message, { expectedBase, deletions = [] }) {
          if (expectedBase !== this.readRevision) throw new Error('Synthetic stale parent');
          for (const file of files) this.files.set(file.path, file.text);
          for (const path of deletions) this.files.delete(path);
          this.readRevision = 'b'.repeat(40);
          return { commit: this.readRevision };
        },
      });
      window.draft = id => ({ id, ts: '2026-11-08T09:00:00.000Z', type: 'task.create', taskId: 'T-' + id, title: 'Synthetic ' + id });
      window.store = new Store(makeRepo()); await store.load();
    }, clear);
    return page;
  }
  const first = await tab(true), second = await tab();
  // Both real tabs hold the same old empty view before either writes storage.
  await Promise.all([
    first.evaluate(() => store.stage(draft('draft-a')) && true),
    second.evaluate(() => store.stage(draft('draft-b')) && true),
  ]);
  let restored = await tab();
  assert.deepEqual(await restored.evaluate(() => store.pending.map(event => event.id).sort()), ['draft-a', 'draft-b']);
  await restored.close();
  await first.evaluate(() => store.discardPending());
  restored = await tab();
  assert.deepEqual(await restored.evaluate(() => store.pending.map(event => event.id)), ['draft-b'], 'Discard must not erase an unseen peer draft');
  await restored.close();
  await first.evaluate(() => store.stage(draft('draft-c')));
  await second.evaluate(async () => { const plan = await store.preparePublish(); await store.push(plan); });
  await first.close(); await second.close();
  restored = await tab();
  assert.deepEqual(await restored.evaluate(() => store.pending.map(event => event.id)), ['draft-c'], 'Approval acknowledgement must not erase unseen peer edits');
  assert.deepEqual(await restored.evaluate(async () => { const other = new Store(makeRepo('other')); await other.load(); return other.pending; }), []);
  await restored.reload();
  await restored.evaluate(async () => { const { Store } = await import('/js/store.js'); window.again = new Store({ owner: 'synthetic', repo: 'pending-tabs', branch: 'main' }); });
  assert.deepEqual(await restored.evaluate(() => again.pending.map(event => event.id)), ['draft-c']);
  assert.deepEqual(errors, []); assert.deepEqual(external, []);
  console.log(`Chromium ${await browser.version()}: actual shared-storage tabs retain concurrent drafts, discard only observed work, acknowledge only approved work and survive closure/reload. No external requests.`);
} finally {
  await browser?.close();
  if (server.exitCode === null) { const exited = new Promise(done => server.once('exit', done)); server.kill(); await exited; }
}
