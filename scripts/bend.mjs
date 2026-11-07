import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lock = JSON.parse(await readFile(resolve(root, 'toolchain/bend.lock.json'), 'utf8'));
for (const [name, expected] of Object.entries(lock.files)) {
  const bytes = await readFile(resolve(root, '.toolchain/bend', name));
  if (createHash('sha256').update(bytes).digest('hex') !== expected) throw new Error(`Compiler integrity mismatch: ${name}`);
}
// Keep compiler update metadata and kernel caches inside this checkout.
const home = resolve(root, '.toolchain/home');
await mkdir(home, { recursive: true });
const bun = process.env.BUN || 'bun';
const version = spawnSync(bun, ['--version'], { encoding: 'utf8' });
if (version.status !== 0 || version.stdout.trim() !== lock.bun) {
  throw new Error(`Bun ${lock.bun} required; set BUN to that executable`);
}
// Disable project-specific preload configuration and automatic .env loading.
const config = resolve(home, 'empty-bunfig.toml');
await writeFile(config, '# Deliberately empty project compiler configuration.\n');
const args = process.argv.slice(2);
const result = spawnSync(bun, ['--no-env-file', `--config=${config}`, resolve(root, '.toolchain/bend/bend2/main.ts'), ...args], {
  cwd: root, stdio: 'inherit', env: { ...process.env, USERPROFILE: home, HOME: home, BEND_NO_TELEMETRY: '1' },
});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
