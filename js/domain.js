import core from './generated/core.mjs';
import reports from './generated/reports.mjs';
import views from './generated/views.mjs';
import { CodecError, parseJSON, canonicalJSON, immutableJSON, listToBend, listFromBend } from './codec.js';

const STATUS = Object.freeze({ backlog: 'SBacklog', todo: 'STodo', in_progress: 'SProgress', blocked: 'SBlocked', review: 'SReview', done: 'SDone' });
const PRIORITY = Object.freeze({ low: 'PLow', normal: 'PNormal', high: 'PHigh', urgent: 'PUrgent' });
const statusNames = Object.fromEntries(Object.entries(STATUS).map(([key, value]) => [value, key]));
const priorityNames = Object.fromEntries(Object.entries(PRIORITY).map(([key, value]) => [value, key]));
const none = () => ({ $: 'None' });
const some = value => ({ $: 'Some', value });
const record = (value, path) => {
  if (!value || Array.isArray(value) || typeof value !== 'object') throw new CodecError('expected object', path);
  return value;
};
function text(value, path, { empty = false, max = 100000 } = {}) {
  if (typeof value !== 'string' || (!empty && !value.trim()) || value.length > max) throw new CodecError(`expected ${empty ? '' : 'nonempty '}text of at most ${max} UTF-16 units`, path);
  canonicalJSON(value);
  return value;
}
function boolean(value, path) {
  if (typeof value !== 'boolean') throw new CodecError('expected boolean', path);
  return value;
}
function enumeration(value, choices, path) {
  if (!Object.hasOwn(choices, value)) throw new CodecError('unsupported enum value', path);
  return { $: choices[value] };
}
function tags(value, path) {
  if (!Array.isArray(value) || value.length > 1000) throw new CodecError('expected at most 1000 tags', path);
  return listToBend(value, tag => text(tag, path, { max: 1000 }));
}
function date(value, path) {
  const parsed = typeof value === 'string' ? new Date(`${value}T00:00:00Z`) : new Date(NaN);
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) throw new CodecError('invalid calendar date', path);
  return value;
}
function instant(value, path) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) throw new CodecError('expected timestamp with explicit UTC offset', path);
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) throw new CodecError('invalid timestamp', path);
  // Date silently rolls impossible days forward; reject those using the original
  // civil portion independently from timezone conversion.
  date(value.slice(0, 10), path);
  return parsed.toISOString();
}
export function localDay(instantValue) {
  const value = new Date(instantValue);
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
}
function period(value) {
  if (value !== 'morning' && value !== 'evening') throw new CodecError('expected morning or evening', '$event.kind');
  return value;
}

export function encodeEvent(input, calendar = localDay) {
  const event = immutableJSON(record(input, '$event'));
  const id = text(event.id, '$event.id', { max: 256 });
  const ts = instant(event.ts, '$event.ts');
  const day = date(calendar(ts), '$calendar');
  const type = text(event.type, '$event.type', { max: 256 });
  const taskId = () => text(event.taskId, '$event.taskId', { max: 256 });
  const legacyDefault = (key, fallback) => Object.hasOwn(event, key) ? event[key] : fallback;
  let payload;
  switch (type) {
    case 'task.create':
      payload = { $: 'Created', taskId: taskId(), title: text(legacyDefault('title', '(untitled)'), '$event.title'),
        status: enumeration(legacyDefault('status', 'todo'), STATUS, '$event.status'),
        priority: enumeration(legacyDefault('priority', 'normal'), PRIORITY, '$event.priority'),
        tags: tags(legacyDefault('tags', []), '$event.tags'), private: boolean(legacyDefault('private', false), '$event.private') };
      break;
    case 'task.status': payload = { $: 'StatusChanged', taskId: taskId(), status: enumeration(event.to, STATUS, '$event.to') }; break;
    case 'task.note': payload = { $: 'Noted', taskId: taskId(), text: text(event.text, '$event.text') }; break;
    case 'task.delete': payload = { $: 'Deleted', taskId: taskId() }; break;
    case 'task.edit': {
      const fields = record(event.fields, '$event.fields');
      if (Object.keys(fields).some(key => !['title', 'status', 'priority', 'tags', 'private'].includes(key))) {
        payload = { $: 'Opaque', kind: 'task.edit with unsupported fields' };
        break;
      }
      const field = (key, encode) => Object.hasOwn(fields, key) ? some(encode(fields[key], `$event.fields.${key}`)) : none();
      payload = { $: 'Edited', taskId: taskId(), patch: { $: 'Patch',
        title: field('title', text), status: field('status', (value, path) => enumeration(value, STATUS, path)),
        priority: field('priority', (value, path) => enumeration(value, PRIORITY, path)),
        tags: field('tags', tags), private: field('private', boolean) } };
      break;
    }
    case 'summary.set':
      record(event.summary, '$event.summary');
      payload = { $: 'SummarySet', date: date(event.date, '$event.date'), kind: period(event.kind), body: canonicalJSON(event) };
      break;
    case 'standup.set': payload = { $: 'StandupSet', date: date(event.date, '$event.date'), kind: period(event.kind), text: text(event.text, '$event.text', { empty: true }) }; break;
    default: payload = { $: 'Opaque', kind: type };
  }
  return { $: 'Ev', id, ts, day, payload, canonical: canonicalJSON(event) };
}

export function decodeTask(task) {
  if (task?.$ !== 'Task' || !Object.hasOwn(statusNames, task.status?.$) || !Object.hasOwn(priorityNames, task.priority?.$)) throw new CodecError('unexpected compiled Task');
  return {
    id: task.id, title: task.title, status: statusNames[task.status.$], priority: priorityNames[task.priority.$],
    tags: listFromBend(task.tags), private: task.private, deleted: task.deleted,
    created: task.created, updated: task.updated, done: task.completed.$ === 'Some' ? task.completed.value : null,
    notes: listFromBend(task.notes, note => ({ id: note.id, ts: note.ts, text: note.text })),
  };
}

export class EventConflictError extends Error {
  constructor(id) { super(`Conflicting content for event ${id}`); this.name = 'EventConflictError'; this.eventId = id; }
}

export function mergeEvents(...collections) {
  const events = collections.flatMap(collection => collection ?? []);
  const result = core.merge(listToBend(events, event => encodeEvent(event)), listToBend([]));
  if (result.$ === 'EventConflict') throw new EventConflictError(result.id);
  if (result.$ !== 'Merged') throw new CodecError('unexpected compiled merge result');
  return listFromBend(result.events, event => parseJSON(event.canonical));
}

export function replayEvents(events, calendar = localDay) {
  const result = core.replay(listToBend(events, event => encodeEvent(event, calendar)));
  if (result.$ === 'ReplayConflict') throw new EventConflictError(result.id);
  if (result.$ !== 'Replayed') throw new CodecError('unexpected compiled replay result');
  const compiled = result.state;
  const originals = new Map(events.map(event => [event.id, event]));
  const tasks = new Map(listFromBend(compiled.tasks, decodeTask).map(task => [task.id, task]));
  const summaries = {}, standups = {};
  for (const saved of listFromBend(compiled.summaries)) {
    const event = originals.get(saved.id) ?? parseJSON(saved.body);
    (summaries[saved.date] ??= {})[saved.kind] = { ...event.summary, ts: saved.ts, model: event.model };
  }
  for (const saved of listFromBend(compiled.reports)) {
    const event = originals.get(saved.id);
    (standups[saved.date] ??= {})[saved.kind] = { text: saved.body, style: event?.style, ts: saved.ts };
  }
  const diagnostics = listFromBend(compiled.diagnostics);
  return { tasks, summaries, standups, skipped: diagnostics.length, diagnostics, complete: compiled.complete, compiled };
}

export function validateCommand(events, event, calendar = localDay) {
  const encoded = encodeEvent(event, calendar);
  const result = core.stage(listToBend(events, value => encodeEvent(value, calendar)), encoded);
  if (result.$ === 'StageRejected') throw new CodecError(result.reason, '$command');
  if (result.$ !== 'StageAccepted') throw new CodecError('unexpected compiled command result');
  if (!core.event_eq(result.event, encoded)) throw new CodecError('compiled command changed its supplied event');
  return immutableJSON(event);
}

export function eligibleContext(events, sendNotes) {
  if (typeof sendNotes !== 'boolean') throw new CodecError('expected boolean notes policy');
  const { compiled } = replayEvents(events);
  return listFromBend(core.context(compiled, sendNotes), task => ({
    id: task.id, title: task.title, status: statusNames[task.status.$], priority: priorityNames[task.priority.$],
    tags: listFromBend(task.tags), notes: listFromBend(task.notes, note => ({ id: note.id, ts: note.ts, text: note.text })),
  }));
}

export function requestContext(events, sendNotes, { startDay, endDay }) {
  if (typeof sendNotes !== 'boolean') throw new CodecError('expected boolean notes policy');
  date(startDay, '$window.start'); date(endDay, '$window.end');
  if (startDay > endDay) throw new CodecError('inverted context date window');
  const canonical = mergeEvents(events);
  const { compiled } = replayEvents(canonical);
  const tasks = eligibleContext(canonical, sendNotes);
  const activity = listFromBend(core.context_events(compiled, listToBend(canonical, event => encodeEvent(event)), sendNotes, startDay, endDay), item => ({
    id: item.id, ts: item.ts, day: item.day, taskId: item.taskId, kind: item.kind, type: item.kind,
    title: item.title, status: item.status.$ === 'Some' ? statusNames[item.status.value.$] : null, text: item.text,
  }));
  return immutableJSON({ tasks, events: activity });
}

export function validateProposal(events, event) {
  const encoded = encodeEvent(event);
  const result = core.proposal_stage(listToBend(events, value => encodeEvent(value)), encoded);
  if (result.$ === 'StageRejected') throw new CodecError(result.reason, '$proposal');
  if (result.$ !== 'StageAccepted') throw new CodecError('unexpected compiled proposal result');
  if (!core.event_eq(result.event, encoded)) throw new CodecError('compiled proposal changed its supplied event');
  return immutableJSON(event);
}

export function reportContext(events, sendNotes, { date: day, kind, includePlan = false }) {
  date(day, '$report.date'); period(kind);
  boolean(sendNotes, '$report.sendNotes'); boolean(includePlan, '$report.includePlan');
  const canonical = mergeEvents(events);
  const { compiled } = replayEvents(canonical);
  return listFromBend(reports.model_report(compiled, listToBend(canonical, event => encodeEvent(event)), sendNotes, day, kind === 'morning', includePlan), item => ({
    task: item.task, project: item.project, didToday: listFromBend(item.didToday),
  }));
}

export function reportItems(events, sendNotes, { date: day, kind, includePlan = false }) {
  date(day, '$report.date'); period(kind);
  boolean(sendNotes, '$report.sendNotes'); boolean(includePlan, '$report.includePlan');
  const canonical = mergeEvents(events);
  const { compiled } = replayEvents(canonical);
  return listFromBend(reports.report_items(compiled, listToBend(canonical, event => encodeEvent(event)), sendNotes, day, kind === 'morning', includePlan), item => ({
    taskId: item.taskId, task: item.task, project: item.project, didToday: listFromBend(item.didToday), firstTs: item.firstTs,
  }));
}

export function ownerProjection(events, query = '', wiki = false, suppliedState = null) {
  const compiled = suppliedState ?? replayEvents(events).compiled;
  const folded = text(query, '$search', { empty: true }).trim().toLowerCase();
  const keys = listToBend(listFromBend(compiled.tasks), task => ({ $: 'SearchKey', taskId: task.id, foldedText: views.search_text(task).toLowerCase() }));
  const selected = wiki ? views.wiki_search_tasks(compiled, keys, folded) : views.search_tasks(compiled, keys, folded);
  return {
    tasks: listFromBend(selected, decodeTask),
    columns: Object.fromEntries(Object.entries(STATUS).map(([name, tag]) => [name, listFromBend(views.for_status(selected, { $: tag }), decodeTask)])),
    counts: listFromBend(views.status_counts_tasks(selected), item => ({ status: statusNames[item.status.$], count: item.count })),
    tags: listFromBend(views.tag_counts(selected), item => ({ tag: item.tag, count: item.count })),
  };
}

export function journalDays(events) {
  return listFromBend(views.day_index(listToBend(events, event => encodeEvent(event))), item => ({ day: item.day, count: item.count }));
}
export function taskHistory(events, id) {
  return listFromBend(views.task_history(listToBend(events, event => encodeEvent(event)), text(id, '$taskId', { max: 256 })), event => parseJSON(event.canonical));
}
export function journalEvents(events, day) {
  return listFromBend(views.day_events(listToBend(events, event => encodeEvent(event)), date(day, '$day')), event => parseJSON(event.canonical));
}
export function taggedTasks(events, tag, suppliedState = null) {
  return listFromBend(views.tag_tasks(suppliedState ?? replayEvents(events).compiled, text(tag, '$tag', { max: 1000 })), decodeTask);
}
export function relatedTasks(events, id, suppliedState = null) {
  return listFromBend(views.related_tasks(suppliedState ?? replayEvents(events).compiled, text(id, '$taskId', { max: 256 })), decodeTask);
}

export { core, reports, views, listToBend, listFromBend };
