import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const verdict = process.argv.includes('--verdict');
function bend(args, expected, pattern) {
  const result = spawnSync(process.execPath, [resolve(root, 'scripts/bend.mjs'), ...args], {
    cwd: root, env: process.env, encoding: 'utf8', timeout: 300000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.error, undefined, output);
  assert.equal(result.status, expected, output);
  assert.match(output, pattern, output);
  console.log(`${args.join(' ')}: exit ${result.status}`);
  return output;
}
const proofArgs = verdict ? ['--verdict'] : [];
const evidence = {
  mode: verdict ? 'BendTT verdict' : 'standard checker only',
  version: bend(['version'], 0, /bend 2\.0\.40/).trim(),
  true: bend(['toolchain/smoke/true.bend', ...proofArgs], 0, /ALL PROOFS CHECK/),
  false: bend(['toolchain/smoke/false.bend', ...proofArgs], 1, /SOME PROOFS FAIL|Type mismatch/),
  open: bend(['toolchain/smoke/open.bend', ...proofArgs], 1, /SOME PROOFS FAIL|TODO/),
  termination: bend(['toolchain/smoke/nonterminating.bend', ...proofArgs], 1, /SOME PROOFS FAIL|recursive|termination/i),
};
if (process.platform === 'win32') {
  evidence.imports = 'Not supported natively by this pin; use the validated WSL route';
  console.warn('SKIP multi-module build on native Windows: pinned compiler path bug; use WSL');
} else {
  evidence.imports = bend(['toolchain/smoke/imported.bend', ...proofArgs], 0, /ALL PROOFS CHECK/);
  bend(['toolchain/smoke/imported.bend', '-o', '.toolchain/imported.mjs'], 0, /(?:)/);
  const { default: imported } = await import(pathToFileURL(resolve(root, '.toolchain/imported.mjs')).href);
  assert.equal(imported.via_import(42), 42);
}
bend(['toolchain/smoke/bridge.bend', '-o', '.toolchain/bridge.mjs'], 0, /(?:)/);
const { default: core } = await import(pathToFileURL(resolve(root, '.toolchain/bridge.mjs')).href);
assert.equal(core.keep('Synthetic \u03bb \ud83d\ude80'), 'Synthetic \u03bb \ud83d\ude80');
assert.equal(core.keep('\ud800'), '\ufffd');
assert.deepEqual(core.task('T-synthetic', true, 7), { $: 'Task', id: 'T-synthetic', private: true, count: 7 });
assert.deepEqual([core.invert(true), core.invert(false)], [false, true]);
assert.equal(core.sum({ $: 'Con', head: 2, tail: { $: 'Con', head: 3, tail: { $: 'Nil' } } }, 0), 5);
assert.equal(core.wrap(4294967295), 0);
assert.deepEqual(core.checked(true, 4), { $: 'Accepted', value: 4 });
assert.deepEqual(core.checked(false, 4), { $: 'Rejected', reason: 'invalid input' });
const original = [1, 2], owned = original.slice();
assert.equal(core.overwrite(owned), owned);
assert.deepEqual(owned, [9, 2]);
assert.deepEqual(original, [1, 2]);
// Boundary validation is required: the generated exports do not reject wrong host types.
assert.equal(core.wrap(-1), 0);
evidence.bridge = { checks: 'strings, unicode replacement, bool, constructor, list, U32 wrap, typed errors, array ownership', moduleSha256: createHash('sha256').update(await readFile(resolve(root, '.toolchain/bridge.mjs'))).digest('hex') };
await mkdir(resolve(root, '.toolchain/evidence'), { recursive: true });
await writeFile(resolve(root, `.toolchain/evidence/${verdict ? 'verdict' : 'standard'}.json`), JSON.stringify(evidence, null, 2) + '\n');
console.log(`Bend ${evidence.mode} and actual generated JavaScript smoke passed`);
