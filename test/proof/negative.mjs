import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFile, writeFile, mkdir, mkdtemp, readdir } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const wrapper = resolve(process.env.BEND_LINUX_WRAPPER || join(root, 'scripts/bend-linux.sh'));
const wslPath = path => path.replace(/^([A-Za-z]):[\\/]/, (_, drive) => `/mnt/${drive.toLowerCase()}/`).replaceAll('\\', '/');
function check(cwd, expectedStatus, expectedOutput, file = 'PROOF.bend') {
  const result = process.platform === 'win32'
    ? spawnSync('wsl.exe', ['--distribution', 'Ubuntu', '--exec', 'sh', wslPath(wrapper), file, '--verdict'], { cwd, encoding: 'utf8', timeout: 300000 })
    : spawnSync('sh', [wrapper, file, '--verdict'], { cwd, encoding: 'utf8', timeout: 300000 });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.error, undefined, output);
  assert.equal(result.status, expectedStatus, output);
  assert.match(output, expectedOutput);
  return output;
}

check(root, 0, /ALL PROOFS CHECK/);
const witnesses = 'test/proof/mutation-witnesses.bend';
check(root, 0, /ALL PROOFS CHECK/, witnesses);
const mutations = [
  {
    name: 'notes-off leak',
    file: 'Core.bend',
    source: 'case False{}:\n      Nil{}\n    case True{}:\n      notes',
    replacement: 'case False{}:\n      notes\n    case True{}:\n      notes',
    failure: /notes_off_omits_all_direct_notes|notes_off_context_has_no_notes/,
  },
  {
    name: 'private-task leak',
    file: 'Core.bend',
    source: 'Bool.and(Bool.not(private), Bool.not(deleted))',
    replacement: 'Bool.not(deleted)',
    failure: /private_is_ineligible|private_context_head_is_omitted/,
  },
  {
    name: 'publication schema bypass',
    file: 'Publication.bend',
    source: 'Bool.and(schemas_compatible(schemas), String.eq(approved_plan, execution_plan))',
    replacement: 'String.eq(approved_plan, execution_plan)',
    failure: /future_schema_refused_witness/,
  },
  {
    name: 'publication plan substitution',
    file: 'Publication.bend',
    source: 'Bool.and(schemas_compatible(schemas), String.eq(approved_plan, execution_plan))',
    replacement: 'schemas_compatible(schemas)',
    failure: /changed_plan_refused_witness/,
  },
  {
    name: 'distinct-event omission during merge',
    file: 'Core.bend',
    source: 'case True{}:\n      xs\n    case False{}:\n      e <> xs',
    replacement: 'case True{}:\n      xs\n    case False{}:\n      xs',
    failure: /complete_content_merge_witness|ScanProof.unique_put_invariant|scan_preserves_ids|successful_merge_has_exact_input_ids/,
  },
  {
    name: 'disabled reminder fires',
    file: 'Reports.bend',
    source: 'Bool.and(enabled, Bool.and(Bool.not(alreadyFired),',
    replacement: 'Bool.and(True{}, Bool.and(Bool.not(alreadyFired),',
    failure: /reminder_disabled_witness/,
  },
  {
    name: 'complete-day reminder fires',
    file: 'Reports.bend',
    source: 'reminder_needed(hasPending, hasEveningSummary, hasSignOff)',
    replacement: 'True{}',
    failure: /reminder_complete_day_witness/,
  },
  {
    name: 'report includes ineligible task',
    file: 'Reports.bend',
    source: 'case Some{item} True{}:',
    replacement: 'case Some{item} _:',
    failure: /ReportsProof.ineligible_item|reports_omit_private_head|reports_omit_deleted_head/,
  },
  {
    name: 'conflicting event content accepted',
    file: 'Core.bend',
    source: 'Bool.and(same, Bool.not(event_eq(h, p)))',
    replacement: 'False{}',
    failure: /collision_refusal_witness/,
  },
  {
    name: 'complete event content corrupted while ID survives',
    file: 'Core.bend',
    source: 'def unique_put(e: T.DomainEvent, xs: List<&2, T.DomainEvent>, exists: Bool) -> List<&2, T.DomainEvent>:\n  match exists:\n    case True{}:\n      xs\n    case False{}:\n      e <> xs',
    replacement: 'def mutation_tamper(event: T.DomainEvent) -> T.DomainEvent:\n  match event:\n    case T.Ev{id, ts, day, payload, canonical}:\n      T.Ev{id, ts, day, payload, "MUTATED"}\n\ndef unique_put(e: T.DomainEvent, xs: List<&2, T.DomainEvent>, exists: Bool) -> List<&2, T.DomainEvent>:\n  match exists:\n    case True{}:\n      xs\n    case False{}:\n      mutation_tamper(e) <> xs',
    failure: /complete_content_merge_witness/,
  },
  {
    name: 'duplicate event retained in merge output',
    file: 'Core.bend',
    source: 'case True{}:\n      xs\n    case False{}:\n      e <> xs',
    replacement: 'case True{}:\n      e <> xs\n    case False{}:\n      e <> xs',
    failure: /scan_identical_pair|duplicate_delivery_single_event|successful_merge_has_unique_ids/,
  },
  {
    name: 'new command accepted before its task creation',
    file: 'Core.bend',
    source: 'stage_candidate_replayed(replay(List.append(&2, T.DomainEvent, existing, [event])), event)',
    replacement: 'T.StageAccepted{event}',
    failure: /clock_rollback_command_is_rejected/,
  },
];
await mkdir(join(root, 'tmp'), { recursive: true });
for (const mutation of mutations) {
  const normalized = (await readFile(join(root, 'bend', mutation.file), 'utf8')).replaceAll('\r\n', '\n');
  assert.equal(normalized.split(mutation.source).length, 2, `Mutation must match exactly once: ${mutation.name}`);
  const target = await mkdtemp(join(root, 'tmp/proof-negative-'));
  await mkdir(join(target, 'bend'));
  await mkdir(join(target, 'proof'));
  await mkdir(join(target, 'test/proof'), { recursive: true });
  const modules = (await readdir(join(root, 'bend'))).filter(name => name.endsWith('.bend')).map(name => `bend/${name}`);
  const proofModules = (await readdir(join(root, 'proof'))).filter(name => name.endsWith('.bend')).map(name => `proof/${name}`);
  for (const name of ['LAWS.bend', 'PROOF.bend', witnesses, ...modules, ...proofModules]) {
    await writeFile(join(target, name), await readFile(join(root, name)));
  }
  await writeFile(join(target, 'bend', mutation.file), normalized.replace(mutation.source, mutation.replacement));
  const output = check(target, 1, mutation.failure, witnesses);
  assert.match(output, /SOME PROOFS FAIL/);
  const fullGate = check(target, 1, /SOME PROOFS FAIL/);
  await writeFile(join(target, 'result.txt'), `${output}\n\nFull root proof gate:\n${fullGate}`);
  console.log(`Rejected ${mutation.name}: expected domain law failed (exit 1). Evidence: ${target}`);
}
console.log('Positive verdict and production-source mutation-negative proof checks passed.');
