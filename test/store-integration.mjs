import assert from 'node:assert/strict';
import { Store, PATHS } from '../js/store.js';
import { GitHubRepo, ConflictError } from '../js/github.js';
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
console.log(`${checks} store/effect integration checks passed; synthetic HTTP and loopback only`);
