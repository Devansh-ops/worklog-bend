import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, realpath } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(process.env.WORKLOG_APP_ROOT || fileURLToPath(new URL('../', import.meta.url)));
const physicalRoot = await realpath(root);
const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href) : await import('playwright');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };
const server = createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    if (!pathname.startsWith('/project/')) return response.writeHead(404).end();
    const suffix = decodeURIComponent(pathname.slice('/project/'.length)) || 'index.html';
    const file = await realpath(resolve(root, suffix));
    if (file !== physicalRoot && !file.startsWith(physicalRoot + sep)) return response.writeHead(404).end();
    response.writeHead(200, { 'Content-Type': `${types[extname(file)] || 'application/octet-stream'}; charset=utf-8` });
    response.end(await readFile(file));
  } catch { response.writeHead(404).end(); }
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  browser = await playwright.chromium.launch({ headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
  });
  const context = await browser.newContext();
  await context.addInitScript(() => Object.defineProperty(navigator, 'gpu', { value: undefined, configurable: true }));
  const external = [], errors = [], loaded = [];
  await context.route('**/*', route => {
    if (new URL(route.request().url()).origin !== origin) { external.push(route.request().url()); return route.abort(); }
    return route.continue();
  });
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => loaded.push({ path: new URL(response.url()).pathname, status: response.status() }));
  await page.goto(`${origin}/project/?demo=1`);
  await page.getByRole('tab').filter({ hasText: 'Board (10)' }).waitFor();
  const result = await page.evaluate(async () => {
    for (const name of ['core', 'reports', 'publication', 'views', 'planning']) await import(`./js/generated/${name}.mjs`);
    const vault = await import('./js/vault.js');
    const webllm = await import('./js/webllm.js');
    const { endpointProblem } = await import('./js/providers.js');
    const key = 'worklog.tokens.v1';
    const secrets = { githubToken: 'SYNTHETIC_GITHUB_TOKEN', aiTokens: { openai: 'SYNTHETIC_PROVIDER_TOKEN' } };
    vault.clearTokens();
    const initiallyEmpty = !vault.hasStoredTokens() && await vault.loadTokens() === null;
    await vault.saveTokens(secrets, 'synthetic passphrase for browser checks');
    const raw = localStorage.getItem(key), record = JSON.parse(raw);
    const encrypted = vault.isLocked() && !raw.includes(secrets.githubToken) && !raw.includes(secrets.aiTokens.openai);
    const parameters = { alg: record.alg, hash: record.kdf.hash, iterations: record.kdf.iterations,
      saltBytes: atob(record.kdf.salt).length, ivBytes: atob(record.iv).length };
    const needsPassphrase = await vault.loadTokens() === null;
    const unlocked = await vault.loadTokens('synthetic passphrase for browser checks');
    const wrongPassphrase = await vault.loadTokens('definitely wrong') === null && localStorage.getItem(key) === raw;
    const bytes = Uint8Array.from(atob(record.ct), character => character.charCodeAt(0));
    bytes[0] ^= 1;
    record.ct = btoa(String.fromCharCode(...bytes));
    localStorage.setItem(key, JSON.stringify(record));
    const tamperRejected = await vault.loadTokens('synthetic passphrase for browser checks') === null;
    await vault.saveTokens(secrets, 'synthetic passphrase for browser checks');
    const fresh = JSON.parse(localStorage.getItem(key));
    const independentRandomness = fresh.iv !== JSON.parse(raw).iv && fresh.kdf.salt !== JSON.parse(raw).kdf.salt;

    // Compatible older records use their stored iteration count and migrate hfToken.
    const oldSecrets = { githubToken: 'SYNTHETIC_LEGACY_GITHUB', hfToken: 'SYNTHETIC_LEGACY_HF' };
    const salt = crypto.getRandomValues(new Uint8Array(16)), iv = crypto.getRandomValues(new Uint8Array(12));
    const encoder = new TextEncoder();
    const base = await crypto.subtle.importKey('raw', encoder.encode('synthetic legacy passphrase'), 'PBKDF2', false, ['deriveKey']);
    const derived = await crypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations: 120000, hash: 'SHA-256' }, base, { name: 'AES-GCM', length: 256 }, false, ['encrypt']);
    const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, derived, encoder.encode(JSON.stringify(oldSecrets))));
    const b64 = bytes => btoa(String.fromCharCode(...bytes));
    localStorage.setItem(key, JSON.stringify({ locked: true, alg: 'A256GCM', kdf: { hash: 'SHA-256', iterations: 120000, salt: b64(salt) }, iv: b64(iv), ct: b64(ct) }));
    const legacyEncrypted = await vault.loadTokens('synthetic legacy passphrase');
    localStorage.setItem(key, JSON.stringify({ locked: false, secrets: oldSecrets }));
    const legacyPlain = await vault.loadTokens();
    vault.clearTokens();
    const forgotten = !vault.hasStoredTokens() && await vault.loadTokens() === null;
    let gpuError = '';
    try { await webllm.preloadBrowserModel('synthetic-no-download'); } catch (error) { gpuError = error.message; }
    return { initiallyEmpty, encrypted, parameters, needsPassphrase, unlocked, wrongPassphrase, tamperRejected,
      independentRandomness, legacyEncrypted, legacyPlain, forgotten, gpuPresent: webllm.hasWebGPU(), gpuError,
      gpuProblem: endpointProblem({ kind: 'webgpu', model: 'synthetic-no-download' }), loadedModels: webllm.loadedBrowserModels() };
  });
  for (const field of ['initiallyEmpty', 'encrypted', 'needsPassphrase', 'wrongPassphrase', 'tamperRejected', 'independentRandomness', 'forgotten']) assert.equal(result[field], true, field);
  assert.deepEqual(result.parameters, { alg: 'A256GCM', hash: 'SHA-256', iterations: 600000, saltBytes: 16, ivBytes: 12 });
  assert.deepEqual(result.unlocked, { githubToken: 'SYNTHETIC_GITHUB_TOKEN', aiTokens: { openai: 'SYNTHETIC_PROVIDER_TOKEN' } });
  for (const restored of [result.legacyEncrypted, result.legacyPlain]) assert.deepEqual(restored, { githubToken: 'SYNTHETIC_LEGACY_GITHUB', aiTokens: { huggingface: 'SYNTHETIC_LEGACY_HF' } });
  assert.equal(result.gpuPresent, false); assert.match(result.gpuError, /no WebGPU/); assert.match(result.gpuProblem, /no WebGPU/); assert.deepEqual(result.loadedModels, []);
  await page.evaluate(async () => {
    const vault = await import('./js/vault.js');
    const { settingsDialog } = await import('./js/ui/settings.js');
    const { resolveEndpoint } = await import('./js/providers.js');
    const { prepareOperationsRequest } = await import('./js/ai.js');
    const { appRevision } = await import('./js/request.js');
    await vault.saveTokens({ githubToken: 'SYNTHETIC_OLD_GITHUB', aiTokens: { custom: 'SYNTHETIC_OLD_AI' } }, 'synthetic forget passphrase');
    window.forgetApp = {
      settings: { owner: 'synthetic', repo: 'data', branch: 'main', provider: 'custom', baseUrl: 'https://synthetic.invalid/v1', model: 'synthetic-model', sendNotes: false },
      tokens: { github: 'SYNTHETIC_OLD_GITHUB', ai: { custom: 'SYNTHETIC_OLD_AI' } }, credentialRevision: 0,
      store: { authoritative: true, repo: { token: 'SYNTHETIC_OLD_GITHUB' } },
      state: { complete: true, events: [{ id: 'create', ts: '2026-11-07T09:00:00.000Z', type: 'task.create', taskId: 'T-public', title: 'Synthetic' }] },
      get endpoint() { return resolveEndpoint(this.settings, this.tokens.ai); },
      saveSettings(value) { this.settings = { ...this.settings, ...value }; },
    };
    window.beforeForgetRequest = await prepareOperationsRequest({ endpoint: forgetApp.endpoint, events: forgetApp.state.events,
      text: 'Synthetic', readCurrent: () => appRevision(forgetApp) });
    window.forgetFinished = false;
    settingsDialog(forgetApp).then(() => { window.forgetFinished = true; });
  });
  const settings = page.getByRole('dialog', { name: 'Settings', exact: true });
  await settings.getByLabel('GitHub token', { exact: true }).fill('SYNTHETIC_UNSAVED_GITHUB');
  await settings.getByLabel('API key', { exact: true }).fill('SYNTHETIC_UNSAVED_AI');
  await settings.getByLabel('New vault passphrase', { exact: true }).fill('synthetic unsaved passphrase');
  await settings.getByRole('button', { name: 'Forget tokens on this browser', exact: true }).click();
  await page.getByRole('dialog', { name: 'Forget stored tokens?', exact: true }).getByRole('button', { name: 'Forget them', exact: true }).click();
  for (const label of ['GitHub token', 'API key', 'New vault passphrase']) assert.equal(await settings.getByLabel(label, { exact: true }).inputValue(), '');
  const revoked = await page.evaluate(async () => {
    const { requestTransport } = await import('./js/request.js');
    let stale = false;
    try { requestTransport(beforeForgetRequest); } catch (error) { stale = /changed/.test(error.message); }
    return { github: forgetApp.tokens.github, ai: forgetApp.tokens.ai, activeToken: forgetApp.store.repo.token, stale, revision: forgetApp.credentialRevision };
  });
  assert.deepEqual(revoked, { github: null, ai: {}, activeToken: null, stale: true, revision: 1 });
  await settings.getByRole('button', { name: 'Save', exact: true }).click();
  await page.waitForFunction(() => window.forgetFinished);
  assert.deepEqual(await page.evaluate(async () => ({ tokens: forgetApp.tokens, stored: (await import('./js/vault.js')).hasStoredTokens() })), { tokens: { github: null, ai: {} }, stored: false });
  for (const width of [1440, 400]) {
    await page.setViewportSize({ width, height: 900 });
    await page.getByRole('button', { name: '+ Task', exact: true }).waitFor();
    assert.equal(await page.title(), 'Worklog Bend');
  }
  for (const name of ['core', 'reports', 'publication', 'views', 'planning']) assert.ok(loaded.some(item => item.path === `/project/js/generated/${name}.mjs` && item.status === 200), `Subpath missing ${name}`);
  assert.deepEqual(errors, []); assert.deepEqual(external, []);
  console.log(`Chromium ${await browser.version()}: actual PBKDF2/AES-GCM, legacy records, UI forget/session revocation without typed-key resurrection, unavailable WebGPU, and static /project/ module loading passed. No external requests.`);
} finally {
  await browser?.close();
  await new Promise(done => server.close(done));
}
