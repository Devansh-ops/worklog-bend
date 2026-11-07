import assert from 'node:assert/strict';
import core from '../js/generated/core.mjs';
import reports from '../js/generated/reports.mjs';
const list = values => values.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
const array = value => { const result = []; for (let n = value; n.$ === 'Con'; n = n.tail) result.push(n.head); return result; };
const event = (id, payload, hour = 9, day = '2026-11-01') => {
  const e = { $: 'Ev', id, ts: `${day}T${String(hour).padStart(2, '0')}:00:00.000Z`, day, payload };
  return { ...e, canonical: JSON.stringify(e) };
};
const create = (taskId, values = {}) => ({ $: 'Created', taskId, title: 'The work', status: { $: 'STodo' }, priority: { $: 'PNormal' }, tags: list([]), private: false, ...values });
const a = event('create-a', create('T-aaa111', { title: 'The migration', tags: list([' Ingest ']) }));
const b = event('create-b', create('T-bbb222', { title: 'Trace the race', status: { $: 'SProgress' } }), 8, '2026-10-31');
const n1 = event('note-a', { $: 'Noted', taskId: 'T-aaa111', text: 'swapped\n the driver.' }, 10);
const n2 = event('note-b', { $: 'Noted', taskId: 'T-aaa111', text: 'tests\u00a0still failing...' }, 14);
const moved = event('moved-b', { $: 'StatusChanged', taskId: 'T-bbb222', status: { $: 'SBlocked' } }, 11);
const run = (events, { sendNotes = true, morning = false, includePlan = false, day = '2026-11-01' } = {}) => {
  const state = core.replay(list(events)); assert.equal(state.$, 'Replayed');
  return array(reports.report_items(state.state, list(events), sendNotes, day, morning, includePlan));
};
let count = 0;
const check = (name, fn) => { fn(); count++; console.log(`PASS ${name}`); };
check('pure report string shaping handles scalar whitespace, ellipses and empty fragments', () => {
  assert.equal(reports.one_line(' \tHi\u00a0\n\u2003there  🚀\ufeff'), 'Hi there 🚀');
  assert.equal(reports.fragment('Shipped.'), 'Shipped');
  assert.equal(reports.fragment('Still looking...'), 'Still looking...');
  assert.equal(reports.fragment('.'), '');
});
check('evening picks one chronological item per touched task and ordered daily notes', () => {
  const result = run([n2, b, moved, a, n1, n1]);
  assert.deepEqual(result.map(i => i.taskId), ['T-aaa111', 'T-bbb222']);
  assert.deepEqual(array(result[0].didToday), ['swapped the driver', 'tests still failing...']);
  assert.equal(result[0].task, 'The migration'); assert.equal(result[0].project, 'Ingest');
  assert.equal(result[1].project, 'Misc'); assert.deepEqual(array(result[1].didToday), []);
});
check('notes disabled still includes a task touched only by a note using title fallback', () => {
  const onlyPriorCreate = event('old-a', a.payload, 8, '2026-10-31');
  const result = run([onlyPriorCreate, n1], { sendNotes: false });
  assert.equal(result.length, 1); assert.equal(result[0].task, 'The migration');
  assert.deepEqual(array(result[0].didToday), []); assert.equal(JSON.stringify(result).includes('swapped'), false);
});
check('task edits alone are bookkeeping and do not invent an evening work item', () => {
  const old = event('old-a', a.payload, 8, '2026-10-31');
  const edited = event('edit', { $: 'Edited', taskId: 'T-aaa111', patch: { $: 'Patch', title: { $: 'Some', value: 'Renamed' }, status: { $: 'None' }, priority: { $: 'None' }, tags: { $: 'None' }, private: { $: 'None' } } });
  assert.deepEqual(run([old, edited]), []);
});
check('morning plan is opt-in and contains only public live in-flight and blocked tasks', () => {
  assert.deepEqual(run([a, b], { morning: true }), []);
  const secret = event('secret', create('T-secret', { private: true, status: { $: 'SProgress' } }));
  const finished = event('done', create('T-done', { status: { $: 'SDone' } }));
  const result = run([a, b, secret, finished], { morning: true, includePlan: true });
  assert.deepEqual(result.map(i => i.taskId), ['T-bbb222']); assert.deepEqual(array(result[0].didToday), []);
});
check('deleted/private history and outside-day events cannot enter report selection', () => {
  const secret = event('secret', create('T-secret', { title: 'CANARY_PRIVATE', private: true }));
  const deleted = event('deleted', { $: 'Deleted', taskId: 'T-aaa111' }, 15);
  const result = run([a, n1, secret, b, deleted]);
  assert.deepEqual(result, []);
});
check('model report values have no internal IDs or timestamp fields', () => {
  const events = [a, n1, b, moved]; const state = core.replay(list(events)).state;
  const result = array(reports.model_report(state, list(events), true, '2026-11-01', false, false));
  for (const item of result) assert.deepEqual(Object.keys(item).sort(), ['$', 'didToday', 'project', 'task']);
  assert.equal(JSON.stringify(result).includes('T-aaa111'), false);
});
check('incomplete semantic history and conflicting event content fail closed', () => {
  assert.deepEqual(run([event('opaque', { $: 'Opaque', kind: 'future.kind' }), a]), []);
  const known = core.replay(list([a])).state;
  assert.deepEqual(array(reports.report_items(known, list([a, { ...a, canonical: a.canonical + 'different' }]), true, '2026-11-01', false, false)), []);
});
check('reminder exhaustive boolean conditions agree with independent decision table', () => {
  for (const enabled of [false, true]) for (const fired of [false, true]) for (const pending of [false, true]) for (const summary of [false, true]) for (const signoff of [false, true]) {
    for (const now of [0, 1049, 1050, 1439, 1440]) {
      const actual = reports.reminder_decision(enabled, fired, now, 1050, pending, summary, signoff);
      const due = enabled && !fired && now >= 1050 && now < 1440 && (pending || !summary || !signoff);
      assert.equal(actual.$, due ? 'ReminderDue' : 'ReminderOff');
      if (due) assert.deepEqual(actual, { $: 'ReminderDue', pending, missingSummary: !summary, missingSignOff: !signoff });
    }
  }
  assert.deepEqual(reports.reminder_decision(true, false, 1439, 1440, true, false, false), { $: 'ReminderOff' });
});
console.log(`${count} Bend-generated report/reminder checks passed; runtime evidence only`);
