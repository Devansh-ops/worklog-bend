import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFile, writeFile, mkdir, mkdtemp } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const wrapper = resolve(process.env.BEND_LINUX_WRAPPER || join(root, 'scripts/bend-linux.sh'));
const wslPath = path => path.replace(/^([A-Za-z]):[\\/]/, (_, drive) => `/mnt/${drive.toLowerCase()}/`).replaceAll('\\', '/');
function check(cwd, expectedStatus, expectedOutput) {
  const result = process.platform === 'win32'
    ? spawnSync('wsl.exe', ['--distribution', 'Ubuntu', '--exec', 'sh', wslPath(wrapper), 'PROOF.bend', '--verdict'], { cwd, encoding: 'utf8', timeout: 300000 })
    : spawnSync('sh', [wrapper, 'PROOF.bend', '--verdict'], { cwd, encoding: 'utf8', timeout: 300000 });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.error, undefined, output);
  assert.equal(result.status, expectedStatus, output);
  assert.match(output, expectedOutput);
  return output;
}

check(root, 0, /ALL PROOFS CHECK/);
const core = await readFile(join(root, 'bend/Core.bend'), 'utf8');
const mutations = [
  {
    name: 'notes-off leak',
    source: 'case False{}:\n      Nil{}\n    case True{}:\n      notes',
    replacement: 'case False{}:\n      notes\n    case True{}:\n      notes',
    failure: /notes_off_omits_all_direct_notes|notes_off_context_has_no_notes/,
  },
  {
    name: 'private-task leak',
    source: 'Bool.and(Bool.not(private), Bool.not(deleted))',
    replacement: 'Bool.not(deleted)',
    failure: /private_is_ineligible|private_context_head_is_omitted/,
  },
];
await mkdir(join(root, 'tmp'), { recursive: true });
for (const mutation of mutations) {
  const normalized = core.replaceAll('\r\n', '\n');
  assert.equal(normalized.split(mutation.source).length, 2, `Mutation must match exactly once: ${mutation.name}`);
  const target = await mkdtemp(join(root, 'tmp/proof-negative-'));
  await mkdir(join(target, 'bend'));
  for (const name of ['LAWS.bend', 'PROOF.bend', 'bend/Types.bend']) {
    await writeFile(join(target, name), await readFile(join(root, name)));
  }
  await writeFile(join(target, 'bend/Core.bend'), normalized.replace(mutation.source, mutation.replacement));
  const output = check(target, 1, mutation.failure);
  assert.match(output, /SOME PROOFS FAIL/);
  await writeFile(join(target, 'result.txt'), output);
  console.log(`Rejected ${mutation.name}: expected domain law failed (exit 1). Evidence: ${target}`);
}
console.log('Positive verdict and production-source mutation-negative proof checks passed.');
