// Exercise the shipped CLI with actual Node filesystem and loopback HTTP APIs.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { request } from 'node:http';
import { fileURLToPath } from 'node:url';
const cli = fileURLToPath(new URL('../bin/worklog.mjs', import.meta.url));
for (const [args, status, pattern] of [
  [['--help'], 0, /worklog.*localhost/i],
  [['--version'], 0, /0\.1\.0/],
  [['--port', 'banana'], 2, /--port/],
]) {
  const result = spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, status);
  assert.match(result.stdout + result.stderr, pattern);
}
const child = spawn(process.execPath, [cli, '--port', '0', '--no-open', '--demo'], { stdio: ['ignore', 'pipe', 'pipe'] });
const exited = new Promise(resolve => child.once('exit', (code, signal) => resolve({ code, signal })));
let output = '';
try {
  const url = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`CLI startup timeout: ${output}`)), 10000);
    child.stdout.on('data', chunk => {
      output += chunk;
      const match = output.match(/http:\/\/127\.0\.0\.1:\d+\/\?demo=1/);
      if (match) { clearTimeout(timer); resolve(new URL(match[0])); }
    });
    child.on('error', reject);
    child.stderr.on('data', chunk => { output += chunk; });
  });
  const get = (path, method = 'GET') => new Promise((resolve, reject) => {
    const req = request({ hostname: url.hostname, port: url.port, path, method }, res => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body, headers: res.headers }));
    });
    req.setTimeout(5000, () => req.destroy(new Error('HTTP timeout')));
    req.on('error', reject);
    req.end();
  });
  const root = await get('/');
  assert.equal(root.status, 200);
  assert.match(root.body, /<!doctype html>/i);
  const head = await get('/js/store.js', 'HEAD');
  assert.equal(head.status, 200);
  assert.equal(head.body, '');
  assert.match(head.headers['content-type'], /javascript/);
  assert.equal((await get('/no-such-file')).status, 404);
  assert.equal((await get('/%ZZ')).status, 404);
  assert.equal((await get('/%2e%2e/package.json')).status, 404);
  assert.equal((await get('/', 'POST')).status, 405);
  console.log('Real Node CLI smoke passed: help/version/errors, static GET/HEAD, missing/malformed/traversal paths, POST rejection, demo URL');
} finally {
  child.kill();
  await exited;
}
