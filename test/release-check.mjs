import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createServer, request } from 'node:http';
import { mkdtemp, mkdir, writeFile, symlink, unlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = resolve(root, 'bin/worklog.mjs');
function run(args) {
  return spawnSync(process.execPath, [cli, '--no-open', ...args], { encoding: 'utf8', timeout: 10000 });
}
for (const args of [['--porthole=123'], ['--hostname=127.0.0.1'], ['--host'], ['--host='], ['--port=-1'], ['--port=65536']]) {
  const result = run(args);
  assert.equal(result.status, 2, `Invalid option must reject before starting: ${args.join(' ')}\n${result.stdout}${result.stderr}`);
}
assert.equal(run(['--help']).status, 0);
assert.equal(run(['--version']).status, 0);

async function start(args = []) {
  const child = spawn(process.execPath, [cli, '--no-open', ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
  const exited = new Promise(done => child.once('exit', (code, signal) => done({ code, signal })));
  let output = '';
  const url = await new Promise((done, reject) => {
    const timer = setTimeout(() => reject(new Error(`CLI startup timeout: ${output}`)), 10000);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`CLI startup exit ${code}: ${output}`)); });
    child.stdout.on('data', bytes => {
      output += bytes;
      const match = output.match(/http:\/\/127\.0\.0\.1:\d+\/[^\s]*/);
      if (match) { clearTimeout(timer); done(new URL(match[0])); }
    });
    child.stderr.on('data', bytes => { output += bytes; });
  });
  return { child, exited, url, output: () => output };
}
function get(url, path, method = 'GET') {
  return new Promise((done, reject) => {
    const req = request({ hostname: url.hostname, port: url.port, path, method }, response => {
      let body = '';
      response.setEncoding('utf8'); response.on('data', chunk => { body += chunk; });
      response.on('end', () => done({ status: response.statusCode, body, type: response.headers['content-type'] }));
    });
    req.setTimeout(5000, () => req.destroy(new Error('HTTP timeout')));
    req.on('error', reject); req.end();
  });
}
async function stop(server) {
  server.child.kill('SIGTERM');
  const status = await server.exited;
  await assert.rejects(() => get(server.url, '/'));
  return status;
}
const tempParent = resolve(root, 'tmp');
await mkdir(tempParent, { recursive: true });
const inside = await mkdtemp(join(tempParent, 'release-links-'));
const outside = await mkdtemp(join(tmpdir(), 'worklog-release-outside-'));
const link = join(inside, 'outside');
await writeFile(join(outside, 'synthetic-private.txt'), 'SYNTHETIC_OUTSIDE_ROOT');
let server;
try {
  // Windows directory junctions do not require developer-mode symlink privilege.
  await symlink(outside, link, process.platform === 'win32' ? 'junction' : 'dir');
  server = await start(['--port', '0', '--demo']);
  const relative = '/' + link.slice(root.length).replaceAll('\\', '/').replace(/^\/+/, '');
  assert.equal((await get(server.url, `${relative}/synthetic-private.txt`)).status, 404, 'A junction cannot expose a file outside the package root');
  for (const path of ['/%2e%2e/package.json', '/%2e%2e%5cpackage.json', '/%ZZ', '/%00', '/no-file']) assert.equal((await get(server.url, path)).status, 404, path);
  assert.equal((await get(server.url, '/', 'POST')).status, 405);
  const head = await get(server.url, '/js/generated/core.mjs', 'HEAD');
  assert.equal(head.status, 200); assert.equal(head.body, ''); assert.match(head.type, /javascript/);
  const status = await stop(server); server = null;
  console.log(`CLI confinement/GET/HEAD/method rejection/shutdown passed (${JSON.stringify(status)}).`);
} finally {
  if (server) await stop(server);
  await unlink(link).catch(error => { if (error.code !== 'ENOENT') throw error; });
  // Both temporary directories were created above under these exact verified roots.
  assert.ok(inside.startsWith(tempParent + (process.platform === 'win32' ? '\\' : '/')));
  assert.ok(outside.startsWith(resolve(tmpdir()) + (process.platform === 'win32' ? '\\' : '/')));
  await rm(inside, { recursive: true }); await rm(outside, { recursive: true });
}
const blocker = createServer((_request, response) => response.end('synthetic blocker'));
await new Promise(done => blocker.listen(0, '127.0.0.1', done));
try {
  const occupied = blocker.address().port;
  const fallback = await start(['--port', String(occupied)]);
  try {
    assert.ok(Number(fallback.url.port) > occupied);
    assert.match(fallback.output(), /busy, trying/);
    assert.equal((await get(fallback.url, '/')).status, 200);
  } finally { await stop(fallback); }
} finally { await new Promise(done => blocker.close(done)); }

const npmArgs = ['--loglevel', 'verbose', 'pack', '--dry-run', '--json'];
const npm = process.platform === 'win32' ? process.execPath : 'npm';
if (process.platform === 'win32') npmArgs.unshift(process.env.npm_execpath || resolve(dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js'));
const pack = spawnSync(npm, npmArgs, {
  cwd: root, encoding: 'utf8', timeout: 30000,
  env: { ...process.env, npm_config_cache: resolve(root, 'tmp/npm-cache') },
});
assert.equal(pack.status, 0, pack.stderr);
const listing = JSON.parse(pack.stdout);
const files = new Set(listing[0].files.map(file => file.path));
for (const path of ['LICENSE', 'index.html', 'bin/worklog.mjs', 'js/generated/core.mjs', 'js/generated/reports.mjs', 'js/generated/views.mjs', 'js/generated/publication.mjs']) assert.ok(files.has(path), `Package omitted ${path}`);
assert.ok(![...files].some(path => path.startsWith('.toolchain/') || path.startsWith('node_modules/') || path.endsWith('.token')));
console.log(`Port fallback and npm package content checks passed (${files.size} packaged files). No package was published.`);
