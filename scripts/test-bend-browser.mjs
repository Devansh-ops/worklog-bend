import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Install the exact Playwright version in toolchain/bend.lock.json, or point
// PLAYWRIGHT_MODULE at an existing installation's index.mjs. Browser binaries
// must be installed separately. This harness uses only synthetic values.
const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href)
  : await import('playwright');
const modulePath = resolve(process.argv[2] || '.toolchain/bridge.mjs');
const moduleBytes = await readFile(modulePath);
const server = createServer((request, response) => {
  if (request.url === '/bridge.mjs') {
    response.writeHead(200, { 'Content-Type': 'text/javascript; charset=utf-8' });
    response.end(moduleBytes);
  } else if (request.url === '/smoke/') {
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end('<!doctype html><title>Bend bridge smoke</title><main>synthetic bridge check</main>');
  } else {
    response.writeHead(404).end();
  }
});
await new Promise((done, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', done);
});
let browser;
try {
  browser = await playwright.chromium.launch({
    headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
      ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/smoke/`);
  const actual = await page.evaluate(async () => {
    const { default: bend } = await import('/bridge.mjs');
    const original = [1, 2];
    const owned = original.slice();
    const changed = bend.overwrite(owned);
    const task = bend.task('T-synthetic', true, 7);
    return {
      text: bend.keep('Synthetic unicode: \u03bb \ud83d\ude80'),
      inverted: [bend.invert(true), bend.invert(false)],
      sum: bend.sum({ $: 'Con', head: 2, tail: { $: 'Con', head: 3, tail: { $: 'Nil' } } }, 0),
      wrapped: bend.wrap(0xffffffff),
      taskTag: task.$, taskId: task.id, taskPrivate: task.private, taskCount: task.count,
      accepted: bend.checked(true, 7), rejected: bend.checked(false, 7),
      original, changed, mutatesOwnedInput: changed === owned,
    };
  });
  assert.deepEqual(actual, {
    text: 'Synthetic unicode: \u03bb \ud83d\ude80', inverted: [false, true],
    sum: 5, wrapped: 0, taskTag: 'Task', taskId: 'T-synthetic', taskPrivate: true, taskCount: 7,
    accepted: { $: 'Accepted', value: 7 }, rejected: { $: 'Rejected', reason: 'invalid input' },
    original: [1, 2], changed: [9, 2], mutatesOwnedInput: true,
  });
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({ browser: await browser.version(), module: modulePath, checks: actual }, null, 2));
} finally {
  await browser?.close();
  await new Promise((done, reject) => server.close((error) => error ? reject(error) : done()));
}
