// Baseline observations, intentionally asserting existing reference faults.
// Convert each observation into an intended-behavior regression when replaced.
import assert from 'node:assert/strict';
const log = console.log.bind(console);
globalThis.print = log;
Object.defineProperty(globalThis, 'crypto', { value: undefined, writable: true, configurable: true });
await import('./shim.js');
const { Store, PATHS, foldEvents, unionEvents, todayISO } = await import('../js/store.js');
const { summarise, sanitiseOperations } = await import('../js/ai.js');
const { resolveEndpoint } = await import('../js/providers.js');
const event = (id, type, extra = {}) => ({ id, ts: '2026-11-07T10:00:00.000Z', type, ...extra });
let observations = 0;
function observed(name, fn) { fn(); observations++; log(`OBSERVED ${name}`); }

observed('F07 conflicting event content silently keeps first input', () => {
  const a = event('collision', 'task.create', { taskId: 'T-aaaaaa', title: 'first' });
  const b = { ...a, title: 'second' };
  assert.equal(unionEvents([a], [b])[0].title, 'first');
  assert.equal(unionEvents([b], [a])[0].title, 'second');
});
observed('F09 unseen backdated status is discarded by timestamp checkpoint', () => {
  const create = event('create', 'task.create', { taskId: 'T-aaaaaa', title: 'Synthetic', status: 'todo' });
  const store = new Store({ owner: 'synthetic', repo: 'checkpoint' });
  store.checkpoint = { through: { ts: '2026-11-07T12:00:00.000Z', id: 'z' }, tasks: [...foldEvents([create]).tasks.values()] };
  store.remoteEvents = [event('uncovered', 'task.status', { taskId: 'T-aaaaaa', to: 'done', ts: '2026-11-07T11:00:00.000Z' })];
  assert.equal(store.tasks[0].status, 'todo');
});
observed('F15 standup at checkpoint disappears from Store state', () => {
  const report = event('report', 'standup.set', { date: '2026-11-07', kind: 'evening', text: 'SYNTHETIC_REPORT' });
  assert.equal(foldEvents([report]).standups['2026-11-07'].evening.text, report.text);
  const store = new Store({ owner: 'synthetic', repo: 'report' });
  store.checkpoint = { through: report, tasks: [] };
  store.remoteEvents = [report];
  assert.equal(store.state.standups['2026-11-07'], undefined);
});

const futureFiles = new Map([
  [PATHS.manifest, { schema: 999, months: [] }],
  [PATHS.board, { schema: 999, through: event('checkpoint', 'noop'), tasks: [] }],
]);
const futureStore = new Store({ owner: 'synthetic', repo: 'future', getFile: async path => futureFiles.has(path) ? { text: JSON.stringify(futureFiles.get(path)) } : null });
await futureStore.load();
observed('F10 future schemas load and receive a schema 2 write plan', () => {
  assert.equal(futureStore.manifestSchema, 999);
  futureStore.stage(event('new', 'task.create', { ts: new Date().toISOString(), taskId: 'T-bbbbbb', title: 'Synthetic' }));
  const plan = futureStore.previewCommit();
  assert.equal(JSON.parse(plan.files.find(f => f.path === PATHS.manifest).text).schema, 2);
});
observed('F18 remote Ollama override inherits local classification', () => {
  const endpoint = resolveEndpoint({ provider: 'ollama', baseUrl: 'https://remote.example/v1', model: 'synthetic' });
  assert.equal(endpoint.local, true);
  assert.equal(endpoint.baseUrl, 'https://remote.example/v1');
});
observed('F18 sanitizer admits a known private target', () => {
  assert.equal(sanitiseOperations([{ op: 'note', taskId: 'T-secret', text: 'synthetic', rationale: 'test' }], [{ id: 'T-secret', private: true, status: 'todo' }]).length, 1);
});

const requests = [];
globalThis.fetch = async (_url, init) => {
  requests.push(JSON.parse(init.body));
  return { ok: true, json: async () => ({ choices: [{ message: { content: '{"headline":"Synthetic","bullets":[],"risks":[],"next":[]}' } }] }) };
};
const ts = `${todayISO()}T12:00:00`;
const endpoint = { kind: 'http', baseUrl: 'https://synthetic.invalid/v1', model: 'synthetic', headers: {} };
await summarise({ endpoint, tasks: [], events: [event('old-private', 'task.note', { taskId: 'T-deleted', text: 'CANARY_DELETED_PRIVATE', ts }), event('standup', 'standup.set', { text: 'CANARY_RETAINED_REPORT', ts })], previous: { headline: 'CANARY_PREVIOUS_HEADLINE' } });
observed('F18 outgoing request contains deleted private history and secondary free text', () => {
  const bytes = JSON.stringify(requests[0]);
  for (const canary of ['CANARY_DELETED_PRIVATE', 'CANARY_RETAINED_REPORT', 'CANARY_PREVIOUS_HEADLINE']) assert.ok(bytes.includes(canary), canary);
});
await summarise({ endpoint, tasks: [], events: [], includeNotes: false, previous: { headline: 'CANARY_NOTE_DERIVED_PREVIOUS' } });
observed('F18 notes off still sends the previous headline', () => {
  assert.ok(JSON.stringify(requests[1]).includes('CANARY_NOTE_DERIVED_PREVIOUS'));
});
log(`${observations} reference fault observations reproduced; these are not intended-behavior passes`);
