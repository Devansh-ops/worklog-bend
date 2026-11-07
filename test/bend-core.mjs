import assert from 'node:assert/strict';
import core from '../js/generated/core.mjs';

const list = values => values.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
const array = values => {
  const result = [];
  for (let node = values; node.$ !== 'Nil'; node = node.tail) {
    assert.equal(node.$, 'Con'); result.push(node.head);
  }
  return result;
};
const nil = () => ({ $: 'None' });
const some = value => ({ $: 'Some', value });
const status = $ => ({ $ });
const patch = values => ({ $: 'Patch', title: nil(), status: nil(), priority: nil(), tags: nil(), private: nil(), ...values });
const create = (taskId, title = 'Synthetic', values = {}) => ({
  $: 'Created', taskId, title, status: status('STodo'), priority: status('PNormal'), tags: list([]), private: false, ...values,
});
const event = (id, payload, hour = 9, values = {}) => {
  const result = { $: 'Ev', id, ts: `2026-11-01T${String(hour).padStart(2, '0')}:00:00.000Z`, day: '2026-11-01', payload, ...values };
  return { ...result, canonical: JSON.stringify(result) };
};
const merged = (...collections) => {
  const result = collections.reduce((left, right) => {
    const result = core.merge(list(left), list(right)); assert.equal(result.$, 'Merged'); return array(result.events);
  }, []);
  return result;
};
const state = events => {
  const result = core.replay(list(events)); assert.equal(result.$, 'Replayed'); return result.state;
};
let checks = 0;
const check = (name, fn) => { fn(); checks++; console.log(`PASS ${name}`); };
const a = event('a', create('T-aaa111'));
const b = event('b', create('T-bbb222'), 9);
const done = event('done', { $: 'StatusChanged', taskId: 'T-aaa111', status: status('SDone') }, 12);
const note = event('note', { $: 'Noted', taskId: 'T-aaa111', text: 'Synthetic note' }, 10);

check('same-time peers and exact duplicate deliveries survive canonical merge', () => {
  assert.deepEqual(merged([b, a], [a]).map(e => e.id), ['a', 'b']);
});
check('same ID and differing content conflict in both directions', () => {
  const forged = { ...a, payload: create('T-aaa111', 'Different'), canonical: a.canonical };
  assert.deepEqual(core.merge(list([a]), list([forged])), { $: 'EventConflict', id: 'a' });
  assert.deepEqual(core.merge(list([forged]), list([a])), { $: 'EventConflict', id: 'a' });
});
check('forged differing metadata or extension envelope cannot bypass full equality', () => {
  for (const altered of [{ ...a, day: '2026-11-02' }, { ...a, ts: b.ts.replace('09:', '10:') }, { ...a, canonical: a.canonical + ' ' }]) {
    assert.equal(core.merge(list([a]), list([altered])).$, 'EventConflict');
  }
});
check('canonical order uses Unicode scalar order independent of locale', () => {
  const ids = ['e-🚀', 'e-\ue000', 'e-z', 'e-A'];
  assert.deepEqual(merged(ids.map(id => event(id, create(`T-${id}`)))) .map(e => e.id), ['e-A', 'e-z', 'e-\ue000', 'e-🚀']);
});
check('merge union, idempotence, commutativity and associativity on independent generated sets', () => {
  let seed = 117;
  const random = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0);
  const pool = Array.from({ length: 25 }, (_, i) => event(`event-${String(i).padStart(2, '0')}`, create(`T-${i}`), 1 + i % 20));
  for (let i = 0; i < 80; i++) {
    const groups = Array.from({ length: 3 }, () => pool.filter(() => random() % 3 === 0).reverse());
    const [x, y, z] = groups;
    const expected = [...new Map([...x, ...y, ...z].map(e => [e.id, e])).values()].sort((a, b) => a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : a.id < b.id ? -1 : 1);
    assert.deepEqual(merged(x, y, z), expected);
    assert.deepEqual(merged(x, x), merged(x));
    assert.deepEqual(merged(x, y), merged(y, x));
    assert.deepEqual(merged(merged(x, y), z), merged(x, merged(y, z)));
  }
});
check('replay sorts input and retains notes with the same text and timestamp by event identity', () => {
  const result = state([done, note, { ...note, id: 'note-two', canonical: note.canonical + 'two' }, a]);
  const task = array(result.tasks)[0];
  assert.equal(task.status.$, 'SDone'); assert.equal(task.completed.value, done.ts);
  assert.equal(task.updated, done.ts); assert.deepEqual(array(task.notes).map(n => n.id), ['note', 'note-two']);
});
check('created-done and status edits share completion semantics; reopening clears completion', () => {
  const created = event('created', create('T-aaa111', 'Completed', { status: status('SDone') }));
  assert.equal(array(state([created]).tasks)[0].completed.value, created.ts);
  const edited = event('edited', { $: 'Edited', taskId: 'T-aaa111', patch: patch({ status: some(status('SDone')) }) }, 11);
  assert.equal(array(state([a, edited]).tasks)[0].completed.value, edited.ts);
  const reopen = event('reopen', { $: 'StatusChanged', taskId: 'T-aaa111', status: status('STodo') }, 13);
  assert.deepEqual(array(state([a, done, reopen]).tasks)[0].completed, nil());
});
check('title-only edits preserve completion and ordered tags', () => {
  const edited = event('title', { $: 'Edited', taskId: 'T-aaa111', patch: patch({ title: some('Renamed'), tags: some(list(['z', 'a'])) }) }, 13);
  const task = array(state([a, done, edited]).tasks)[0];
  assert.equal(task.title, 'Renamed'); assert.equal(task.completed.value, done.ts); assert.deepEqual(array(task.tags), ['z', 'a']);
});
check('deleted private task keeps tombstone and history but is absent from model context', () => {
  const secret = event('secret', create('T-secret', 'CANARY_PRIVATE', { private: true }));
  const secretNote = event('secret-note', { $: 'Noted', taskId: 'T-secret', text: 'CANARY_NOTE' }, 10);
  const deleted = event('deleted', { $: 'Deleted', taskId: 'T-secret' }, 11);
  const result = state([secret, secretNote, deleted, b]);
  assert.equal(array(result.tasks).find(t => t.id === 'T-secret').private, true);
  assert.equal(array(result.tasks).find(t => t.id === 'T-secret').deleted, true);
  assert.deepEqual(array(core.context(result, true)).map(t => t.id), ['T-bbb222']);
  assert.equal(core.eligible_target(result, 'T-secret'), false);
  assert.equal(JSON.stringify(core.context_events(result, list([secret, secretNote, deleted]), true, '2026-11-01', '2026-11-01')).includes('CANARY'), false);
});
check('notes-off context and historical projection omit automatic note content', () => {
  const events = [a, note, done]; const result = state(events);
  assert.deepEqual(array(array(core.context(result, false))[0].notes), []);
  const context = array(core.context_events(result, list(events), false, '2026-11-01', '2026-11-01'));
  assert.deepEqual(context.map(e => e.kind), ['task.create', 'task.status']);
  assert.equal(JSON.stringify(context).includes(note.payload.text), false);
  assert.deepEqual(array(core.context_events(result, list(events), true, '2026-11-02', '2026-11-03')), []);
});
check('stored reports and summaries persist in state but never enter automatic historical AI context', () => {
  const summary = event('summary', { $: 'SummarySet', date: '2026-11-01', kind: 'morning', body: '{"headline":"CANARY_SUMMARY"}' }, 11);
  const report = event('report', { $: 'StandupSet', date: '2026-11-01', kind: 'evening', text: 'CANARY_REPORT' }, 12);
  const newer = event('report-new', { ...report.payload, text: 'Exactly copied text' }, 13);
  const events = [a, report, summary, newer]; const result = state(events);
  assert.equal(array(result.reports).length, 1); assert.equal(array(result.reports)[0].body, newer.payload.text);
  assert.equal(array(result.summaries)[0].body, summary.payload.body);
  assert.equal(JSON.stringify(core.context_events(result, list(events), true, '2026-11-01', '2026-11-01')).includes('CANARY'), false);
});
check('missing references and opaque history produce explicit incomplete diagnostics', () => {
  const unknown = event('opaque', { $: 'Opaque', kind: 'future.operation' });
  const result = state([note, unknown]);
  assert.equal(result.complete, false); assert.deepEqual(array(result.diagnostics).map(d => d.$), ['Unsupported', 'MissingTask']);
  assert.deepEqual(array(core.context(result, true)), []);
  assert.equal(core.stage(list([note, unknown]), b).$, 'StageRejected');
  assert.equal(state([note, a]).complete, true);
});
check('a deleted task cannot be resurrected by later notes, edits or create', () => {
  const deleted = event('delete', { $: 'Deleted', taskId: 'T-aaa111' }, 11);
  const later = event('later', { $: 'Noted', taskId: 'T-aaa111', text: 'must not apply' }, 12);
  const result = state([a, deleted, later, event('recreate', create('T-aaa111'), 13)]);
  const task = array(result.tasks)[0]; assert.equal(task.deleted, true); assert.deepEqual(array(task.notes), []);
  assert.deepEqual(array(result.diagnostics).map(d => d.$), ['AfterDelete', 'DuplicateCreate']);
});
check('authoritative checkpoint reconciliation includes backdated changes before covered later state', () => {
  const late = event('late', { $: 'StatusChanged', taskId: 'T-aaa111', status: status('SBlocked') }, 11);
  const result = core.reconcile(list([a, done]), list([late, note]));
  assert.deepEqual(result, core.replay(list([a, late, note, done])));
  const task = array(result.state.tasks)[0]; assert.equal(task.status.$, 'SDone'); assert.equal(task.updated, done.ts);
});
check('manual commands validate task existence, deletion, text bounds and duplicate event IDs', () => {
  assert.equal(core.stage(list([]), a).$, 'StageAccepted');
  assert.equal(core.stage(list([a]), a).$, 'StageRejected');
  assert.equal(core.stage(list([]), note).$, 'StageRejected');
  assert.equal(core.stage(list([]), event('blank', create('T-x', '  '))).$, 'StageRejected');
  assert.equal(core.stage(list([]), event('long', create('T-x', 'x'.repeat(201)))).$, 'StageRejected');
  assert.equal(core.stage(list([a]), note).$, 'StageAccepted');
});
check('private manual edits stay supported while model proposals cannot target them', () => {
  const secret = event('secret', create('T-secret', 'Private', { private: true }));
  const change = event('change', { $: 'Noted', taskId: 'T-secret', text: 'Synthetic' }, 11);
  assert.equal(core.stage(list([secret]), change).$, 'StageAccepted');
  assert.equal(core.proposal_stage(list([secret]), change).$, 'StageRejected');
  assert.equal(core.proposal_stage(list([a]), note).$, 'StageAccepted');
});
check('unsupported schemas fail domain write gate', () => {
  assert.deepEqual([0, 1, 2, 3, 999].map(v => core.schema_allowed(v)), [false, true, true, false, false]);
});
check('success acknowledges exact committed events only; failure preserves all pending work', () => {
  const changed = { ...a, canonical: a.canonical + 'changed' };
  assert.deepEqual(array(core.acknowledge(list([a, b, changed]), list([a]), true)), [b, changed]);
  assert.deepEqual(array(core.acknowledge(list([a, b]), list([a]), false)), [a, b]);
});
check('generated core does not mutate caller-owned event/list objects', () => {
  const input = list([a, note, done]); const before = JSON.stringify(input);
  core.replay(input); core.merge(input, input); core.stage(input, b); core.context(state([a, note]), false);
  assert.equal(JSON.stringify(input), before);
});
check('large duplicate history canonicalizes without event loss', () => {
  const events = Array.from({ length: 1200 }, (_, i) => event(`large-${String(i).padStart(5, '0')}`, create(`T-${i}`), 1 + i % 20));
  const result = core.merge(list(events), list(events.toReversed()));
  assert.equal(result.$, 'Merged'); assert.equal(array(result.events).length, events.length);
});
console.log(`${checks} Bend-generated domain behavior checks passed; these are runtime tests, not universal proof claims`);
