import { check, checkAsync, eq, ok, report } from './shim.js';
import {
  foldEvents, unionEvents, makeEvent, newTaskId, Store, STATUSES, statusLabel,
  PATHS, serialiseMonth, renderMonthMd, renderYearReadme, renderChangelogIndex,
  renderBoardMd, renderBoardSnapshot, afterThrough, todayISO,
} from '../js/store.js';

/** Fixed timestamps keep ordering assertions deterministic. */
const ev = (ts, type, payload = {}) => ({ id: `${ts}-${type}`, ts, type, ...payload });

const T1 = 'T-aaa111';
const T2 = 'T-bbb222';

print('\n--- fold ---');

check('create then status then note yields expected task', () => {
  const { tasks } = foldEvents([
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'Fix flaky CI', status: 'todo' }),
    ev('2026-09-17T10:00:00.000Z', 'task.status', { taskId: T1, from: 'todo', to: 'in_progress' }),
    ev('2026-09-17T11:00:00.000Z', 'task.note',   { taskId: T1, text: 'root caused to a race' }),
  ]);
  const t = tasks.get(T1);
  eq(t.title, 'Fix flaky CI');
  eq(t.status, 'in_progress');
  eq(t.notes.length, 1);
  eq(t.notes[0].text, 'root caused to a race');
  eq(t.updated, '2026-09-17T11:00:00.000Z', 'updated should track the latest event');
});

check('events are replayed in timestamp order, not array order', () => {
  const { tasks } = foldEvents([
    ev('2026-09-17T12:00:00.000Z', 'task.status', { taskId: T1, from: 'in_progress', to: 'done' }),
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x', status: 'todo' }),
    ev('2026-09-17T10:00:00.000Z', 'task.status', { taskId: T1, from: 'todo', to: 'in_progress' }),
  ]);
  eq(tasks.get(T1).status, 'done', 'latest status must win regardless of input order');
  ok(tasks.get(T1).done !== null, 'done timestamp should be set');
});

check('events for an unknown task are skipped, not thrown', () => {
  const { tasks, skipped } = foldEvents([
    ev('2026-09-17T10:00:00.000Z', 'task.note', { taskId: 'T-missing', text: 'orphan' }),
  ]);
  eq(tasks.size, 0);
  eq(skipped, 1, 'orphan event should be counted as skipped');
});

check('delete marks deleted rather than dropping history', () => {
  const { tasks } = foldEvents([
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }),
    ev('2026-09-17T10:00:00.000Z', 'task.delete', { taskId: T1 }),
  ]);
  eq(tasks.get(T1).deleted, true);
});

check('unknown edit semantics are retained and diagnosed; supported edits apply', () => {
  const events = [
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }),
    ev('2026-09-17T10:00:00.000Z', 'task.edit', { taskId: T1, fields: { title: 'y', priority: 'high', hacked: 'nope' } }),
  ];
  const result = foldEvents(events);
  eq(result.tasks.get(T1).title, 'x');
  eq(result.complete, false, 'unknown edit semantics must block destructive plans');
  ok(result.diagnostics.some(issue => issue.$ === 'Unsupported'));
  const known = foldEvents([events[0], { ...events[1], fields: { title: 'y', priority: 'high' } }]);
  eq(known.tasks.get(T1).title, 'y'); eq(known.tasks.get(T1).priority, 'high');
});

print('\n--- merge convergence (the data-loss guard) ---');

// Laptop and desktop each edit while unaware of the other.
const laptop = [
  ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'Fix flaky CI', status: 'todo' }),
  ev('2026-09-17T10:00:00.000Z', 'task.status', { taskId: T1, from: 'todo', to: 'in_progress' }),
];
const desktop = [
  ev('2026-09-17T09:30:00.000Z', 'task.create', { taskId: T2, title: 'Index bloat', status: 'todo' }),
  ev('2026-09-17T10:30:00.000Z', 'task.note',   { taskId: T1, text: 'from the other machine' }),
];

check('union is order independent', () => {
  eq(unionEvents(laptop, desktop), unionEvents(desktop, laptop));
});

check('merged board keeps BOTH machines\' work', () => {
  const { tasks } = foldEvents(unionEvents(laptop, desktop));
  eq(tasks.size, 2, 'both tasks should survive');
  eq(tasks.get(T1).status, 'in_progress', 'laptop status kept');
  eq(tasks.get(T1).notes.length, 1, 'desktop note kept on laptop-created task');
  eq(tasks.get(T2).title, 'Index bloat');
});

check('re-merging is idempotent (no duplicated notes on retry)', () => {
  const once = foldEvents(unionEvents(laptop, desktop));
  const twice = foldEvents(unionEvents(laptop, desktop, laptop, desktop));
  eq(twice.tasks.get(T1).notes.length, once.tasks.get(T1).notes.length, 'push retry must not duplicate');
  eq(twice.tasks.size, once.tasks.size);
});

print('\n--- staging: nothing publishes without asking ---');

const fakeRepo = { owner: 'me', repo: 'worklog-data', slug: 'me/worklog-data' };
async function loadedStore(events = laptop) {
  const months = [...new Set(events.map(event => event.ts.slice(0, 7)))];
  const repo = memRepo({
    [PATHS.manifest]: JSON.stringify({ schema: 2, months }),
    ...Object.fromEntries(months.map(month => [PATHS.month(month), serialiseMonth(month, events.filter(event => event.ts.startsWith(month)))])),
  });
  Object.assign(repo, fakeRepo);
  const store = new Store(repo);
  await store.load();
  return store;
}

await checkAsync('staged events are visible locally but remote baseline untouched', async () => {
  localStorage.clear();
  const s = (await loadedStore());
  s.remoteEvents = laptop.slice();
  s.stage(makeEvent('task.note', { taskId: T1, text: 'staged only' }));
  ok(s.hasPending, 'should report pending changes');
  eq(s.remoteEvents.length, 2, 'remote baseline must not change on stage');
  eq(s.state.tasks.get(T1).notes.length, 1, 'staged note shows in local view');
});

await checkAsync('previewCommit describes the commit without performing it', async () => {
  localStorage.clear();
  const s = (await loadedStore());
  s.remoteEvents = laptop.slice();
  s.stage(makeEvent('task.create', { taskId: newTaskId(), title: 'New thing', status: 'todo' }));
  const p = s.previewCommit();
  ok(p, 'preview should exist when pending');
  eq(p.count, 1);
  const month = todayISO().slice(0, 7);
  const paths = p.files.map((f) => f.path).sort();
  // JSON and its rendered page are committed together: that is what makes the repo
  // readable with no Action and no build step.
  eq(paths, [
    'CHANGELOG.md',
    'data/BOARD.md',
    'data/board.json',
    PATHS.month(month),
    PATHS.monthMd(month),
    PATHS.yearReadme(month.slice(0, 4)),
    'data/log/README.md',
    'data/manifest.json',
  ].sort());
  ok(/^worklog \d{4}-\d{2}-\d{2}: 1 new/.test(p.message), `subject should summarise: ${p.message.split('\n')[0]}`);
  ok(s.hasPending, 'preview must not clear pending');
});

await checkAsync('previewCommit is null with nothing staged', async () => {
  localStorage.clear();
  eq((await loadedStore()).previewCommit(), null);
});

await checkAsync('pendingDescriptions says what is staged, in words', async () => {
  localStorage.clear();
  const s = (await loadedStore());
  s.remoteEvents = laptop.slice();
  s.stage(
    makeEvent('task.status', { taskId: T1, from: 'todo', to: 'done' }),
    makeEvent('task.note', { taskId: T1, text: 'shipped it' }),
  );
  const d = s.pendingDescriptions;
  eq(d.length, 2);
  const moved = d.find(row => row.type === 'task.status');
  const noted = d.find(row => row.type === 'task.note');
  ok(/→ Done$/.test(moved.text), `should read as a move: ${moved.text}`);
  ok(moved.text.includes(T1), 'and name the task');
  ok(/note — shipped it$/.test(noted.text), noted.text);
  ok(d.every((r) => r.ts && r.type), 'each row carries its instant and type for the UI');
});

await checkAsync('pendingDescriptions answers even when a month is unread', async () => {
  // The whole reason it does not go through previewCommit(): that refuses, correctly,
  // and someone asking "what have I got staged?" deserves an answer regardless.
  localStorage.clear();
  const s = (await loadedStore());
  s.loadedMonths = ['2024-01'];
  s.stage(makeEvent('task.note', { taskId: T1, text: 'x' }));
  let threw = null;
  try { s.previewCommit(); } catch (e) { threw = e; }
  ok(threw, 'previewCommit still refuses');
  eq(s.pendingDescriptions.length, 1, 'but the list is still available');
});

await checkAsync('pending changes survive a reload', async () => {
  localStorage.clear();
  const a = (await loadedStore());
  a.stage(makeEvent('task.note', { taskId: T1, text: 'unpushed work' }));
  const b = (await loadedStore());       // simulates reopening the tab
  eq(b.pending.length, 1, 'pending should be restored from localStorage');
  b.discardPending();
  eq((await loadedStore()).pending.length, 0, 'discard should clear persisted pending');
});

await checkAsync('board snapshot is valid JSON with per-status counts', async () => {
  localStorage.clear();
  const s = await loadedStore(unionEvents(laptop, desktop));
  s.stage(makeEvent('task.note', { taskId: T2, text: 'n' }));
  const board = JSON.parse(s.previewCommit().files.find((f) => f.path === 'data/board.json').text);
  eq(board.counts.in_progress, 1);
  eq(board.tasks.length, 2);
});

check('a month page renders newest day first', () => {
  const md = renderMonthMd('2026-09', [
    ev('2026-09-16T09:00:00.000Z', 'task.create', { taskId: T1, title: 'older' }),
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T2, title: 'newer' }),
  ], new Map());
  ok(md.indexOf('## 2026-09-17') < md.indexOf('## 2026-09-16'), 'newest day must come first');
});

print('\n--- years: does this survive being used for years? ---');

/** A repo double that records what was read, so a lazy boot can be proven lazy. */
function memRepo(files = {}) {
  return {
    owner: 'me', repo: 'd', slug: 'me/d', files, reads: [], commits: 0,
    async getFile(path) { this.reads.push(path); return files[path] == null ? null : { text: files[path] }; },
    async commitFiles(list, message, { deletions = [] } = {}) {
      for (const f of list) files[f.path] = f.text;
      for (const d of deletions) delete files[d];
      this.commits++; this.lastMessage = message; this.lastDeletions = deletions;
      return { ok: true };
    },
  };
}

check('event files live in year directories, with a rendered page beside them', () => {
  eq(PATHS.month('2031-04'), 'data/log/2031/04.json');
  eq(PATHS.monthMd('2031-04'), 'data/log/2031/04.md');
  eq(PATHS.yearReadme('2031'), 'data/log/2031/README.md');
});

check('a month file is one line per event, and still ordinary JSON', () => {
  const text = serialiseMonth('2026-09', [
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'a' }),
    ev('2026-09-17T10:00:00.000Z', 'task.note', { taskId: T1, text: 'b' }),
  ]);
  const parsed = JSON.parse(text);
  eq(parsed.month, '2026-09');
  eq(parsed.count, 2);
  eq(parsed.events.length, 2);
  // One added change must be one added line, or `git log -p` stops being readable.
  eq(text.split('\n').filter((l) => l.trim().startsWith('{"ts"')).length, 2, 'each event on its own line, ts first');
  eq(Object.keys(parsed.events[0])[0], 'ts', 'what happened comes before bookkeeping');
  ok(Object.keys(parsed.events[0]).includes('id'), 'the id must survive the reordering');
});

check('an empty month is still valid JSON', () => {
  eq(JSON.parse(serialiseMonth('2026-09', [])).events.length, 0);
});

await checkAsync('a push rewrites only the month it touched', async () => {
  localStorage.clear();
  const s = await loadedStore([ev('2024-01-05T09:00:00.000Z', 'task.create', { taskId: T1, title: 'ancient' })]);
  s.stage({ ...makeEvent('task.note', { taskId: T1, text: 'today' }), ts: '2026-09-17T09:00:00.000Z' });
  const paths = s.previewCommit().files.map((f) => f.path);
  ok(paths.includes('data/log/2026/09.json'), 'the touched month is written');
  ok(!paths.includes('data/log/2024/01.json'), 'an untouched month must not be rewritten');
  ok(!paths.includes('data/log/2024/README.md'), 'nor an untouched year index');
});

await checkAsync('previewCommit refuses to rewrite a month it has not read', async () => {
  localStorage.clear();
  const s = (await loadedStore());
  s.loadedMonths = ['2024-01'];              // current month deliberately not loaded
  s.stage(makeEvent('task.note', { taskId: T1, text: 'x' }));
  let threw = null;
  try { s.previewCommit(); } catch (e) { threw = e; }
  ok(threw, 'silently truncating a month file would lose events');
  ok(/has not been read/.test(threw.message), threw && threw.message);
});

check('the changelog is an index, not the whole history', () => {
  const md = renderChangelogIndex([
    { month: '2024-01', events: 40, days: 12 },
    { month: '2026-09', events: 9, days: 3 },
  ]);
  ok(md.indexOf('## 2026') < md.indexOf('## 2024'), 'newest year first');
  ok(md.includes('data/log/2026/09.md'), 'links to the rendered month');
  ok(md.includes('data/log/2024/01.json'), 'and to the raw events');
  ok(md.length < 2000, `an index must stay small; got ${md.length} bytes`);
});

check('a year index lists its own months only', () => {
  const md = renderYearReadme('2026', [
    { month: '2025-12', events: 3, days: 1 },
    { month: '2026-01', events: 7, days: 4 },
    { month: '2026-09', events: 9, days: 3 },
  ]);
  ok(md.includes('January'), 'months are named');
  ok(md.includes('September'), 'and all of them appear');
  ok(!md.includes('December'), 'a neighbouring year must not leak in');
  ok(md.includes('16 changes this year'), 'totals come from the manifest, not from reading every month');
});

check('the board page groups by status and caps finished work', () => {
  const tasks = new Map();
  for (let i = 0; i < 20; i++) {
    tasks.set(`T-d${i}`, { id: `T-d${i}`, title: `done ${i}`, status: 'done', priority: 'normal', tags: [], notes: [], created: '2026-01-01T00:00:00.000Z', updated: `2026-0${1 + (i % 9)}-01T00:00:00.000Z`, done: `2026-0${1 + (i % 9)}-01T00:00:00.000Z`, deleted: false });
  }
  tasks.set(T1, { id: T1, title: 'live | one', status: 'in_progress', priority: 'high', tags: ['ci'], notes: [{ ts: '2026-09-17T09:00:00.000Z', text: 'latest note' }], created: '2026-09-01T00:00:00.000Z', updated: '2026-09-17T09:00:00.000Z', done: null, deleted: false });
  const md = renderBoardMd(tasks);
  ok(md.includes('## In Progress (1)'), 'open work is grouped and counted');
  ok(md.includes('## Done (20)'), 'the count is the truth even when the list is capped');
  ok(md.includes('latest note'), 'the most recent note is the useful part');
  ok(/and 5 more finished earlier/.test(md), 'the rest points at the changelog instead of growing');
  ok(md.split('\n').length < 60, 'the board page stays a page');
});

print('\n--- the checkpoint: fast boots that are still correct ---');

const YEARS = [
  ev('2024-03-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'long runner', status: 'todo' }),
  ev('2025-06-01T09:00:00.000Z', 'task.status', { taskId: T1, from: 'todo', to: 'in_progress' }),
  ev('2026-09-17T09:00:00.000Z', 'task.note', { taskId: T1, text: 'still going' }),
];

check('unverified snapshots cannot seed replay; authoritative history remains complete', () => {
  const snapshot = [...foldEvents(YEARS.slice(0, 2)).tasks.values()];
  let error; try { foldEvents(YEARS.slice(2), { base: snapshot }); } catch (value) { error = value; }
  ok(error && /Unverified snapshots/.test(error.message));
  const complete = foldEvents(YEARS);
  eq(complete.tasks.get(T1).status, 'in_progress');
  eq(complete.tasks.get(T1).notes.length, 1);
  eq(snapshot[0].notes.length, 0, 'rejected caches remain unmodified');
});

await checkAsync('events already in the snapshot are not applied twice', async () => {
  localStorage.clear();
  const s = (await loadedStore());
  const folded = foldEvents(YEARS);
  s.checkpoint = { through: { ts: YEARS[2].ts, id: YEARS[2].id }, tasks: [...folded.tasks.values()] };
  s.remoteEvents = YEARS.slice();          // the month file we read contains that note
  eq(s.state.tasks.get(T1).notes.length, 1, 'a duplicated note would be silent data corruption');
});

check('two events in the same millisecond are split correctly by the checkpoint', () => {
  const ts = '2026-09-17T09:00:00.000Z';
  const first = { id: `${ts}-aaa`, ts, type: 'task.note', taskId: T1, text: 'first' };
  const second = { id: `${ts}-bbb`, ts, type: 'task.note', taskId: T1, text: 'second' };
  ok(!afterThrough(first, { ts, id: first.id }), 'the boundary event itself is already folded in');
  ok(afterThrough(second, { ts, id: first.id }), 'its same-millisecond neighbour is not');
});

await checkAsync('the snapshot records what it folded in, so a boot can trust it', async () => {
  localStorage.clear();
  const s = await loadedStore([]);
  const staged = { ...makeEvent('task.create', { taskId: T2, title: 'x' }), ts: '2026-09-17T09:00:00.000Z' };
  s.stage(staged);
  const board = JSON.parse(s.previewCommit().files.find((f) => f.path === 'data/board.json').text);
  eq(board.through.id, staged.id, 'through must name the last event folded in');
  eq(board.schema, 2);
});

await checkAsync('unverified legacy checkpoint uses the visible authoritative full-history fallback', async () => {
  localStorage.clear();
  const months = [];
  for (let y = 2021; y <= 2026; y++) for (let m = 1; m <= 12; m++) months.push(`${y}-${String(m).padStart(2, '0')}`);
  const repo = memRepo({
    [PATHS.manifest]: JSON.stringify({ schema: 2, months }),
    [PATHS.board]: JSON.stringify({ schema: 2, through: { ts: '2026-08-01T00:00:00.000Z', id: 'x' }, tasks: [{ id: T1, title: 'unverified' }] }),
    [PATHS.month('2021-01')]: serialiseMonth('2021-01', [ev('2021-01-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'authoritative' })]),
  });
  const store = new Store(repo); await store.load();
  ok(store.fullyLoaded, 'legacy coverage is insufficient, so all authoritative months are read');
  eq(store.tasks[0].title, 'authoritative');
  ok(repo.reads.includes(PATHS.month('2021-01')), 'old source history must not be skipped');
});

await checkAsync('older history loads on demand, and only once', async () => {
  localStorage.clear();
  const repo = memRepo({
    'data/manifest.json': JSON.stringify({ schema: 2, months: ['2024-01', '2024-02', '2026-09'] }),
    'data/board.json': JSON.stringify({ through: { ts: '2026-09-01T00:00:00.000Z', id: 'x' }, tasks: [] }),
    'data/log/2024/01.json': JSON.stringify({ month: '2024-01', events: [ev('2024-01-05T09:00:00.000Z', 'task.create', { taskId: T1, title: 'ancient' })] }),
  });
  const s = new Store(repo);
  await s.load();
  ok(s.yearLoaded('2024'), 'authoritative fallback already read 2024');

  await s.loadYear('2024');
  ok(s.yearLoaded('2024'), 'and is loaded on request');
  eq(s.remoteEvents.length, 1);
  const before = repo.reads.length;
  await s.loadYear('2024');
  eq(repo.reads.length, before, 'a second request must not re-fetch');
});

await checkAsync('a v1 repo still loads: flat month files and bare month strings', async () => {
  localStorage.clear();
  const repo = memRepo({
    'data/manifest.json': JSON.stringify({ schema: 1, months: ['2026-09'] }),
    'data/log/2026-09.json': JSON.stringify({ month: '2026-09', events: [ev('2026-09-10T09:00:00.000Z', 'task.create', { taskId: T1, title: 'written by v1' })] }),
  });
  const s = new Store(repo);
  await s.load();
  eq(s.tasks.length, 1, 'a v1 flat month file must still be found');
  eq(s.tasks[0].title, 'written by v1');
  ok(s.knownMonths.includes('2026-09'), 'bare month strings still index');
});

check('the snapshot drops notes from long-finished work, and says how many', () => {
  const old = '2024-01-05T09:00:00.000Z';
  const tasks = new Map([
    ['T-old111', { id: 'T-old111', title: 'finished ages ago', status: 'done', priority: 'normal', tags: [], created: old, updated: old, done: old, deleted: false,
      notes: [{ ts: old, text: 'a long note that would be carried on every boot forever' }, { ts: old, text: 'and another' }] }],
    ['T-new222', { id: 'T-new222', title: 'still open', status: 'in_progress', priority: 'normal', tags: [], created: old, updated: new Date().toISOString(), done: null, deleted: false,
      notes: [{ ts: new Date().toISOString(), text: 'current thinking, must be kept' }] }],
  ]);
  const snap = JSON.parse(renderBoardSnapshot(tasks, { ts: old, id: 'x' }));
  const stale = snap.tasks.find((t) => t.id === 'T-old111');
  const live = snap.tasks.find((t) => t.id === 'T-new222');
  eq((stale.notes || []).length, 0, 'old notes are already committed in that month; not carried here');
  eq(stale.noteCount, 2, 'but the count must be recorded so the UI can offer them');
  eq(stale.title, 'finished ages ago', 'the task itself stays, so reopening it still works');
  eq(live.notes.length, 1, 'open work keeps full fidelity');
  ok(live.noteCount === undefined, 'and is not marked as trimmed');
});

check('snapshot remains readable and lossless metadata, with explicit cache-only semantics', () => {
  const tasks = new Map();
  for (let i = 0; i < 5; i++) tasks.set(`T-x0000${i}`, { id: `T-x0000${i}`, title: `task ${i}`, status: 'todo', priority: 'normal', tags: [], notes: [], created: '2026-09-01T00:00:00.000Z', updated: '2026-09-01T00:00:00.000Z', futureField: 'keep me' });
  const text = renderBoardSnapshot(tasks, null), parsed = JSON.parse(text);
  eq(parsed.tasks.length, 5);
  eq(text.split('\n').filter(line => line.trim().startsWith('{"id"')).length, 5);
  eq(parsed.tasks[0].futureField, 'keep me');
  ok(parsed.cacheOnly, 'cache cannot self-assert authoritative coverage');
  let error; try { foldEvents([], { base: parsed.tasks }); } catch (value) { error = value; }
  ok(error, 'host cache is not accepted as source history');
});

check('a note is a set, not a sequence: applying it twice changes nothing', () => {
  const n = ev('2026-09-17T09:00:00.000Z', 'task.note', { taskId: T1, text: 'same' });
  const { tasks } = foldEvents([
    ev('2026-09-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }),
    n, { ...n, id: 'different-event-id-same-content' },
  ]);
  eq(tasks.get(T1).notes.length, 2, 'distinct note identities must both survive');
  eq(foldEvents([ev('2026-09-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }), n, n]).tasks.get(T1).notes.length, 1, 'exact re-delivery is idempotent');
});

await checkAsync('authoritative replay recovers old notes without rewinding completion', async () => {
  localStorage.clear();
  const old = '2024-01-05T09:00:00.000Z';
  const creation = ev('2024-01-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'finished ages ago' });
  const note = ev(old, 'task.note', { taskId: T1, text: 'recovered detail' });
  const done = ev('2026-09-01T00:00:00.000Z', 'task.status', { taskId: T1, to: 'done' });
  const store = await loadedStore([creation, note, done]);
  eq(store.tasks[0].notes[0].text, note.text);
  eq(store.tasks[0].status, 'done');
  eq(store.tasks[0].updated, done.ts);
});

await checkAsync('late older status is replayed before newer authoritative status', async () => {
  const creation = ev('2024-01-01T00:00:00.000Z', 'task.create', { taskId: T1, title: 'x' });
  const old = ev('2024-06-01T09:00:00.000Z', 'task.status', { taskId: T1, to: 'in_progress' });
  const done = ev('2026-08-01T00:00:00.000Z', 'task.status', { taskId: T1, to: 'done' });
  const store = await loadedStore([done, creation, old]);
  eq(store.tasks[0].status, 'done');
  eq(store.tasks[0].done, done.ts);
});

check('notes recovered out of order end up in date order', () => {
  const { tasks } = foldEvents([
    ev('2026-09-05T09:00:00.000Z', 'task.note', { taskId: T1, text: 'second' }),
    ev('2026-09-01T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }),
    ev('2026-09-02T09:00:00.000Z', 'task.note', { taskId: T1, text: 'first' }),
  ]);
  eq(tasks.get(T1).notes.map((n) => n.text), ['first', 'second']);
});

check('every link in the rendered pages stays inside the repo', () => {
  // A link that walks off the top of the repo is a 404 on github.com, and these pages
  // exist precisely so nobody has to run anything to read them.
  const at = (file, md) => {
    const dir = file.split('/').slice(0, -1);
    for (const [, href] of md.matchAll(/\]\(([^)]+)\)/g)) {
      if (/^https?:/.test(href)) continue;
      const parts = [...dir];
      for (const seg of href.split('/')) {
        if (seg === '..') { ok(parts.length > 0, `${file}: "${href}" escapes the repo root`); parts.pop(); }
        else if (seg !== '.') parts.push(seg);
      }
    }
  };
  const month = todayISO().slice(0, 7);
  at(PATHS.boardMd, renderBoardMd(new Map()));
  at(PATHS.changelog, renderChangelogIndex([{ month, events: 1, days: 1 }]));
  at(PATHS.yearReadme(month.slice(0, 4)), renderYearReadme(month.slice(0, 4), [{ month, events: 1, days: 1 }]));
  at(PATHS.monthMd(month), renderMonthMd(month, [], new Map()));
});

print('\n--- migrating a repo written by v1 ---');

/** A repo laid out the way v1 wrote it: flat months, bare manifest, no checkpoint. */
/**
 * A repo where the newest event is a summary -- exactly the shape you get by writing
 * an evening summary and publishing it, since the summary is then the checkpoint.
 */
function repoWithSummary() {
  const events = [
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'ship the thing', status: 'in_progress' }),
    ev('2026-09-17T17:00:00.000Z', 'summary.set', {
      date: '2026-09-17',
      kind: 'evening',
      summary: { headline: 'shipped it', bullets: [{ text: 'done', taskIds: [T1] }] },
    }),
  ];
  const { tasks } = foldEvents(events);
  const through = events[events.length - 1];
  return memRepo({
    'data/manifest.json': JSON.stringify({
      schema: 2, app: 'worklog', months: [{ month: '2026-09', events: events.length, days: 1 }],
    }),
    'data/log/2026/09.json': serialiseMonth('2026-09', events),
    'data/board.json': renderBoardSnapshot(tasks, through),
  });
}

await checkAsync('a summary survives being the checkpoint', async () => {
  // The snapshot stores tasks, not summaries, so a summary that is at or before the
  // checkpoint has to be replayed or it is gone from the UI while still in the log.
  localStorage.clear();
  const s = new Store(repoWithSummary());
  await s.load();
  const today = s.state.summaries['2026-09-17'];
  ok(today, 'no summaries at all for the day the summary was written');
  ok(today.evening, 'the evening summary is in the log but not in the folded state');
  eq(today.evening.headline, 'shipped it');
});

function v1Repo() {
  const aug = [
    ev('2026-08-11T09:00:00.000Z', 'task.create', { taskId: T1, title: 'v1 task', status: 'todo' }),
    ev('2026-08-11T10:00:00.000Z', 'task.note',   { taskId: T1, text: 'written by the old version' }),
  ];
  const sep = [
    ev('2026-09-02T09:00:00.000Z', 'task.status', { taskId: T1, from: 'todo', to: 'in_progress' }),
    ev('2026-09-02T09:30:00.000Z', 'task.create', { taskId: T2, title: 'another', status: 'todo' }),
  ];
  return memRepo({
    'data/manifest.json': JSON.stringify({ schema: 1, app: 'worklog', months: ['2026-08', '2026-09'] }),
    'data/log/2026-08.json': JSON.stringify({ month: '2026-08', events: aug }),
    'data/log/2026-09.json': JSON.stringify({ month: '2026-09', events: sep }),
    'data/board.json': JSON.stringify({ schema: 1, tasks: [] }),
    'CHANGELOG.md': '# Changelog\n\nthe whole history, in one file\n',
  });
}

await checkAsync('a v1 repo loads completely, and is offered an upgrade', async () => {
  localStorage.clear();
  const s = new Store(v1Repo());
  await s.load();
  eq(s.state.tasks.size, 2, 'nothing may be missing before an upgrade is even offered');
  eq(s.state.tasks.get(T1).status, 'in_progress');
  ok(s.needsMigration, 'the flat layout must be detected');
  eq(s.legacyMonths.sort(), ['2026-08', '2026-09']);
  ok(s.fullyLoaded, 'with no checkpoint, v1 months are all read, so a rewrite is safe');
});

await checkAsync('the upgrade moves every month and deletes the flat copies', async () => {
  localStorage.clear();
  const repo = v1Repo();
  const s = new Store(repo);
  await s.load();
  const plan = s.migrationCommit();

  const written = plan.files.map((f) => f.path).sort();
  ok(written.includes('data/log/2026/08.json'), 'August moves under its year');
  ok(written.includes('data/log/2026/08.md'), 'and gains a page you can read on GitHub');
  ok(written.includes('data/log/2026/README.md'));
  eq([...plan.deletions].sort(), ['data/log/2026-08.json', 'data/log/2026-09.json']);
  ok(/schema 2/.test(plan.message), `the message should say what it does: ${plan.message.split('\n')[0]}`);
  ok(/Co-Authored-By/.test(plan.message));

  await s.migrate(plan);
  eq(repo.commits, 1, 'one commit, not one per month');
  ok(repo.files['data/log/2026-08.json'] === undefined, 'the flat file must actually be gone');
  ok(repo.files['data/log/2026/08.json'], 'and its events must be at the new path');
  eq(JSON.parse(repo.files['data/manifest.json']).schema, 2);
  ok(JSON.parse(repo.files['data/board.json']).through?.ts, 'board.json becomes a checkpoint');
});

await checkAsync('upgrading changes no event, and does not need doing twice', async () => {
  localStorage.clear();
  const repo = v1Repo();
  const before = new Store(repo);
  await before.load();
  const beforeTasks = [...before.state.tasks.values()].map((t) => `${t.id}|${t.status}|${t.notes.length}`).sort();

  await before.migrate(before.migrationCommit());

  const after = new Store(repo);
  await after.load();
  const afterTasks = [...after.state.tasks.values()].map((t) => `${t.id}|${t.status}|${t.notes.length}`).sort();
  eq(afterTasks, beforeTasks, 'the board must be identical after the upgrade');
  ok(!after.needsMigration, 'and the offer must stop being made');
  eq(after.migrationCommit(), null);
});

await checkAsync('a half-read history refuses to be rewritten', async () => {
  localStorage.clear();
  const repo = v1Repo();
  // Give it a checkpoint so load() reads only recent months, then ask to migrate.
  repo.files['data/board.json'] = JSON.stringify({ schema: 2, through: { ts: '2026-08-11T10:00:00.000Z', id: 'zzz' }, tasks: [] });
  repo.files['data/manifest.json'] = JSON.stringify({ schema: 1, months: ['2020-01', '2026-08', '2026-09'] });
  const s = new Store(repo);
  await s.load({ recent: 1 });
  s.loadedMonths = s.loadedMonths.filter(month => month !== '2020-01');
  ok(!s.fullyLoaded, 'explicit partial-source state exercises the defensive gate');
  let threw = null;
  try { s.migrationCommit(); } catch (e) { threw = e; }
  ok(threw && /full history/.test(threw.message), 'rewriting a month it never read would drop events');
});


print('\n--- ids & labels ---');

check('task ids are unique across many draws', () => {
  const seen = new Set();
  for (let i = 0; i < 2000; i++) seen.add(newTaskId());
  eq(seen.size, 2000, 'no id collisions expected');
});

check('event ids are unique even within the same millisecond', () => {
  // Collisions here would make unionEvents() drop an event, so test hard.
  const ids = new Set();
  for (let i = 0; i < 20000; i++) ids.add(makeEvent('task.note', { taskId: T1, text: 'x' }).id);
  eq(ids.size, 20000);
});

check('id characters are drawn from the whole alphabet (no modulo skew)', () => {
  let s = '';
  for (let i = 0; i < 3000; i++) s += newTaskId().slice(2);
  const distinct = new Set(s.split('')).size;
  ok(distinct >= 30, `expected a broad character spread, saw ${distinct} distinct`);
});

check('every status has a human label', () => {
  for (const s of STATUSES) ok(statusLabel(s.id) && statusLabel(s.id) !== s.id, `missing label for ${s.id}`);
});

print('\n--- sign-off reports in the log ---');

const REPORT = ev('2026-09-17T17:30:00.000Z', 'standup.set', {
  date: '2026-09-17', kind: 'evening', text: 'Signing off:\n\n## AI Assistant\n\n- Finished the api', style: 'markdown',
});

check('a report folds into state by date and kind', () => {
  const { standups } = foldEvents([REPORT]);
  eq(standups['2026-09-17'].evening.text, 'Signing off:\n\n## AI Assistant\n\n- Finished the api');
  eq(standups['2026-09-17'].evening.style, 'markdown');
});

check('re-copying an edited report supersedes the earlier one', () => {
  const { standups } = foldEvents([
    REPORT,
    ev('2026-09-17T18:00:00.000Z', 'standup.set', { date: '2026-09-17', kind: 'evening', text: 'the edited one' }),
  ]);
  eq(standups['2026-09-17'].evening.text, 'the edited one', 'one report per kind per day, last one wins');
});

check('a report needs no new layout: it is one more line in the month file', () => {
  // The claim this protects: adding sign-offs changed no path and no schema. If this
  // ever fails, something started writing a second place for reports to live.
  const json = JSON.parse(serialiseMonth('2026-09', [REPORT]));
  eq(json.count, 1);
  eq(json.events[0].type, 'standup.set');
  eq(Object.keys(json.events[0]).slice(0, 5), ['ts', 'type', 'date', 'kind', 'text'],
    'field order comes from the existing EVENT_KEYS, so no key had to be invented');
});

check('an unknown event type is skipped rather than fatal', () => {
  // Which is what lets a repo written by this version still load in an older copy
  // of the app: the report events are ignored, not a crash.
  const { tasks, skipped } = foldEvents([
    ev('2026-09-17T09:00:00.000Z', 'task.create', { taskId: T1, title: 'x' }),
    ev('2026-09-17T19:00:00.000Z', 'standup.fromTheFuture', { date: '2026-09-17' }),
  ]);
  eq(tasks.size, 1);
  eq(skipped, 1);
});

check('the month page quotes the report instead of letting its headings escape', () => {
  const md = renderMonthMd('2026-09', [REPORT], new Map());
  ok(md.includes('**evening report**'), 'the day should name the report');
  ok(md.includes('> ## AI Assistant'), `a markdown-styled report must be quoted, not inlined:\n${md}`);
  ok(!/^## AI Assistant/m.test(md), 'otherwise the report takes over the page heading structure');
  ok(!md.includes('| 17:30 |'), 'and it does not also appear as a row in the change table');
});

await checkAsync('a report still shows up in the commit subject', async () => {
  const s = (await loadedStore());
  s.stage(REPORT);
  ok(/report/.test(s.previewCommit().message), s.previewCommit().message);
});

quit(report('store.js'));
