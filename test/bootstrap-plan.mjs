import assert from 'node:assert/strict';
import { prepareScaffold, scaffold, inspect, RepoState } from '../js/bootstrap.js';
import { GitHubRepo, ConflictError } from '../js/github.js';

const sha = value => value.repeat(40);
class Repository {
  owner = 'synthetic'; repo = 'data'; branch = 'main'; revision = sha('a'); calls = [];
  files = new Map();
  get slug() { return `${this.owner}/${this.repo}`; }
  async pinRevision() { this.readRevision = this.revision; this.calls.push('pin'); return this.readRevision; }
  async getFile(path) { this.calls.push(`read:${path}`); return this.files.has(path) ? { text: this.files.get(path) } : null; }
  async createRepo(options) { this.calls.push('create'); this.created = options; }
  async initialCommit(files, message) { this.calls.push('root'); this.written = { files, message }; }
  async commitFiles(files, message, options) {
    this.calls.push('commit');
    if (options.expectedBase !== this.revision) throw new ConflictError(this.branch);
    this.written = { files, message, options };
  }
}
let checks = 0;
async function check(name, action) { await action(); checks++; console.log(`PASS ${name}`); }
await check('missing setup prepares exact immutable values without side effects', async () => {
  const repo = new Repository();
  const plan = await prepareScaffold({ repo, state: RepoState.MISSING, withExamples: true, isPrivate: true, appUrl: 'https://synthetic.invalid/app/' });
  assert.deepEqual(repo.calls, []);
  assert.equal(plan.expectedBase, null);
  assert.throws(() => { plan.files[0].text = 'changed'; }, TypeError);
  await assert.rejects(() => scaffold({ repo }), /exact prepared/);
  await assert.rejects(() => scaffold({ repo, plan: structuredClone(plan) }), /exact prepared/);
  await scaffold({ repo, plan });
  assert.deepEqual(repo.calls, ['create', 'root']);
  assert.equal(repo.created.private, true);
  assert.equal(repo.written.files, plan.files);
  assert.equal(repo.written.message, plan.message);
  await assert.rejects(() => scaffold({ repo, plan }), /exact prepared/);
});
await check('options change the reviewed payload and destination changes invalidate approval', async () => {
  const repo = new Repository();
  const withExamples = await prepareScaffold({ repo, state: RepoState.EMPTY, withExamples: true });
  const blank = await prepareScaffold({ repo, state: RepoState.EMPTY, withExamples: false });
  const month = plan => JSON.parse(plan.files.find(file => /\d{2}\.json$/.test(file.path)).text);
  assert.ok(month(withExamples).events.length > 0);
  assert.equal(month(blank).events.length, 0);
  repo.branch = 'changed';
  await assert.rejects(() => scaffold({ repo, plan: blank }), /destination changed/);
  assert.deepEqual(repo.calls, []);
});
await check('unseeded setup binds one base and preserves an existing README', async () => {
  const repo = new Repository(); repo.files.set('README.md', 'UNRELATED README');
  const plan = await prepareScaffold({ repo, state: RepoState.UNSEEDED, withExamples: false });
  assert.equal(plan.expectedBase, sha('a'));
  assert.deepEqual(plan.retainedPaths, ['README.md']);
  assert.ok(!plan.files.some(file => file.path === 'README.md'));
  assert.ok(!repo.calls.includes('commit'));
  await scaffold({ repo, plan });
  assert.equal(repo.written.options.expectedBase, sha('a'));
  assert.equal(repo.files.get('README.md'), 'UNRELATED README');
});
await check('partial existing data and changed base refuse without a destructive write', async () => {
  const repo = new Repository(); repo.files.set('data/board.json', '{"schema":999}');
  await assert.rejects(() => prepareScaffold({ repo, state: RepoState.UNSEEDED }), /partial log/);
  assert.ok(!repo.calls.includes('commit'));
  repo.files.clear();
  const plan = await prepareScaffold({ repo, state: RepoState.UNSEEDED, withExamples: false });
  repo.revision = sha('b');
  await assert.rejects(() => scaffold({ repo, plan }), ConflictError);
  assert.equal(repo.written, undefined);
});
await check('ready inspection pins the revision before manifest reads', async () => {
  const repo = new Repository(); repo.files.set('data/manifest.json', '{}');
  repo.exists = async () => true; repo.info = async () => ({ visibility: 'private' }); repo.hasCommits = async () => true;
  assert.equal((await inspect(repo)).state, RepoState.READY);
  assert.deepEqual(repo.calls, ['pin', 'read:data/manifest.json']);
});
await check('root branch collision is atomic and never falls back to individual file writes', async () => {
  const oldFetch = globalThis.fetch, calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, method: options.method });
    if (url.endsWith('/git/trees')) return { ok: true, json: async () => ({ sha: sha('a') }) };
    if (url.endsWith('/git/commits')) return { ok: true, json: async () => ({ sha: sha('b') }) };
    if (url.endsWith('/git/refs')) return { ok: false, status: 409, text: async () => 'already exists' };
    throw new Error('Unexpected request');
  };
  try {
    const repo = new GitHubRepo({ owner: 'synthetic', repo: 'data', token: 'FAKE_ONLY' });
    await assert.rejects(() => repo.initialCommit([{ path: 'synthetic.txt', text: 'synthetic' }], 'synthetic'), ConflictError);
    assert.equal(calls.length, 3);
    assert.ok(calls.every(call => call.method === 'POST'));
    assert.ok(calls.every(call => !call.url.includes('/contents/')));
  } finally { globalThis.fetch = oldFetch; }
});
await check('wrong authenticated owner fails before repository creation', async () => {
  const oldFetch = globalThis.fetch, methods = [];
  globalThis.fetch = async (_url, options = {}) => { methods.push(options.method || 'GET'); return { ok: true, json: async () => ({ login: 'other-account' }) }; };
  try {
    await assert.rejects(() => new GitHubRepo({ owner: 'synthetic', repo: 'data', token: 'FAKE_ONLY' }).createRepo(), /authenticated personal account/);
    assert.deepEqual(methods, ['GET']);
  } finally { globalThis.fetch = oldFetch; }
});
console.log(`${checks} exact setup-plan and atomic adapter checks passed; fake HTTP only`);
