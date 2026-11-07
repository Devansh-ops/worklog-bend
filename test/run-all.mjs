import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tests = [
  'run-node-baseline.mjs', 'cli-real-smoke.mjs', 'codec-boundary.mjs',
  'bend-core.mjs', 'bend-reports.mjs', 'bend-views.mjs', 'bend-planning.mjs', 'domain-bridge.mjs',
  'store-integration.mjs', 'source-cache.mjs', 'bootstrap-plan.mjs',
  'ai-privacy.mjs', 'ai-provider-contracts.mjs', 'release-check.mjs', 'setup-cli.mjs', 'view-effects.mjs',
];
let failed = 0;
for (const test of tests) {
  const result = spawnSync(process.execPath, [resolve(root, 'test', test)], { cwd: root, stdio: 'inherit', timeout: 120000 });
  if (result.error || result.status !== 0) { failed++; console.error(`FAILED ${test}: ${result.error?.message || result.status}`); }
}
console.log(`${tests.length} runtime/adapter suites executed; ${failed} failed. Browser and proof gates run separately.`);
process.exitCode = failed ? 1 : 0;
