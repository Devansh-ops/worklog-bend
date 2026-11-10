import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const site = new URL(process.argv[2] || 'https://devansh-ops.github.io/worklog-bend/');
assert.equal(site.protocol, 'https:');
assert.ok(site.pathname.endsWith('/'), 'Supply the project root URL with its trailing slash');
assert.ok(!site.username && !site.password && !site.search && !site.hash);
const manifest = JSON.parse(await readFile(resolve(root, 'js/generated/manifest.json'), 'utf8'));
async function asset(path, type) {
  const response = await fetch(new URL(path, site), { redirect: 'error', signal: AbortSignal.timeout(30000) });
  assert.equal(response.status, 200, path);
  if (type) assert.match(response.headers.get('content-type') || '', type, path);
  return Buffer.from(await response.arrayBuffer());
}
const html = (await asset('', /text\/html/)).toString('utf8');
assert.ok(html.includes('<title>Worklog Bend</title>'));
assert.deepEqual(JSON.parse((await asset('js/generated/manifest.json', /json/)).toString('utf8')), manifest);
for (const [name, expected] of Object.entries(manifest.assets)) {
  const bytes = await asset('js/generated/' + name, /(?:application|text)\/javascript/);
  assert.equal(bytes.length, expected.bytes, name);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), expected.sha256, name);
}
await asset('css/app.css', /text\/css/);
await asset('js/webllm-worker.js', /(?:application|text)\/javascript/);
await asset('LICENSE');
await asset('THIRD_PARTY_NOTICES.md');
await asset('licenses/Bend-Apache-2.0.txt');
console.log('Hosted HTTPS assets, MIME types, licenses and all five generated hashes match the checkout.');

const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
const browser = await playwright.chromium.launch({ headless: true,
  ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
});
try {
  const context = await browser.newContext();
  const errors = [], external = [], badResponses = [];
  context.on('page', page => page.on('pageerror', error => errors.push(error.message)));
  context.on('response', response => {
    if (response.url().startsWith(site.href) && response.status() >= 400) badResponses.push([response.status(), response.url()]);
  });
  await context.route('**/*', route => {
    const target = new URL(route.request().url());
    if (target.origin !== site.origin || !target.pathname.startsWith(site.pathname)) {
      external.push(target.href); return route.abort();
    }
    return route.continue();
  });
  const page = await context.newPage();
  await page.goto(site.href);
  const welcome = page.getByRole('dialog', { name: 'Welcome to your work log', exact: true });
  await welcome.waitFor();
  const demo = new URL('?demo=1', site).href;
  const href = await welcome.getByRole('link', { name: 'Open the demo board', exact: true }).getAttribute('href');
  assert.equal(new URL(href, site).href, demo);
  for (const width of [1440, 400]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(demo);
    await page.getByRole('tab').filter({ hasText: 'Board (10)' }).waitFor();
    assert.equal(await page.title(), 'Worklog Bend');
    await page.getByRole('button', { name: '+ Task', exact: true }).click();
    await page.getByPlaceholder('What needs doing?').fill('Synthetic hosted smoke task');
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await page.getByRole('tab').filter({ hasText: 'Board (11)' }).waitFor();
    await page.reload();
    await page.getByRole('tab').filter({ hasText: 'Board (10)' }).waitFor();
    console.log(`Hosted demo ${width}px: rendered, accepted a synthetic edit and discarded it on reload.`);
  }
  assert.deepEqual(errors, []);
  assert.deepEqual(external, [], 'Welcome/demo must not call providers or GitHub');
  assert.deepEqual(badResponses, []);
  await context.close();
  console.log(`Chromium ${await browser.version()}: hosted app and ?demo=1 passed without page errors or external requests.`);
} finally { await browser.close(); }
