// Deterministic transport contracts; no request reaches a provider service.
import assert from 'node:assert/strict';
import { PROVIDERS, resolveEndpoint, endpointUrl } from '../js/providers.js';
import { prepareSummaryRequest, summarise, AIError, parseJSONLoose } from '../js/ai.js';
const originalFetch = globalThis.fetch;
const result = '{"headline":"Synthetic","bullets":[],"risks":[],"next":[]}';
const success = () => ({ ok: true, json: async () => ({ choices: [{ message: { content: result } }] }) });
let providers = 0;
try {
  for (const id of Object.keys(PROVIDERS)) {
    const endpoint = resolveEndpoint({ provider: id, model: 'synthetic-model', ...(id === 'custom' ? { baseUrl: 'https://custom.invalid/v1' } : {}) }, { [id]: 'FAKE_PROVIDER_KEY' });
    if (endpoint.kind !== 'http') continue;
    const request = await prepareSummaryRequest({ endpoint, events: [] });
    const sent = [];
    globalThis.fetch = async (url, options) => { sent.push({ url, options, body: JSON.parse(options.body) }); return success(); };
    await summarise({ request });
    assert.equal(sent.length, 1);
    assert.equal(sent[0].url, endpointUrl(endpoint, 'chat/completions'));
    assert.equal(sent[0].options.redirect, 'error');
    assert.equal(sent[0].options.headers.Authorization, 'Bearer FAKE_PROVIDER_KEY');
    for (const [name, value] of Object.entries(endpoint.headers)) assert.equal(sent[0].options.headers[name], value);
    assert.equal(sent[0].body.model, 'synthetic-model');
    assert.deepEqual(sent[0].body.messages, request.messages);
    providers++;
  }
  const endpoint = resolveEndpoint({ provider: 'custom', baseUrl: 'https://custom.invalid/v1', model: 'synthetic' });
  const request = await prepareSummaryRequest({ endpoint, events: [] });
  const attempts = [];
  globalThis.fetch = async (_url, options) => {
    const body = JSON.parse(options.body); attempts.push(body);
    if ('max_tokens' in body) return { ok: false, status: 400, text: async () => 'Unsupported max_tokens. Use max_completion_tokens instead.' };
    if ('temperature' in body) return { ok: false, status: 400, text: async () => 'Unsupported temperature; only temperature=1 is supported.' };
    return success();
  };
  await summarise({ request });
  assert.equal(attempts.length, 3);
  assert.equal(attempts[1].max_completion_tokens, request.maxTokens);
  assert.ok(!('temperature' in attempts[2]));
  assert.deepEqual(attempts[0].messages, attempts[2].messages);
  for (const status of [401, 402, 403, 404, 429, 500]) {
    globalThis.fetch = async () => ({ ok: false, status, text: async () => 'synthetic failure' });
    await assert.rejects(() => summarise({ request }), error => error instanceof AIError && error.retryable === [429, 500].includes(status));
  }
  globalThis.fetch = async () => { throw new TypeError('synthetic CORS/redirect failure'); };
  await assert.rejects(() => summarise({ request }), /connection|browser requests/);
  globalThis.fetch = async () => ({ ok: true, json: async () => { throw new SyntaxError('synthetic invalid JSON'); } });
  await assert.rejects(() => summarise({ request }), /malformed JSON/);
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ choices: [{ message: { content: '{}' } }] }) });
  await assert.rejects(() => summarise({ request }), /malformed summary/);
  assert.throws(() => parseJSONLoose('{"operations":[],"operations":[1]}'), /usable JSON/);
  assert.throws(() => parseJSONLoose('x'.repeat(1000001)), /bounded/);
  console.log(`Provider transport contracts passed: ${providers} HTTP presets, exact routes/headers, bounded format/parameter fallbacks, errors and malformed output`);
} finally { globalThis.fetch = originalFetch; }
