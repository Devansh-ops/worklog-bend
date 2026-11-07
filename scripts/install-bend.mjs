import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import https from 'node:https';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lock = JSON.parse(await readFile(resolve(root, 'toolchain/bend.lock.json'), 'utf8'));
const target = resolve(root, '.toolchain/bend');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
function download(url) {
  return new Promise((accept, reject) => {
    const request = https.get(url, { headers: { 'User-Agent': 'worklog-bend-toolchain' }, timeout: 30000 }, response => {
      if (response.statusCode !== 200) { response.resume(); reject(new Error(`HTTP ${response.statusCode}: ${url}`)); return; }
      const parts = [];
      response.on('data', part => parts.push(part));
      response.on('end', () => accept(Buffer.concat(parts)));
      response.on('error', reject);
    });
    request.on('timeout', () => request.destroy(new Error(`Download timed out: ${url}`)));
    request.on('error', reject);
  });
}
for (const [name, expected] of Object.entries(lock.files)) {
  const output = resolve(target, name);
  let bytes;
  try { bytes = await readFile(output); } catch {}
  if (!bytes || digest(bytes) !== expected) {
    bytes = await download(`https://raw.githubusercontent.com/bendlang/bend/${lock.commit}/${name}`);
    if (digest(bytes) !== expected) throw new Error(`Integrity mismatch: ${name}`);
    await mkdir(dirname(output), { recursive: true });
    await writeFile(output, bytes);
  }
  console.log(`Verified ${name}`);
}
console.log(`Bend ${lock.version} source ready at ${target}`);
