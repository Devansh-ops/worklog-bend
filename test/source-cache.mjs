import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { readSourceIndex, SourceIndexError } from '../js/source-index.js';
import { createVerifiedSourceReader, gitBlobHash, SourceIntegrityError } from '../js/source-cache.js';

const sha = letter => letter.repeat(40);
const blob = text => createHash('sha1').update(`blob ${Buffer.byteLength(text)}\0`).update(text).digest('hex');
const storage = () => {
  const values = new Map();
  return { values, getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, String(value)) };
};
class FakeRepo {
  owner = 'synthetic'; repo = 'data'; branch = 'main'; readRevision = sha('a'); metadataReads = 0; bodyReads = 0;
  get slug() { return `${this.owner}/${this.repo}`; }
  constructor(files = new Map()) { this.files = files; this.responses = new Map(); }
  index() {
    const entries = [...this.files].map(([path, text]) => ({ path: path.slice('data/'.length), mode: '100644', type: 'blob', sha: blob(text), size: Buffer.byteLength(text) }));
    this.responses = new Map([
      [`/git/commits/${this.readRevision}`, { sha: this.readRevision, tree: { sha: sha('b') } }],
      [`/git/trees/${sha('b')}`, { sha: sha('b'), truncated: false, tree: [{ path: 'data', mode: '040000', type: 'tree', sha: sha('c') }] }],
      [`/git/trees/${sha('c')}?recursive=1`, { sha: sha('c'), truncated: false, tree: entries }],
    ]);
  }
  async _json(url) {
    this.metadataReads++;
    const key = url.replace(`https://api.github.com/repos/${this.slug}`, '');
    assert.ok(this.responses.has(key), `Unexpected metadata URL: ${url}`);
    return structuredClone(this.responses.get(key));
  }
  async getFile(path) {
    this.bodyReads++;
    const text = this.files.get(path);
    return text === undefined ? null : { text, sha: blob(text) };
  }
}
const readAll = async (reader, index) => Promise.all(Object.keys(index.files).map(path => reader.getFile(path)));
const reader = (repo, index, store) => createVerifiedSourceReader(repo, index, { storage: store, cryptoObject: webcrypto });
let checks = 0;
async function check(name, run) { await run(); checks++; console.log(`PASS ${name}`); }

await check('WebCrypto hashes exact Git blob framing and Unicode bytes like real Git', async () => {
  const text = 'Synthetic λ 🚀 café\n';
  const git = spawnSync('git', ['hash-object', '--stdin'], { input: text, encoding: 'utf8' });
  assert.equal(git.status, 0);
  assert.equal(await gitBlobHash(text, 40, webcrypto), git.stdout.trim());
  assert.equal(await gitBlobHash(text, 64, webcrypto), createHash('sha256').update(`blob ${Buffer.byteLength(text)}\0`).update(text).digest('hex'));
  await assert.rejects(() => gitBlobHash('\ud800', 40, webcrypto), /surrogate/);
  await assert.rejects(() => gitBlobHash('x', 42, webcrypto), /format/);
  await assert.rejects(() => gitBlobHash('x', 40, {}), /WebCrypto/);
});

await check('complete pinned metadata discovers unindexed canonical and legacy months', async () => {
  const repo = new FakeRepo(new Map([
    ['data/manifest.json', '{"schema":2,"months":[]}'],
    ['data/log/2026/01.json', '{"month":"2026-01","events":[]}'],
    ['data/log/2025-12.json', '{"month":"2025-12","events":[]}'],
    ['data/log/2026/02.json', '{"schema":999,"month":"2026-02","events":[]}'],
  ]));
  repo.index();
  const index = await readSourceIndex(repo);
  assert.equal(index.complete, true);
  assert.deepEqual(index.months, ['2025-12', '2026-01', '2026-02']);
  assert.equal(repo.metadataReads, 3);
  const source = reader(repo, index, storage());
  assert.equal(JSON.parse((await source.getFile('data/log/2026/02.json')).text).schema, 999);
  // The store's schema guard receives these exact bytes; the cache never hides them.
});

await check('1000-month history reloads with zero body reads and a changed month needs only changed bodies', async () => {
  const files = new Map();
  for (let index = 0; index < 1000; index++) {
    const month = `${2000 + Math.floor(index / 12)}-${String(index % 12 + 1).padStart(2, '0')}`;
    files.set(`data/log/${month.slice(0, 4)}/${month.slice(5)}.json`, JSON.stringify({ month, events: [], extra: 'Synthetic 🚀' }));
  }
  files.set('data/manifest.json', '{"schema":2,"months":[]}');
  files.set('data/board.json', '{"schema":2,"tasks":[]}');
  const store = storage(), repo = new FakeRepo(files); repo.index();
  let index = await readSourceIndex(repo), source = reader(repo, index, store);
  await readAll(source, index); assert.equal(source.flush(), true);
  assert.equal(repo.bodyReads, 1002);
  const initialReads = repo.bodyReads;
  index = await readSourceIndex(repo); source = reader(repo, index, store);
  await readAll(source, index); source.flush();
  assert.equal(repo.bodyReads, initialReads);
  assert.equal(source.stats.hits, 1002);
  repo.readRevision = sha('d');
  files.set('data/manifest.json', '{"schema":2,"months":[],"changed":true}');
  files.set('data/board.json', '{"schema":2,"tasks":[],"changed":true}');
  const recent = [...files.keys()].filter(path => path.includes('/log/')).at(-1);
  files.set(recent, files.get(recent).replace('Synthetic', 'Updated synthetic'));
  repo.index(); index = await readSourceIndex(repo); source = reader(repo, index, store);
  await readAll(source, index); source.flush();
  assert.equal(repo.bodyReads - initialReads, 3);
  assert.equal(source.stats.hits, 999);
  assert.equal(repo.metadataReads, 9);
});

await check('cached body tampering and self-asserted SHA values cannot bypass the remote index', async () => {
  const repo = new FakeRepo(new Map([['data/manifest.json', '{"schema":2,"months":[]}']])); repo.index();
  const store = storage(), index = await readSourceIndex(repo);
  let source = reader(repo, index, store); await readAll(source, index); source.flush();
  const key = [...store.values.keys()][0];
  store.values.set(key, JSON.stringify({ version: 1, revision: repo.readRevision, sha: blob('MALICIOUS'), files: { 'data/manifest.json': 'MALICIOUS' } }));
  source = reader(repo, index, store);
  assert.equal((await source.getFile('data/manifest.json')).text, repo.files.get('data/manifest.json'));
  assert.equal(source.stats.invalid, 1); assert.equal(source.stats.networkReads, 1);
  store.values.set(key, '{"version":1,"version":1,"files":{}}');
  source = reader(repo, index, store); await readAll(source, index);
  assert.equal(source.stats.storageReadFailed, true);
});

await check('network body, metadata and missing indexed blob mismatches are refused', async () => {
  const repo = new FakeRepo(new Map([['data/manifest.json', '{}']])); repo.index();
  const index = await readSourceIndex(repo);
  for (const reply of [null, { text: 'changed', sha: index.files['data/manifest.json'].sha }, { text: '{}', sha: sha('f') }, { text: '\ud800', sha: null }]) {
    repo.getFile = async () => reply;
    await assert.rejects(() => reader(repo, index, storage()).getFile('data/manifest.json'), SourceIntegrityError);
  }
});

await check('destination or revision changes before or during a read are refused', async () => {
  const repo = new FakeRepo(new Map([['data/manifest.json', '{}']])); repo.index();
  const index = await readSourceIndex(repo), source = reader(repo, index, storage());
  repo.readRevision = sha('d');
  await assert.rejects(() => source.getFile('data/manifest.json'), /changed/);
  assert.throws(() => source.flush(), /changed/);
  repo.readRevision = index.revision;
  repo.getFile = async () => { repo.branch = 'other'; return { text: '{}', sha: blob('{}') }; };
  await assert.rejects(() => reader(repo, index, storage()).getFile('data/manifest.json'), /changed/);
});

await check('quota or disabled storage falls back to verified network reads without touching pending work', async () => {
  const repo = new FakeRepo(new Map([['data/manifest.json', '{}']])); repo.index();
  const index = await readSourceIndex(repo), pending = 'UNCHANGED_PENDING';
  const store = { getItem() { throw new Error('disabled'); }, setItem() { throw new Error('quota'); }, pending };
  const source = reader(repo, index, store); await readAll(source, index);
  assert.equal(source.flush(), false); assert.equal(source.stats.storageReadFailed, true); assert.equal(source.stats.storageWriteFailed, true);
  assert.equal(store.pending, pending);
  const absent = reader(repo, index, null); await readAll(absent, index); assert.equal(absent.flush(), false);
});

await check('cache scope is branch-specific and concurrent reads of one path share one fetch', async () => {
  const repo = new FakeRepo(new Map([['data/manifest.json', '{}']])); repo.index();
  const store = storage(), index = await readSourceIndex(repo), source = reader(repo, index, store);
  await Promise.all([source.getFile('data/manifest.json'), source.getFile('data/manifest.json')]);
  source.flush(); assert.equal(repo.bodyReads, 1);
  repo.branch = 'other'; const next = reader(repo, index, store); await readAll(next, index); next.flush();
  assert.equal(repo.bodyReads, 2); assert.equal(store.values.size, 2);
  assert.equal(await next.getFile('data/board.json'), null);
});

await check('truncated or malformed trees and nonregular source files never claim completeness', async () => {
  const mutations = [
    value => { value.truncated = true; },
    value => { value.sha = sha('f'); },
    value => { value.tree[0].mode = '120000'; },
    value => { value.tree[0].size = -1; },
    value => { value.tree.push({ ...value.tree[0] }); },
    value => { value.tree[0].path = 'log/2026/13.json'; },
    value => { value.tree[0].path = '../manifest.json'; },
    value => { value.tree[0].sha = 'a'.repeat(41); },
  ];
  for (const mutate of mutations) {
    const repo = new FakeRepo(new Map([['data/manifest.json', '{}']])); repo.index();
    mutate(repo.responses.get(`/git/trees/${sha('c')}?recursive=1`));
    await assert.rejects(() => readSourceIndex(repo), SourceIndexError);
  }
  const empty = new FakeRepo(); empty.index();
  empty.responses.get(`/git/trees/${sha('b')}`).tree = [];
  assert.deepEqual((await readSourceIndex(empty)).months, []);
  for (const path of ['log', 'log/2026']) {
    const linked = new FakeRepo(); linked.index();
    linked.responses.get(`/git/trees/${sha('c')}?recursive=1`).tree.push({ path, type: 'blob', mode: '120000', sha: sha('f'), size: 1 });
    await assert.rejects(() => readSourceIndex(linked), /ordinary Git tree/);
  }
  const stale = new FakeRepo(); stale.index();
  const get = stale._json.bind(stale); stale._json = async url => { const result = await get(url); stale.readRevision = sha('d'); return result; };
  await assert.rejects(() => readSourceIndex(stale), /changed/);
});
console.log(`${checks} verified source cache checks passed; all repository and network data are synthetic`);
