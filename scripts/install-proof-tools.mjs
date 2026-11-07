import { readFile, mkdir, rename, rm } from 'node:fs/promises';
import { createReadStream, createWriteStream } from 'node:fs';
import { createHash } from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import https from 'node:https';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lock = JSON.parse(await readFile(resolve(root, 'toolchain/bend.lock.json'), 'utf8'));
const target = resolve(root, '.toolchain');
await mkdir(target, { recursive: true });
async function digest(file) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest('hex');
}
function response(url, redirects = 0) {
  if (!url.startsWith('https:') || redirects > 8) throw new Error('Invalid proof tool download redirect');
  return new Promise((done, reject) => {
    const req = https.get(url, { headers: { 'User-Agent': 'worklog-bend-toolchain' }, timeout: 30000 }, res => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        res.resume();
        done(response(new URL(res.headers.location, url).href, redirects + 1));
      } else if (res.statusCode === 200) done(res);
      else { res.resume(); reject(new Error(`Proof download HTTP ${res.statusCode}`)); }
    });
    req.on('timeout', () => req.destroy(new Error('Proof tool download timed out')));
    req.on('error', reject);
  });
}
for (const [name, spec] of Object.entries(lock.proofTools)) {
  const output = resolve(target, name);
  let valid = false;
  try { valid = await digest(output) === spec.sha256; } catch {}
  if (!valid) {
    console.log(`Downloading locked ${name}`);
    const partial = output + '.download';
    try {
      await pipeline(await response(spec.url), createWriteStream(partial));
      if (await digest(partial) !== spec.sha256) throw new Error(`Integrity mismatch: ${name}`);
      await rename(partial, output);
    } finally { await rm(partial, { force: true }); }
  }
  console.log(`Verified ${name}`);
}
