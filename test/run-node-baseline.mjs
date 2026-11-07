// Run the inherited JSC suites with reviewed Bend-contract fixture updates in isolated Node processes.
// These suites deliberately shim browser APIs; this is not browser evidence.
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const suites = readdirSync(new URL('./', import.meta.url)).filter(n => n.endsWith('.test.js')).sort();
let failures = 0;
let checks = 0;
for (const zone of ['Asia/Kolkata', 'Pacific/Kiritimati', 'Pacific/Niue', 'UTC']) {
  for (const suite of suites) {
    const url = new URL(suite, import.meta.url).href;
    const script = `globalThis.print = console.log.bind(console); globalThis.quit = code => process.exit(code); for (const key of ['crypto', 'navigator']) Object.defineProperty(globalThis, key, { value: undefined, configurable: true, writable: true }); await import(${JSON.stringify(url)});`;
    const result = spawnSync(process.execPath, ['--input-type=module', '-e', script], {
      cwd: root, env: { ...process.env, TZ: zone }, encoding: 'utf8', timeout: 60000,
    });
    const output = result.stdout + result.stderr;
    const summary = output.match(/[^\r\n]+: (\d+) passed, (\d+) failed/);
    checks += summary ? Number(summary[1]) + Number(summary[2]) : 0;
    if (result.status !== 0 || result.error || !summary) {
      failures++;
      console.error(`FAIL ${zone} ${suite}\n${output}\n${result.error || ''}`);
    } else {
      console.log(`${zone} ${suite}: ${summary[1]} passed`);
    }
  }
}
console.log(`${suites.length * 4} suite executions, ${checks} assertions, ${failures} failed executions`);
process.exitCode = failures ? 1 : 0;
