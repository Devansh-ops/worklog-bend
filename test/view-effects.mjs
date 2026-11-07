import assert from 'node:assert/strict';
import { installFakeDOM } from './fake-dom.js';
import { todayISO } from '../js/store.js';
import { StandupView } from '../js/ui/standup.js';
import { BraindumpView } from '../js/ui/braindump.js';
import { newTaskDialog } from '../js/ui/board.js';
import { prepareOperationsRequest } from '../js/ai.js';
import { appRevision } from '../js/request.js';

const doc = installFakeDOM();
const createElement = doc.createElement;
doc.createElement = tag => {
  const node = createElement(tag);
  if (tag === 'dialog') {
    node.showModal = () => { node.open = true; };
    node.close = () => { node.open = false; node.closed = true; node.dispatch('close'); };
  }
  return node;
};
globalThis.localStorage = { getItem: () => null, setItem() {} };
const day = todayISO();
const instant = hour => new Date(`${day}T${hour}:00:00`).toISOString();
const events = [{ id: 'create', ts: instant('09'), type: 'task.create', taskId: 'T-public', title: 'Synthetic work', tags: ['Synthetic'] }];
function app() {
  return { store: { authoritative: true }, settings: { sendNotes: true }, onRules: false,
    endpoint: { kind: 'http', id: 'custom', baseUrl: 'http://127.0.0.1:9000/v1', model: 'synthetic' },
    state: { events, complete: true, summaries: {}, standups: {}, lastEventTs: events[0].ts }, tasks: [],
    staged: [], refresh() {}, go() {}, stage(...items) { this.staged.push(...items); return true; } };
}

// Provider response arrives after the user selects another report/draft.
{
  const source = app(), view = new StandupView(source);
  view.kind = 'evening'; view.render();
  let finish, started;
  const began = new Promise(done => { started = done; });
  const previousFetch = globalThis.fetch;
  globalThis.fetch = async () => { started(); return new Promise(done => { finish = done; }); };
  try {
    const writing = view.writeUp();
    await began;
    view.kind = 'morning'; view.draft = 'NEW USER DRAFT'; view.touched = true;
    finish({ ok: true, json: async () => ({ choices: [{ message: { content: '{"groups":[{"project":"Synthetic","lines":["OLD MODEL RESULT"]}]}' } }] }) });
    await writing;
    assert.equal(view.draft, 'NEW USER DRAFT');
    assert.equal(view.written, null);
    assert.match(view.error, /changed/);
  } finally { globalThis.fetch = previousFetch; }
}

// Clipboard bytes and selection are captured before the asynchronous effect.
{
  const source = app(), view = new StandupView(source);
  view.kind = 'evening'; view.group = 'project'; view.draft = 'EXACT CLIPBOARD';
  let finish;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, writable: true, value: {
    clipboard: { writeText: async text => { assert.equal(text, 'EXACT CLIPBOARD'); return new Promise(done => { finish = done; }); } },
  } });
  const copying = view.copy();
  view.kind = 'morning'; view.group = 'none'; view.draft = 'LATER DRAFT';
  finish(); await copying;
  assert.equal(source.staged[0].kind, 'evening');
  assert.equal(source.staged[0].style, 'project');
  assert.equal(source.staged[0].text, 'EXACT CLIPBOARD');
}

// A storage/staging failure keeps the reviewable selected proposals.
{
  const source = app(); source.endpoint = { kind: 'rules' }; source.onRules = true;
  let stageCalls = 0, navigations = 0;
  source.stage = () => { stageCalls++; return false; };
  source.go = () => { navigations++; };
  const view = new BraindumpView(source);
  view.text = 'Unchanged request text';
  view.proposalRequest = await prepareOperationsRequest({ endpoint: source.endpoint, events,
    text: view.text, readCurrent: () => appRevision(source) });
  view.proposals = [{ keep: true, op: { op: 'create', title: 'New proposal', status: 'todo', priority: 'normal', tags: [], rationale: 'synthetic' } }];
  const button = view.reviewCard().findAll('button').find(node => node.textContent.startsWith('Apply'));
  await button.listeners.click[0]({ target: button });
  assert.equal(stageCalls, 1); assert.equal(navigations, 0);
  assert.equal(view.proposals.length, 1); assert.equal(view.text, 'Unchanged request text');
  assert.match(view.error, /remain available/);
}

// Invalid/unsaved task input remains available for correction.
{
  newTaskDialog({ stage: () => false });
  const dialog = document.body.findAll('dialog').at(-1);
  dialog.findAll('input')[0].value = 'Recoverable title';
  const add = dialog.findByText('Add');
  await add.listeners.click[0]({ target: add });
  assert.notEqual(dialog.closed, true);
  assert.equal(dialog.findAll('input')[0].value, 'Recoverable title');
  dialog.close();
}
console.log('View effect regressions passed: stale report response, captured clipboard selection, retained proposals and task input on staging failure. DOM is shimmed; not browser evidence.');
