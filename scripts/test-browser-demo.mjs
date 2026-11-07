import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href)
  : await import('playwright');
const root = fileURLToPath(new URL('../', import.meta.url));
const child = spawn(process.execPath, ['bin/worklog.mjs', '--no-open', '--port', '0', '--demo'], {
  cwd: root, stdio: ['ignore', 'pipe', 'pipe'],
});
let browser;
try {
  const url = await new Promise((done, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`CLI did not start: ${output}`)), 10000);
    const fail = error => { clearTimeout(timer); reject(error); };
    child.once('error', fail);
    child.once('exit', code => fail(new Error(`CLI exited ${code}: ${output}`)));
    child.stderr.on('data', chunk => { output += chunk; });
    child.stdout.on('data', chunk => {
      output += chunk;
      const match = output.match(/http:\/\/127\.0\.0\.1:\d+\/\?demo=1/);
      if (match) { clearTimeout(timer); done(match[0]); }
    });
  });
  const origin = new URL(url).origin;
  browser = await playwright.chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  const errors = [], external = [];
  page.on('pageerror', error => errors.push(error.message));
  await context.route('**/*', route => {
    if (new URL(route.request().url()).origin !== origin) {
      external.push(route.request().url());
      return route.abort();
    }
    return route.continue();
  });
  for (const width of [1440, 400]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(url);
    await page.getByRole('tab').filter({ hasText: 'Board (10)' }).waitFor();
    assert.equal(await page.title(), 'Work Log');
    await page.getByRole('button', { name: '+ Task', exact: true }).click();
    const title = page.getByPlaceholder('What needs doing?');
    await title.waitFor();
    await page.waitForFunction(() => document.activeElement?.getAttribute('placeholder') === 'What needs doing?');
    const canary = '<img src=x onerror="globalThis.injected=true">';
    await title.fill(canary);
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await page.getByRole('tab').filter({ hasText: 'Board (11)' }).waitFor();
    await page.getByRole('button', { name: `${canary}, To Do`, exact: true }).waitFor();
    assert.equal(await page.evaluate(() => globalThis.injected), undefined);
    await page.reload();
    await page.getByRole('tab').filter({ hasText: 'Board (10)' }).waitFor();
    console.log(`Demo browser passed width ${width}: render, task dialog focus, synthetic edit, safe text, ephemeral reload`);
  }
  assert.deepEqual(errors, []);
  assert.deepEqual(external, []);
  console.log(`Chromium ${await browser.version()}; no page errors or external requests`);
} finally {
  await browser?.close();
  if (child.exitCode === null) {
    const exit = new Promise(done => child.once('exit', done));
    child.kill();
    await exit;
  }
}


