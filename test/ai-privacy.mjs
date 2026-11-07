// Actual generated Bend projection and intercepted transport. Synthetic data only.
import assert from 'node:assert/strict';
import { prepareOperationsRequest, proposeOperations, prepareSummaryRequest, summarise, prepareStandupRequest, writeStandup, approvedProposalEvents } from '../js/ai.js';
import { resolveEndpoint, endpointUrl, endpointProblem, isLocalDestination } from '../js/providers.js';
import { disclosure, isCloud, consentKey, confirmCloudSend, forgetConsent } from '../js/ui/consent.js';
import { assertRequestCurrent, StaleRequestError } from '../js/request.js';
import { canonicalJSON } from '../js/codec.js';

process.env.TZ = 'UTC';
const event = (id, type, data, time = '10:00:00') => ({ id, ts: `2026-11-07T${time}.000Z`, type, ...data });
const events = [
  event('public', 'task.create', { taskId: 'T-public', title: 'PUBLIC_TITLE', status: 'todo', tags: ['public-project'] }),
  event('public-note', 'task.note', { taskId: 'T-public', text: 'CANARY_PUBLIC_NOTE' }, '11:00:00'),
  event('secret', 'task.create', { taskId: 'T-secret', title: 'CANARY_PRIVATE_TITLE', private: true }),
  event('secret-note', 'task.note', { taskId: 'T-secret', text: 'CANARY_PRIVATE_NOTE' }, '11:00:01'),
  event('secret-delete', 'task.delete', { taskId: 'T-secret' }, '12:00:00'),
  event('saved-summary', 'summary.set', { date: '2026-11-07', kind: 'evening', summary: { headline: 'CANARY_OLD_SUMMARY' } }, '12:01:00'),
  event('saved-report', 'standup.set', { date: '2026-11-07', kind: 'evening', text: 'CANARY_OLD_REPORT' }, '12:02:00'),
];
const endpoint = resolveEndpoint({ provider: 'custom', baseUrl: 'https://receiver.invalid/v1?route=synthetic', model: 'fake-model' }, { custom: 'FAKE_CREDENTIAL_DO_NOT_DISCLOSE' });
const originalFetch = globalThis.fetch;
const sent = [];
let response = { headline: 'Synthetic result', bullets: [{ text: 'Public', taskIds: ['T-public', 'T-secret', 'T-invented'] }], risks: [], next: [] };
globalThis.fetch = async (url, options) => {
  sent.push({ url, options, body: JSON.parse(options.body) });
  return { ok: true, json: async () => ({ choices: [{ message: { content: JSON.stringify(response) } }] }) };
};
try {
  assert.equal(isCloud(resolveEndpoint({ provider: 'ollama', baseUrl: 'https://remote.invalid/v1' })), true);
  assert.equal(isLocalDestination({ kind: 'http', baseUrl: 'https://127.evil.invalid/v1' }), false);
  for (const host of ['localhost', '127.0.0.1', '[::1]']) assert.equal(isLocalDestination({ kind: 'http', baseUrl: `http://${host}:1234/v1` }), true);
  assert.equal(endpointUrl(endpoint, 'chat/completions'), 'https://receiver.invalid/v1/chat/completions?route=synthetic');
  assert.equal(consentKey(endpoint), consentKey({ ...endpoint, baseUrl: 'https://RECEIVER.invalid:443/v1/?route=synthetic' }));
  for (const baseUrl of ['https://user:password@remote.invalid/v1', 'https://remote.invalid/v1?api_key=secret', 'file:///tmp/model', 'https://remote.invalid/v1#hidden']) {
    assert.ok(endpointProblem(resolveEndpoint({ provider: 'custom', baseUrl })));
  }

  const prepared = await prepareSummaryRequest({ endpoint, events, includeNotes: false, today: '2026-11-07' });
  const descriptor = JSON.stringify(prepared);
  for (const canary of ['CANARY_PRIVATE_TITLE', 'CANARY_PRIVATE_NOTE', 'CANARY_PUBLIC_NOTE', 'CANARY_OLD_SUMMARY', 'CANARY_OLD_REPORT', 'FAKE_CREDENTIAL_DO_NOT_DISCLOSE']) assert.ok(!descriptor.includes(canary), canary);
  assert.ok(Object.isFrozen(prepared.messages[0]));
  assert.equal(prepared.tasks.length, 1);
  const declared = disclosure({ request: prepared });
  const result = await summarise({ request: prepared, previous: { headline: 'CANARY_PREVIOUS_ARGUMENT' } });
  assert.deepEqual(sent[0].body.messages, declared.messages);
  assert.equal(sent[0].options.redirect, 'error');
  assert.ok(sent[0].options.headers.Authorization.includes('FAKE_CREDENTIAL'));
  assert.deepEqual(result.bullets[0].taskIds, ['T-public']);
  assert.ok(!JSON.stringify(sent[0].body).includes('CANARY_PREVIOUS_ARGUMENT'));

  response = { operations: [
    { op: 'note', taskId: 'T-secret', text: 'must be dropped' },
    { op: 'note', taskId: 'T-public', text: 'selected public note' },
  ] };
  const freeText = '  User-owned CANARY_PRIVATE_TITLE is disclosed verbatim.\nKeep whitespace.  ';
  const operations = await prepareOperationsRequest({ endpoint, events, includeNotes: false, text: freeText });
  assert.equal(disclosure({ request: operations }).freeText, freeText);
  const proposed = await proposeOperations({ request: operations });
  assert.equal(proposed.length, 1);
  assert.equal(proposed[0].taskId, 'T-public');
  assert.ok(sent.at(-1).body.messages.at(-1).content.includes(freeText));
  assert.deepEqual(await approvedProposalEvents(operations, [], events), []);
  await assert.rejects(() => approvedProposalEvents(operations, [{ op: 'note', taskId: 'T-secret', text: 'no' }], events), /outside this request/);
  assert.equal((await approvedProposalEvents(operations, proposed, events))[0].taskId, 'T-public');
  const becamePrivate = [...events, event('public-now-private', 'task.edit', { taskId: 'T-public', fields: { private: true } }, '13:00:00')];
  await assert.rejects(() => approvedProposalEvents(operations, proposed, becamePrivate), /eligible|private|public|proposal/);

  const report = await prepareStandupRequest({ endpoint, events, date: '2026-11-07', includeNotes: false });
  for (const canary of ['CANARY_PRIVATE_TITLE', 'CANARY_PRIVATE_NOTE', 'CANARY_PUBLIC_NOTE', 'CANARY_OLD_SUMMARY', 'CANARY_OLD_REPORT']) assert.ok(!JSON.stringify(report).includes(canary), canary);
  assert.equal(report.activity.length, 1);
  assert.ok(!JSON.stringify(report.messages).includes('T-public'));
  response = { groups: [{ project: 'public-project', lines: ['PUBLIC_TITLE'] }] };
  assert.equal((await writeStandup({ request: report }))[0].lines[0], 'PUBLIC_TITLE');
  const ownDraft = '  Explicitly authored CANARY_PRIVATE_TITLE\n  preserve indentation  ';
  const editedReport = await prepareStandupRequest({ endpoint, events, date: '2026-11-07', includeNotes: false, draft: ownDraft });
  assert.equal(editedReport.freeText, ownDraft);
  assert.ok(editedReport.messages.at(-1).content.includes(ownDraft));

  let source = { events, destination: endpoint.baseUrl, notes: false };
  const guarded = await prepareOperationsRequest({ endpoint, events, includeNotes: false, text: 'synthetic', readCurrent: () => source });
  source = { ...source, destination: 'https://changed.invalid/v1' };
  const beforeStale = sent.length;
  await assert.rejects(() => proposeOperations({ request: guarded }), StaleRequestError);
  assert.equal(sent.length, beforeStale);
  assert.throws(() => assertRequestCurrent(guarded), StaleRequestError);

  const retry = await prepareSummaryRequest({ endpoint, events, includeNotes: false, today: '2026-11-07' });
  const retries = [];
  globalThis.fetch = async (_url, options) => {
    const body = JSON.parse(options.body); retries.push(body);
    if (body.response_format) return { ok: false, status: 400, text: async () => 'unsupported response_format json_schema json_object' };
    return { ok: true, json: async () => ({ choices: [{ message: { content: '{"headline":"Synthetic","bullets":[],"risks":[],"next":[]}' } }] }) };
  };
  await summarise({ request: retry });
  assert.equal(retries.length, 3);
  for (const body of retries) assert.equal(canonicalJSON(body.messages), canonicalJSON(retry.messages));

  const beforeOff = retries.length;
  const off = await prepareOperationsRequest({ endpoint: resolveEndpoint({ provider: 'none' }), events, text: 'synthetic' });
  await assert.rejects(() => proposeOperations({ request: off }), /turned off/);
  const rules = await prepareOperationsRequest({ endpoint: resolveEndpoint({ provider: 'rules' }), events, text: 'new: synthetic work' });
  await proposeOperations({ request: rules });
  assert.equal(retries.length, beforeOff);

  // Real fake-DOM cancellation dispatch. No provider call occurs after cancel.
  const { installFakeDOM, FakeNode } = await import('./fake-dom.js');
  FakeNode.prototype.showModal = function () { this.open = true; };
  FakeNode.prototype.close = function () { this.open = false; queueMicrotask(() => this.dispatch('close')); };
  installFakeDOM();
  globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };
  forgetConsent();
  const cancelled = confirmCloudSend({ request: retry });
  const find = node => node?.tagName === 'BUTTON' && node.textContent === 'Cancel' ? node : (node?.children || []).map(find).find(Boolean);
  const cancel = find(document.body);
  assert.ok(cancel, 'consent Cancel exists');
  cancel.dispatch('click');
  assert.equal(await cancelled, false);
  assert.equal(retries.length, beforeOff);
  console.log('AI privacy adapter passed: compiled eligibility/report selection, deleted-task canaries, notes-off, exact disclosure, frozen retries, stale destination/proposals, cancellation, AI-off/rules, URL classification');
} finally { globalThis.fetch = originalFetch; }
