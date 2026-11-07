import assert from 'node:assert/strict';
import { Store, PATHS } from '../js/store.js';
import { GitHubRepo, ConflictError } from '../js/github.js';
import { planMonths } from '../js/domain.js';
import { createHash } from 'node:crypto';
const storage = new Map();
globalThis.localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, String(value)), removeItem: key => storage.delete(key) };
const event = (id, type, data = {}, ts = '2026-11-07T09:00:00.000Z') => ({ id, type, ts, ...data });
const create = event('create', 'task.create', { taskId: 'T-aaa111', title: 'Synthetic' });
const note = event('note', 'task.note', { taskId: 'T-aaa111', text: 'NEW_DURING_PUBLISH' }, '2026-11-07T10:00:00.000Z');
const revision = character => character.repeat(40);
class FakeRepo {
  owner = 'synthetic'; repo = 'data'; branch = 'main'; revision = revision('a'); writes = [];
  get slug() { return `${this.owner}/${this.repo}`; }
  constructor(files = []) { this.files = new Map(files.map(([path, value]) => [path, typeof value === 'string' ? value : JSON.stringify(value)])); }
  async pinRevision() { this.readRevision = this.revision; this.readFiles = new Map(this.files); return this.readRevision; }
  async getFile(path) { const text = this.readFiles.get(path); return text === undefined ? null : { text, sha: 'synthetic-blob' }; }
  async commitFiles(files, message, { expectedBase, deletions = [] }) {
    assert.equal(expectedBase, this.readRevision);
    if (this.revision !== expectedBase) throw new ConflictError(this.branch);
    await this.duringCommit?.();
    this.writes.push({ files, message, deletions, expectedBase });
    for (const file of files) this.files.set(file.path, file.text);
    for (const path of deletions) this.files.delete(path);
    this.revision = revision('b');
    this.readRevision = this.revision;
    return { commit: this.revision };
  }
}
const withHistory = (events = [], extras = {}) => new FakeRepo([
  [PATHS.manifest, { schema: 2, months: ['2026-11'], retained: { manifest: true } }],
  [PATHS.month('2026-11'), { month: '2026-11', events, ...extras }],
]);
let checks = 0;
async function check(name, fn) { storage.clear(); await fn(); checks++; console.log(`PASS ${name}`); }

await check('stage and preview are local; exact approval is required and immutable', async () => {
  const repo = withHistory(), store = new Store(repo);
  await store.load(); store.stage(create);
  assert.equal(repo.writes.length, 0);
  const plan = await store.preparePublish();
  assert.equal(repo.writes.length, 0);
  assert.throws(() => { plan.files[0].text = 'changed'; }, TypeError);
  await assert.rejects(() => store.push(), /exact preview/);
  await assert.rejects(() => store.push(structuredClone(plan)), /exact preview/);
  await store.push(plan);
  assert.equal(repo.writes.length, 1);
  assert.equal(store.pending.length, 0);
  assert.deepEqual(JSON.parse(repo.files.get(PATHS.manifest)).retained, { manifest: true });
});
await check('a new event staged during publication stays pending and survives reload', async () => {
  const repo = withHistory(), store = new Store(repo);
  await store.load(); store.stage(create); const plan = await store.preparePublish();
  repo.duringCommit = () => store.stage(note);
  await store.push(plan);
  assert.deepEqual(store.pending.map(value => value.id), ['note']);
  const restored = new Store(repo); await restored.load();
  assert.deepEqual(restored.pending.map(value => value.id), ['note']);
  assert.equal(restored.tasks[0].notes[0].text, note.text);
});
await check('peer revision conflict preserves pending work and requires another preview', async () => {
  const repo = withHistory(), store = new Store(repo);
  await store.load(); store.stage(create); const plan = await store.preparePublish();
  repo.revision = revision('c');
  await assert.rejects(() => store.push(plan), ConflictError);
  assert.equal(repo.writes.length, 0);
  assert.equal(store.pending.length, 1);
  await assert.rejects(() => store.push(plan), /changed/);
});
await check('network failure acknowledges nothing', async () => {
  const repo = withHistory(), store = new Store(repo);
  await store.load(); store.stage(create); const plan = await store.preparePublish();
  repo.commitFiles = async () => { throw new Error('synthetic network failure'); };
  await assert.rejects(() => store.push(plan), /network/);
  assert.deepEqual(store.pending.map(value => value.id), ['create']);
});
await check('compatible event and snapshot extensions survive without prototype-key loss', async () => {
  const extended = JSON.parse(JSON.stringify(create).slice(0, -1) + ',"__proto__":{"canary":"event-extension"},"constructor":"retained"}');
  const repo = withHistory([extended]);
  repo.files.set(PATHS.board, JSON.stringify({ schema: 2, futureCacheField: { keep: true }, tasks: [{ id: create.taskId, futureTaskField: ['keep'] }] }));
  const store = new Store(repo); await store.load(); store.stage(note);
  const plan = await store.preparePublish();
  const month = JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-11')).text);
  assert.equal(Object.hasOwn(month.events[0], '__proto__'), true);
  assert.equal(month.events[0].constructor, 'retained');
  const snapshot = JSON.parse(plan.files.find(file => file.path === PATHS.board).text);
  assert.deepEqual(snapshot.futureCacheField, { keep: true });
  assert.deepEqual(snapshot.tasks[0].futureTaskField, ['keep']);
});
await check('pending storage failure preserves edits in memory and malformed saved data is not overwritten', async () => {
  const original = globalThis.localStorage;
  const repo = withHistory(), store = new Store(repo); await store.load();
  globalThis.localStorage = { ...original, setItem: () => { throw new Error('quota'); } };
  assert.throws(() => store.stage(create), /remain in memory/);
  assert.equal(store.pending[0].id, 'create');
  globalThis.localStorage = original;
  storage.set('worklog.pending.synthetic/data#main', '{"invalid":"array expected"}');
  const broken = new Store(repo); await broken.load();
  assert.equal(broken.recoveryRequired, true);
  assert.throws(() => broken.stage(create), /Recover/);
  assert.equal(storage.get('worklog.pending.synthetic/data#main'), '{"invalid":"array expected"}');
});
await check('future manifest, snapshot and month schemas refuse before any write plan', async () => {
  for (const path of [PATHS.manifest, PATHS.board, PATHS.month('2026-11')]) {
    const repo = withHistory();
    repo.files.set(path, JSON.stringify({ schema: 999, months: ['2026-11'], events: [] }));
    const store = new Store(repo);
    await assert.rejects(() => store.load(), /unsupported schema/);
    assert.throws(() => store.stage(create), /supported history/);
    assert.equal(repo.writes.length, 0);
  }
});
await check('legacy/current files reconcile and unknown month metadata survives migration', async () => {
  const repo = withHistory([create], { retained: { month: ['keep'] } });
  repo.files.set(PATHS.legacyMonth('2026-11'), JSON.stringify({ month: '2026-11', events: [create, note], retained: { month: ['keep'] } }));
  const store = new Store(repo); await store.load();
  assert.equal(store.remoteEvents.length, 2);
  const plan = store.migrationCommit();
  assert.ok(plan.deletions.includes(PATHS.legacyMonth('2026-11')));
  const month = JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-11')).text);
  assert.deepEqual(month.retained, { month: ['keep'] });
  assert.deepEqual(month.events.map(value => value.id), ['create', 'note']);
  await store.migrate(plan);
  assert.equal(repo.files.has(PATHS.legacyMonth('2026-11')), false);
});
await check('conflicting IDs and incompatible retained source metadata cannot migrate', async () => {
  for (const legacy of [{ month: '2026-11', events: [{ ...create, title: 'collision' }] }, { month: '2026-11', events: [note], retained: 'different' }]) {
    const repo = withHistory([create], { retained: 'first' }); repo.files.set(PATHS.legacyMonth('2026-11'), JSON.stringify(legacy));
    await assert.rejects(() => new Store(repo).load(), /Conflicting/);
    assert.equal(repo.writes.length, 0);
  }
});
await check('unverified checkpoint cannot drop a late status, deleted provenance or covered report', async () => {
  const status = event('done', 'task.status', { taskId: 'T-aaa111', to: 'done' }, '2026-11-07T11:00:00.000Z');
  const report = event('report', 'standup.set', { date: '2026-11-07', kind: 'evening', text: 'EXACT_COPY', style: 'plain' });
  const repo = withHistory([status, report, create]);
  repo.files.set(PATHS.board, JSON.stringify({ schema: 2, through: status, tasks: [{ id: create.taskId, status: 'todo', title: 'STALE' }] }));
  const store = new Store(repo); await store.load();
  assert.equal(store.tasks[0].status, 'done');
  assert.equal(store.state.standups['2026-11-07'].evening.text, 'EXACT_COPY');
});
await check('pending storage is branch-scoped; legacy recovery requires an explicit choice', async () => {
  storage.set('worklog.pending.synthetic/data', JSON.stringify([create]));
  const repo = withHistory(), store = new Store(repo); await store.load();
  assert.equal(store.pending.length, 0); assert.ok(store.pendingRecovery);
  store.recoverLegacyPending(); assert.equal(store.pending.length, 1);
  assert.ok(storage.has('worklog.pending.synthetic/data'));
  const other = new FakeRepo(); other.branch = 'other';
  const otherStore = new Store(other); await otherStore.load();
  assert.equal(otherStore.pending.length, 0);
});
await check('real GitHub adapter pins reads and rejects stale approved parent before mutations', async () => {
  const original = globalThis.fetch, requests = [];
  try {
    globalThis.fetch = async (url, options = {}) => {
      requests.push({ url, method: options.method || 'GET' });
      if (url.includes('/git/ref/')) return { ok: true, json: async () => ({ object: { sha: revision(requests.length > 2 ? 'c' : 'a') } }) };
      if (url.includes('/contents/')) return { ok: true, json: async () => ({ encoding: 'base64', content: btoa('{}'), sha: 'blob' }) };
      throw new Error('No mutation should be attempted');
    };
    const repo = new GitHubRepo({ owner: 'synthetic', repo: 'data', token: 'FAKE_ONLY' });
    await repo.pinRevision(); await repo.getFile('data/manifest.json');
    assert.ok(requests[1].url.includes(`ref=${revision('a')}`));
    await assert.rejects(() => repo.commitFiles([{ path: 'data/x', text: 'synthetic' }], 'm', { expectedBase: revision('a') }), ConflictError);
    assert.ok(requests.every(request => request.method === 'GET'));
    await assert.rejects(() => repo.commitFiles([{ path: '../outside', text: 'x' }], 'm', { expectedBase: revision('a') }), /Invalid/);
  } finally { globalThis.fetch = original; }
});
await check('complete source indexing discovers unlisted history and unchanged reloads use verified cache', async () => {
  const privateCreate = event('old-private', 'task.create', { taskId: 'T-secret', title: 'PRIVATE_CANARY', private: true }, '2026-10-01T09:00:00.000Z');
  const deletion = event('old-delete', 'task.delete', { taskId: 'T-secret' }, '2026-10-02T09:00:00.000Z');
  const repo = withHistory([create]);
  repo.files.set(PATHS.month('2026-10'), JSON.stringify({ month: '2026-10', events: [privateCreate, deletion] }));
  repo.sourceIndex = async () => ({ revision: repo.readRevision, complete: true, months: ['2026-10', '2026-11'],
    files: Object.fromEntries([...repo.readFiles].filter(([path]) => path.startsWith('data/')).map(([path, body]) => [path, {
      sha: createHash('sha1').update(`blob ${Buffer.byteLength(body)}\0`).update(body).digest('hex'), size: Buffer.byteLength(body),
    }])) });
  const getFile = repo.getFile.bind(repo); let reads = 0;
  repo.getFile = async path => {
    reads++;
    const file = await getFile(path);
    return file ? { ...file, sha: createHash('sha1').update(`blob ${Buffer.byteLength(file.text)}\0`).update(file.text).digest('hex') } : null;
  };
  const store = new Store(repo); await store.load();
  assert.equal(store.state.tasks.get('T-secret').deleted, true);
  assert.ok(store.knownMonths.includes('2026-10'));
  assert.equal(reads, 3);
  reads = 0; await store.load();
  assert.equal(reads, 0);
  assert.equal(store.sourceCacheStats.hits, 3);
  repo.files.set(PATHS.month('2026-10'), '{"schema":999,"month":"2026-10","events":[]}');
  repo.revision = revision('c');
  await assert.rejects(() => store.load(), /unsupported schema/);
  assert.equal(repo.writes.length, 0);
});
await check('checked planning creates an unread new destination without inventing source reads', async () => {
  const repo = withHistory([create]), store = new Store(repo);
  const reads = [], read = repo.getFile.bind(repo);
  repo.getFile = async path => { reads.push(path); return read(path); };
  await store.load();
  const next = event('new-month', 'task.note', { taskId: create.taskId, text: 'NEW_MONTH' }, '2027-01-15T09:00:00.000Z');
  store.stage(next);
  reads.length = 0;
  const plan = await store.preparePublish();
  assert.deepEqual(reads, []);
  assert.deepEqual(store.touchedMonths, ['2027-01']);
  assert.deepEqual(JSON.parse(plan.files.find(file => file.path === PATHS.month('2027-01')).text).events, [next]);
  assert.equal(plan.files.some(file => file.path === PATHS.month('2026-11')), false);
});
await check('physical historical source relocation uses local day and preserves empty-source metadata', async () => {
  const previousTZ = process.env.TZ;
  process.env.TZ = 'America/Los_Angeles';
  try {
    const boundary = event('boundary', 'task.create', { taskId: 'T-boundary', title: 'CANONICAL_EXTENSION', extra: { preserved: true } }, '2026-11-01T00:15:00.000Z');
    const untouched = event('untouched', 'task.create', { taskId: 'T-untouched', title: 'Untouched' }, '2026-09-15T09:00:00.000Z');
    const repo = new FakeRepo([
      [PATHS.manifest, { schema: 2, months: [{ month: '2026-08', extension: 'KEEP_EMPTY' }, { month: '2026-09', events: 1, days: 1, updated: 'UNCHANGED' }] }],
      [PATHS.month('2026-08'), { month: '2026-08', events: [boundary], retained: { physical: 'August' } }],
      [PATHS.month('2026-09'), { month: '2026-09', events: [untouched] }],
    ]);
    const store = new Store(repo); await store.load();
    store.stage(event('after-boundary', 'task.note', { taskId: boundary.taskId, text: 'After' }, '2026-11-15T09:00:00.000Z'));
    const plan = await store.preparePublish();
    assert.deepEqual(store.touchedMonths, ['2026-08', '2026-10', '2026-11']);
    const empty = JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-08')).text);
    assert.deepEqual(empty.events, []); assert.deepEqual(empty.retained, { physical: 'August' });
    const moved = JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-10')).text);
    assert.deepEqual(moved.events, [boundary]);
    assert.equal(plan.files.some(file => file.path === PATHS.month('2026-09')), false);
    const stats = JSON.parse(plan.files.find(file => file.path === PATHS.manifest).text).months;
    assert.deepEqual(stats.find(value => value.month === '2026-09'), { month: '2026-09', events: 1, days: 1, updated: 'UNCHANGED' });
    assert.equal(stats.find(value => value.month === '2026-08').extension, 'KEEP_EMPTY');
    assert.equal(stats.find(value => value.month === '2026-10').events, 1);
    assert.equal(stats.find(value => value.month === '2026-10').days, 1);
  } finally { if (previousTZ === undefined) delete process.env.TZ; else process.env.TZ = previousTZ; }
});
await check('migration deletes a historical legacy physical month only after local-month relocation', async () => {
  const previousTZ = process.env.TZ; process.env.TZ = 'America/Los_Angeles';
  try {
    const boundary = { ...create, ts: '2026-11-01T00:15:00.000Z' };
    const repo = new FakeRepo([
      [PATHS.manifest, { schema: 1, months: ['2026-08'] }],
      [PATHS.legacyMonth('2026-08'), { month: '2026-08', events: [boundary], retained: ['EMPTY_LEGACY_METADATA'] }],
    ]);
    const store = new Store(repo); await store.load(); const plan = store.migrationCommit();
    assert.deepEqual(plan.deletions, [PATHS.legacyMonth('2026-08')]);
    const emptied = JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-08')).text);
    assert.deepEqual(emptied.events, []); assert.deepEqual(emptied.retained, ['EMPTY_LEGACY_METADATA']);
    assert.deepEqual(JSON.parse(plan.files.find(file => file.path === PATHS.month('2026-10')).text).events, [boundary]);
    assert.equal(repo.writes.length, 0);
  } finally { if (previousTZ === undefined) delete process.env.TZ; else process.env.TZ = previousTZ; }
});
await check('planner host boundary refuses malformed months, schemas and unsupported semantics', async () => {
  const options = { schemas: [2], currentMonth: '2026-11' };
  for (const schema of [-1, 0x100000000, 1.5, '2']) assert.throws(() => planMonths([], [], { ...options, schemas: [schema] }), /U32/);
  for (const currentMonth of ['2026-13', '2026-00', '26-11', null]) assert.throws(() => planMonths([], [], { ...options, currentMonth }), /calendar/);
  assert.throws(() => planMonths([], [], { ...options, schemas: [2, 999, 1] }), /unsupported source schema/);
  assert.throws(() => planMonths([], [event('opaque', 'unknown.future')], options), /unsupported source semantics/);
  assert.throws(() => planMonths([{ month: '2026-11', currentExists: false, legacyExists: false, events: [create] }], [], options), /coverage/);
});
console.log(`${checks} store/effect integration checks passed; synthetic HTTP and loopback only`);
