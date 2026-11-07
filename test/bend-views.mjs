import assert from 'node:assert/strict';
import core from '../js/generated/core.mjs';
import views from '../js/generated/views.mjs';

const list = values => values.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
const array = values => { const result = []; for (let n = values; n.$ === 'Con'; n = n.tail) result.push(n.head); return result; };
const payload = (taskId, values = {}) => ({ $: 'Created', taskId, title: `Task ${taskId}`, status: { $: 'STodo' }, priority: { $: 'PNormal' }, tags: list([]), private: false, ...values });
const event = (id, body, hour = 9, day = '2026-11-01') => {
  const e = { $: 'Ev', id, ts: `${day}T${String(hour).padStart(2, '0')}:00:00.000Z`, day, payload: body };
  return { ...e, canonical: JSON.stringify(e) };
};
const a = event('a', payload('T-a', { title: 'Plan ΛAUNCH with İZMİR', priority: { $: 'PHigh' }, tags: list(['ingest', 'ingest', 'team']) }), 10);
const b = event('b', payload('T-b', { title: 'Review concurrency', priority: { $: 'PUrgent' }, status: { $: 'SBlocked' }, tags: list(['team']) }), 9);
const c = event('c', payload('T-c', { title: 'Notes on storage', priority: { $: 'PHigh' }, private: true, tags: list(['store']) }), 11);
const d = event('d', payload('T-d', { title: 'Another high task', priority: { $: 'PHigh' } }), 11);
const note = event('note', { $: 'Noted', taskId: 'T-a', text: 'Need\n WAL replay' }, 12);
const deleted = event('deleted', { $: 'Deleted', taskId: 'T-b' }, 13);
const events = [d, a, c, b, note];
const state = values => { const result = core.replay(list(values)); assert.equal(result.$, 'Replayed'); return result.state; };
const s = state(events);
const ids = tasks => array(tasks).map(t => t.id);
const keys = state => list(array(views.live_state(state)).map(task => ({ $: 'SearchKey', taskId: task.id, foldedText: views.search_text(task).toLowerCase() })));
const query = text => text.trim().toLowerCase();
let checks = 0;
const check = (name, fn) => { fn(); checks++; console.log(`PASS ${name}`); };

check('board sorts by priority then updated recency with stable scalar ID ties', () => {
  assert.deepEqual(ids(views.board_tasks(s)), ['T-b', 'T-a', 'T-c', 'T-d']);
  assert.deepEqual(ids(views.wiki_tasks(s)), ['T-a', 'T-c', 'T-d', 'T-b']);
  assert.deepEqual(ids(views.board_tasks(state(events.toReversed()))), ['T-b', 'T-a', 'T-c', 'T-d']);
});
check('the owner board includes private tasks but excludes tombstones', () => {
  assert.deepEqual(ids(views.board_tasks(state([...events, deleted]))), ['T-a', 'T-c', 'T-d']);
  assert.equal(views.wiki_task(state([...events, deleted]), 'T-b').value.deleted, true);
  assert.deepEqual(views.wiki_task(s, 'T-absent'), { $: 'None' });
});
check('status selectors and all six counters agree without losing empty columns', () => {
  assert.deepEqual(ids(views.status_tasks(s, { $: 'SBlocked' })), ['T-b']);
  assert.deepEqual(ids(views.status_tasks(s, { $: 'STodo' })), ['T-a', 'T-c', 'T-d']);
  const result = array(views.status_counts(s));
  assert.deepEqual(result.map(c => c.status.$), ['SBacklog', 'STodo', 'SProgress', 'SBlocked', 'SReview', 'SDone']);
  assert.deepEqual(result.map(c => c.count), [0, 3, 0, 1, 0, 0]);
  assert.equal(result.reduce((n, c) => n + c.count, 0), 4);
});
check('Bend search projection owns IDs, title, ordered tags and note text', () => {
  const task = views.wiki_task(s, 'T-a').value;
  assert.equal(views.search_text(task), 'T-a Plan ΛAUNCH with İZMİR ingest ingest team Need\n WAL replay');
  for (const text of ['T-A', 'launch', 'INGEST', 'wal REPLAY']) {
    // Query boundaries preserve exact whitespace, as the original substring UI did.
    const expected = text === 'launch' ? [] : ['T-a'];
    assert.deepEqual(ids(views.search_tasks(s, keys(s), query(text))), expected);
  }
});
check('explicit native Unicode folding preserves Greek and expanding dotted-I searches', () => {
  assert.deepEqual(ids(views.search_tasks(s, keys(s), query('λaunch'))), ['T-a']);
  assert.deepEqual(ids(views.search_tasks(s, keys(s), query('İZMİR'))), ['T-a']);
  assert.deepEqual(ids(views.search_tasks(s, keys(s), 'i\u0307zmi\u0307r')), ['T-a']);
});
check('empty query includes live tasks; missing normalized keys fail closed for nonempty queries', () => {
  assert.deepEqual(ids(views.search_tasks(s, list([]), '')), ['T-b', 'T-a', 'T-c', 'T-d']);
  assert.deepEqual(ids(views.search_tasks(s, list([]), 'plan')), []);
  assert.deepEqual(ids(views.search_tasks(state([...events, deleted]), keys(s), 'review')), []);
});
check('wiki search applies recency order independently of board priority', () => {
  assert.deepEqual(ids(views.wiki_search_tasks(s, keys(s), 't-')), ['T-a', 'T-c', 'T-d', 'T-b']);
});
check('tag counts count tasks once despite duplicate tags, sort count then scalar name', () => {
  assert.deepEqual(array(views.tag_index(s)), [
    { $: 'TagCount', tag: 'team', count: 2 }, { $: 'TagCount', tag: 'ingest', count: 1 }, { $: 'TagCount', tag: 'store', count: 1 },
  ]);
  assert.deepEqual(ids(views.tag_tasks(s, 'team')), ['T-a', 'T-b']);
  assert.deepEqual(ids(views.tag_tasks(state([...events, deleted]), 'team')), ['T-a']);
});
check('related tasks share exact tags, exclude self and deleted, preserve private owner visibility', () => {
  assert.deepEqual(ids(views.related_tasks(s, 'T-a')), ['T-b']);
  assert.deepEqual(ids(views.related_tasks(state([...events, deleted]), 'T-a')), []);
  assert.deepEqual(ids(views.related_tasks(s, 'T-absent')), []);
});
check('task history and journal canonicalize duplicate deliveries and supplied calendar days', () => {
  const old = event('old', { $: 'Noted', taskId: 'T-a', text: 'old' }, 23, '2026-10-31');
  const history = [...events, old, note];
  assert.deepEqual(array(views.task_history(list(history), 'T-a')).map(e => e.id), ['old', 'a', 'note']);
  assert.deepEqual(array(views.day_events(list(history), '2026-10-31')).map(e => e.id), ['old']);
  assert.deepEqual(array(views.day_index(list(history))), [
    { $: 'DayCount', day: '2026-11-01', count: 5 }, { $: 'DayCount', day: '2026-10-31', count: 1 },
  ]);
});
check('day record selectors retain latest content and consistently order morning before evening', () => {
  const records = [
    event('evening', { $: 'SummarySet', date: '2026-11-01', kind: 'evening', body: '{"headline":"Evening"}' }, 18),
    event('morning', { $: 'SummarySet', date: '2026-11-01', kind: 'morning', body: '{"headline":"Morning"}' }, 8),
    event('report', { $: 'StandupSet', date: '2026-11-01', kind: 'evening', text: 'Copied exactly' }, 19),
  ];
  const stateWithRecords = state(records);
  assert.deepEqual(array(views.day_summaries(stateWithRecords, '2026-11-01')).map(r => r.kind), ['morning', 'evening']);
  assert.equal(array(views.day_reports(stateWithRecords, '2026-11-01'))[0].body, 'Copied exactly');
  assert.deepEqual(array(views.day_reports(stateWithRecords, '2026-11-02')), []);
});
check('conflicting historical identity never produces a misleading partial journal', () => {
  const conflict = list([a, { ...a, canonical: a.canonical + 'altered' }]);
  assert.deepEqual(array(views.task_history(conflict, 'T-a')), []);
  assert.deepEqual(array(views.day_index(conflict)), []);
});
check('all projection functions preserve caller-owned values', () => {
  const before = JSON.stringify(s); const input = list(events); const inputBefore = JSON.stringify(input);
  views.board_tasks(s); views.tag_index(s); views.status_counts(s); views.search_tasks(s, keys(s), 'plan'); views.day_index(input);
  assert.equal(JSON.stringify(s), before); assert.equal(JSON.stringify(input), inputBefore);
});
console.log(`${checks} Bend-generated board/search/wiki projection checks passed; finite runtime evidence only`);
