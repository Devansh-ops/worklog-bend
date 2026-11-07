/** Immutable disclosure/transport handoff. Credentials and revision guards stay private. */
import { canonicalJSON, immutableJSON } from './codec.js';
import { normaliseDestination, isLocalDestination } from './providers.js';

const internals = new WeakMap();
let revision = 0;
const endpointIdentity = endpoint => ({
  id: endpoint?.id || '', kind: endpoint?.kind || 'none', label: endpoint?.label || '',
  baseUrl: endpoint?.baseUrl ? normaliseDestination(endpoint.baseUrl) : '',
  model: endpoint?.model || '', local: isLocalDestination(endpoint),
});

export class StaleRequestError extends Error {
  constructor() { super('The board, notes policy, model, or destination changed. Review a new request before sending.'); this.name = 'StaleRequestError'; }
}

/** Obtain policy decisions from the compiled Bend core, never from visible task rows. */
export async function policyContext({ events, includeNotes = true, startDay = '0000-01-01', endDay = '9999-12-31' }) {
  if (!Array.isArray(events)) throw new Error('Authoritative event history is required before model context can be prepared.');
  const { requestContext } = await import('./domain.js');
  return requestContext(events, includeNotes !== false, { startDay, endDay });
}

export function createRequest({ endpoint, purpose, messages, schema = null, temperature = 0.2, maxTokens = 1600,
  tasks = [], activity = [], includeNotes = true, freeText = '', readCurrent = null, expectedRevision = null }) {
  const identity = endpointIdentity(endpoint);
  const request = immutableJSON({
    version: 1, eligibilityRevision: `request-${++revision}`, purpose,
    endpoint: identity, includeNotes: includeNotes !== false,
    tasks, activity, freeText: String(freeText), messages, schema, temperature, maxTokens,
  });
  const initial = expectedRevision ?? (readCurrent ? canonicalJSON(readCurrent()) : null);
  internals.set(request, {
    endpoint: Object.freeze({ ...endpoint, ...identity, headers: Object.freeze({ ...(endpoint?.headers || {}) }) }),
    check: () => {
      if (readCurrent && canonicalJSON(readCurrent()) !== initial) throw new StaleRequestError();
    },
  });
  return request;
}

export function requestTransport(request) {
  const state = internals.get(request);
  if (!state) throw new Error('This request was not prepared by the request coordinator.');
  state.check();
  return state.endpoint;
}

export function assertRequestCurrent(request) {
  requestTransport(request);
  return true;
}

/** Capture only inside the coordinator; the private source revision is not disclosed. */
export function appRevision(app) {
  return {
    events: app.state.events,
    endpoint: endpointIdentity(app.endpoint),
    includeNotes: app.settings.sendNotes !== false,
    authoritative: app.demo || app.store?.authoritative === true,
  };
}

export function requireAuthoritative(app) {
  if (!app.demo && app.store?.authoritative !== true) throw new Error('Load and validate the complete authoritative history before sending model context.');
  if (app.state.complete === false) throw new Error('Unsupported or incomplete history prevents model context.');
}
