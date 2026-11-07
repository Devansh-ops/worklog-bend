import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const check = process.argv.includes('--check');
const toWSL = path => path.replace(/^([A-Za-z]):[\\/]/, (_, drive) => `/mnt/${drive.toLowerCase()}/`).replaceAll('\\', '/');
const wrapper = resolve(root, 'scripts/bend-linux.sh');
function bend(args) {
  const command = process.platform === 'win32' ? 'wsl.exe' : 'sh';
  const prefix = process.platform === 'win32'
    ? ['--distribution', 'Ubuntu', '--exec', 'sh', toWSL(wrapper)] : [wrapper];
  const result = spawnSync(command, [...prefix, ...args], { cwd: root, stdio: 'inherit', timeout: 300000 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Bend failed (${result.status}): ${args.join(' ')}`);
}
const hash = value => createHash('sha256').update(value).digest('hex');
const lock = JSON.parse(await readFile(resolve(root, 'toolchain/bend.lock.json'), 'utf8'));
const names = ['Core', 'Reports', 'Publication', 'Views', 'Planning'];
await mkdir(resolve(root, '.toolchain/generated'), { recursive: true });
bend(['PROOF.bend', '--verdict']);
bend(['proof/PlanningLaws.bend', '--verdict']);
const outputs = new Map();
for (const name of names) {
  const filename = `${name.toLowerCase()}.mjs`;
  bend([`bend/${name}.bend`, '-o', `.toolchain/generated/${filename}`]);
  outputs.set(filename, await readFile(resolve(root, `.toolchain/generated/${filename}`)));
}
const sources = {};
for (const name of ['Types', ...names]) sources[`bend/${name}.bend`] = hash((await readFile(resolve(root, `bend/${name}.bend`), 'utf8')).replaceAll('\r\n', '\n'));
const manifest = JSON.stringify({ version: 1, compiler: { commit: lock.commit, version: lock.version, bun: lock.bun }, sources,
  assets: Object.fromEntries([...outputs].map(([name, bytes]) => [name, { sha256: hash(bytes), bytes: bytes.length }])) }, null, 2) + '\n';
if (check) {
  for (const [name, bytes] of outputs) assert.deepEqual(await readFile(resolve(root, `js/generated/${name}`)), bytes, `Stale generated asset: ${name}`);
  assert.equal(await readFile(resolve(root, 'js/generated/manifest.json'), 'utf8'), manifest, 'Stale generated manifest');
  console.log('Pinned verdict and reproducible generated assets verified.');
} else {
  await mkdir(resolve(root, 'js/generated'), { recursive: true });
  for (const [name, bytes] of outputs) await writeFile(resolve(root, `js/generated/${name}`), bytes);
  await writeFile(resolve(root, 'js/generated/manifest.json'), manifest);
  console.log('Pinned verdict accepted; static Bend assets and manifest rebuilt.');
}
