import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
for (const script of ['scripts/test-bend-browser.mjs', 'scripts/test-browser-demo.mjs', 'test/ai-browser.mjs', 'test/browser-workflow.mjs', 'test/browser-vault.mjs']) {
  const result = spawnSync(process.execPath, [resolve(root, script)], { cwd: root, stdio: 'inherit', timeout: 180000 });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
console.log('Five real browser gates passed with synthetic data and isolated contexts.');
