import assert from 'node:assert/strict';
import planning from '../js/generated/planning.mjs';

const list = values => values.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
const array = node => { const values = []; for (; node.$ !== 'Nil'; node = node.tail) { assert.equal(node.$, 'Con'); values.push(node.head); } return values; };
const create = (id, month, values = {}) => {
  const result = { $: 'Ev', id, ts: `${month}-01T09:00:00.000Z`, day: `${month}-01`,
    payload: { $: 'Created', taskId: `T-${id}`, title: `Synthetic ${id}`, status: { $: 'STodo' }, priority: { $: 'PNormal' }, tags: list([]), private: false }, ...values };
  return { ...result, canonical: JSON.stringify(result) };
};
const source = (month, events = [], currentExists = true, legacyExists = false) => ({ $: 'SourceMonth', month, currentExists, legacyExists, events: list(events) });
const plan = (sources, pending = [], migration = false, schemas = [2], current = '2026-11') => planning.plan(list(schemas), list(sources), list(pending), current, migration);
const groups = result => { assert.equal(result.$, 'Planned', result.reason); return array(result.groups); };
let checks = 0;
function check(name, run) { run(); checks++; console.log(`PASS ${name}`); }

check('normal publication writes only pending or relocated months in scalar month order', () => {
  const old = create('old', '2026-09'), next = create('next', '2026-11');
  const result = plan([source('2026-09', [old])], [next]);
  assert.deepEqual(groups(result).map(group => [group.month, group.write, group.count, group.days]), [['2026-09', false, 1, 1], ['2026-11', true, 1, 1]]);
  assert.deepEqual(array(result.events).map(event => event.id), ['old', 'next']);
});
check('backdated/local-month relocation writes the original physical source and destination', () => {
  const boundary = create('boundary', '2026-11', { ts: '2026-11-01T00:15:00.000Z', day: '2026-10-31' });
  const result = plan([source('2026-11', [boundary])]);
  assert.deepEqual(groups(result).map(group => [group.month, group.write, group.count]), [['2026-10', true, 1], ['2026-11', true, 0]]);
  assert.equal(groups(result)[1].hadCurrent, true);
});
check('legacy and current duplicate deliveries preserve full content exactly once', () => {
  const event = create('duplicate', '2026-09');
  const result = plan([source('2026-09', [event], true, false), source('2026-09', [event], false, true)], [], true);
  const month = groups(result).find(group => group.month === '2026-09');
  assert.equal(month.count, 1); assert.equal(month.hadCurrent, true); assert.equal(month.hadLegacy, true);
  assert.equal(month.deleteLegacy, true); assert.equal(month.write, true);
  assert.deepEqual(array(month.events), [event]);
});
check('full migration keeps empty source months for host extension metadata and safely relocates legacy events', () => {
  const boundary = create('legacy-boundary', '2026-11', { day: '2026-10-31' });
  const result = plan([source('2026-11', [boundary], false, true), source('2026-08', [], true, false)], [], true);
  assert.deepEqual(groups(result).map(group => [group.month, group.count, group.write, group.deleteLegacy]), [
    ['2026-08', 0, true, false], ['2026-10', 1, true, false], ['2026-11', 0, true, true],
  ]);
  assert.deepEqual(array(groups(result)[1].events), [boundary]);
});
check('conflicting full event content and unsupported semantics return no write collection', () => {
  const a = create('collision', '2026-11'), b = { ...a, canonical: a.canonical + 'changed' };
  for (const result of [plan([source('2026-11', [a, b])]), plan([source('2026-11', [create('opaque', '2026-11', { payload: { $: 'Opaque', kind: 'future.operation' } })])])]) {
    assert.equal(result.$, 'PlanningRefused'); assert.deepEqual(array(planning.writes(result)), []);
  }
});
check('future versions are refused at arbitrary list positions before a plan is emitted', () => {
  const value = source('2026-11', [create('future', '2026-11')], false, true);
  for (const schemas of [[999], [1, 999, 2], [0], [3, 1]]) {
    const result = plan([value], [], true, schemas);
    assert.deepEqual(result, { $: 'PlanningRefused', reason: 'unsupported source schema' });
    assert.deepEqual(array(planning.writes(result)), []);
  }
});
check('source facts without physical coverage cannot smuggle nonempty history', () => {
  const result = plan([source('2026-11', [create('uncovered', '2026-11')], false, false)]);
  assert.equal(result.$, 'PlanningRefused');
});
check('postflight validation rejects lost pending data, wrong-month output and unsafe legacy deletion', () => {
  const event = create('kept', '2026-11');
  const valid = groups(plan([source('2026-11', [event], false, true)], [], true));
  assert.equal(planning.checks(list([2]), list([source('2026-11', [event], false, true)]), list([]), list([event]), list(valid), true), true);
  const wrong = { ...valid[0], month: '2026-10' };
  assert.equal(planning.checks(list([2]), list([source('2026-11', [event], false, true)]), list([]), list([event]), list([wrong]), true), false);
  const dropped = { ...valid[0], events: list([]), count: 0 };
  assert.equal(planning.checks(list([2]), list([source('2026-11', [event], false, true)]), list([]), list([event]), list([dropped]), true), false);
  assert.equal(planning.deletions_safe(list(valid), list(valid), list([source('2026-11', [event], false, true)]), false), false);
});
check('day counts are distinct and planning preserves caller-owned values', () => {
  const a = create('one', '2026-11'), b = create('two', '2026-11'), c = create('three', '2026-11', { day: '2026-11-02', ts: '2026-11-02T09:00:00.000Z' });
  const facts = [source('2026-11', [a, b, c])], before = structuredClone(facts);
  const result = plan(facts, [], true);
  assert.equal(groups(result)[0].count, 3); assert.equal(groups(result)[0].days, 2);
  assert.deepEqual(facts, before);
});
check('one thousand physical months retain all events and only the new month becomes dirty', () => {
  const facts = Array.from({ length: 1000 }, (_, index) => {
    const month = `${2026 + Math.floor(index / 12)}-${String(index % 12 + 1).padStart(2, '0')}`;
    return source(month, [create(String(index).padStart(4, '0'), month)]);
  });
  const next = create('next-large', '2110-01');
  const began = performance.now(), result = plan(facts, [next], false, [1, 2], '2110-01');
  assert.equal(array(result.events).length, 1001);
  assert.deepEqual(groups(result).filter(group => group.write).map(group => group.month), ['2110-01']);
  console.log(`Planning 1001 events across 1001 months: ${Math.round(performance.now() - began)} ms`);
});
console.log(`${checks} generated Bend planning checks passed; finite runtime evidence only`);
