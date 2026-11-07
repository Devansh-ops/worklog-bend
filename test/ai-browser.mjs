// Real browser consent/cancellation and exact immutable request handoff.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
const child = spawn(process.execPath, ['bin/worklog.mjs', '--no-open', '--port', '0', '--demo'], {
  cwd: fileURLToPath(new URL('../', import.meta.url)), stdio: ['ignore', 'pipe', 'pipe'],
});
let browser;
try {
  const url = await new Promise((done, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`CLI startup timeout: ${output}`)), 10000);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.stdout.on('data', bytes => {
      output += bytes;
      const found = output.match(/http:\/\/127\.0\.0\.1:\d+\/\?demo=1/);
      if (found) { clearTimeout(timer); done(found[0]); }
    });
    child.stderr.on('data', bytes => { output += bytes; });
  });
  browser = await playwright.chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  const context = await browser.newContext();
  const external = [];
  await context.route('**/*', route => {
    if (new URL(route.request().url()).origin !== new URL(url).origin) { external.push(route.request().url()); return route.abort(); }
    return route.continue();
  });
  const page = await context.newPage(), pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await page.goto(url);
  await page.getByRole('button', { name: '+ Task', exact: true }).waitFor();
  await page.evaluate(async () => {
    const ai = await import('/js/ai.js');
    const consent = await import('/js/ui/consent.js');
    const { resolveEndpoint } = await import('/js/providers.js');
    const events = [{ id: 'synthetic-create', ts: '2026-11-07T10:00:00.000Z', type: 'task.create', taskId: 'T-public', title: 'SYNTHETIC_PUBLIC' }];
    window.sent = [];
    const original = window.fetch.bind(window);
    window.fetch = async (url, options) => {
      if (!String(url).includes('synthetic.invalid')) return original(url, options);
      window.sent.push({ url, body: JSON.parse(options.body), headers: options.headers });
      return { ok: true, json: async () => ({ choices: [{ message: { content: '{"operations":[]}' } }] }) };
    };
    window.source = { revision: 1 };
    window.request = await ai.prepareOperationsRequest({
      endpoint: resolveEndpoint({ provider: 'custom', baseUrl: 'https://synthetic.invalid/v1', model: 'synthetic-model' }, { custom: 'FAKE_BROWSER_KEY' }),
      events, text: '  VERBATIM_SYNTHETIC_INPUT\n  ', includeNotes: false, readCurrent: () => window.source,
    });
    window.begin = () => {
      window.finished = false; window.failure = null;
      consent.confirmCloudSend({ request: window.request })
        .then(approved => approved ? ai.proposeOperations({ request: window.request }) : null)
        .then(value => { window.answer = value; window.finished = true; })
        .catch(error => { window.failure = error.message; window.finished = true; });
    };
    window.begin();
  });
  const dialog = page.getByRole('dialog', { name: 'Send this to a provider?' });
  await dialog.waitFor();
  assert.ok((await dialog.innerText()).includes('VERBATIM_SYNTHETIC_INPUT'));
  assert.ok(!(await dialog.innerText()).includes('FAKE_BROWSER_KEY'));
  await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
  await page.waitForFunction(() => window.finished);
  assert.equal(await page.evaluate(() => window.sent.length), 0);
  assert.equal(await page.evaluate(() => window.answer), null);

  await page.evaluate(() => window.begin());
  await dialog.getByRole('button', { name: 'Send it', exact: true }).click();
  await page.waitForFunction(() => window.finished);
  const success = await page.evaluate(() => ({ failure: window.failure, sent: window.sent, messages: window.request.messages }));
  assert.equal(success.failure, null);
  assert.equal(success.sent.length, 1);
  assert.deepEqual(success.sent[0].body.messages, success.messages);
  assert.equal(success.sent[0].headers.Authorization, 'Bearer FAKE_BROWSER_KEY');

  // Remembered destination consent does not bypass the private source guard.
  await page.evaluate(() => { window.source = { revision: 2 }; window.begin(); });
  await page.waitForFunction(() => window.finished);
  assert.match(await page.evaluate(() => window.failure), /changed/);
  assert.equal(await page.evaluate(() => window.sent.length), 1);
  assert.deepEqual(pageErrors, []);
  assert.deepEqual(external, []);
  console.log(`Chromium ${await browser.version()}: real Cancel/Send consent, verbatim disclosure, exact outgoing messages, hidden credentials, stale request rejection passed; no external requests`);
} finally {
  await browser?.close();
  if (child.exitCode === null) { const exited = new Promise(done => child.once('exit', done)); child.kill(); await exited; }
}
