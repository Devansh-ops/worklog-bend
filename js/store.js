/**
 * store.js — event-sourced task store, persisted as plain JSON in a git repo.
 *
 * Three design choices worth explaining:
 *
 * 1. APPEND-ONLY EVENTS ARE THE SOURCE OF TRUTH; board state is fold(events).
 *    This makes concurrent edits from two machines resolvable: merging is a union
 *    of events by id, re-sorted and re-folded, so no edit is silently lost. It also
 *    means the repo literally contains the changelog of your work, which is the
 *    point of keeping this in git at all.
 *
 * 2. NOTHING IS EVER PUSHED AUTOMATICALLY. Edits accumulate locally as "pending"
 *    events (mirrored into localStorage so a closed tab loses nothing). Publishing
 *    is an explicit, reviewable step: previewCommit() shows exactly what would be
 *    written, and only push() contacts the repo.
 *
 * 3. EVERYTHING IS BOUNDED BY A MONTH. This is what makes the log survive years
 *    rather than months. Events live in data/log/<year>/<month>.json; each month
 *    also gets a rendered <month>.md, each year a README.md, and the root keeps a
 *    thin CHANGELOG.md index. A push therefore rewrites a fixed handful of files
 *    whose size depends on one month of work, never on how long you have used this.
 *    GitHub renders a README.md in whatever directory you browse and renders any .md
 *    you click, in private repos too, so browsing data/log/2026/ shows a readable
 *    year with no Action, no build step and nothing installed.
 *
 * Schema 1/2 board snapshots cannot establish event coverage. Boot discovers every
 * physical source using the pinned Git tree, verifies raw-body cache hashes, and
 * replays canonical history. Unchanged warm loads reuse verified cached bodies.
 */

import { ConflictError } from './github.js';
import { mergeEvents, replayEvents, validateCommand, encodeEvent, planMonths, core } from './domain.js';
import { parseJSON, canonicalJSON, immutableJSON, listToBend, listFromBend } from './codec.js';
import publication from './generated/publication.mjs';
import { createVerifiedSourceReader } from './source-cache.js';

export const STATUSES = Object.freeze([
  { id: 'backlog',     label: 'Backlog' },
  { id: 'todo',        label: 'To Do' },
  { id: 'in_progress', label: 'In Progress' },
  { id: 'blocked',     label: 'Blocked' },
  { id: 'review',      label: 'In Review' },
  { id: 'done',        label: 'Done' },
]);

export const PRIORITIES = Object.freeze(['low', 'normal', 'high', 'urgent']);

const STATUS_LABEL = new Map(STATUSES.map((s) => [s.id, s.label]));
export const statusLabel = (id) => STATUS_LABEL.get(id) || id;

/**
 * Where everything lives. Year directories are not decoration: they are what keeps
 * the repo navigable by hand, and they give each year a README.md that GitHub
 * renders automatically when you click into the folder.
 */
export const PATHS = {
  manifest: 'data/manifest.json',
  board: 'data/board.json',
  boardMd: 'data/BOARD.md',
  changelog: 'CHANGELOG.md',
  logReadme: 'data/log/README.md',
  month:      (m) => `data/log/${m.slice(0, 4)}/${m.slice(5, 7)}.json`,
  monthMd:    (m) => `data/log/${m.slice(0, 4)}/${m.slice(5, 7)}.md`,
  yearReadme: (y) => `data/log/${y}/README.md`,
  // v1 wrote every month flat into data/log/. Still read, so an upgrade loses nothing.
  legacyMonth: (m) => `data/log/${m}.json`,
};

/** How many recent months a boot reads when a checkpoint lets it read fewer. */
const RECENT_MONTHS = 3;

export const SCHEMA = 2;

/* ---------- small helpers ------------------------------------------------ */

/**
 * Calendar dates are local; timestamps stay UTC.
 *
 * Every event carries a UTC instant, because that is the only thing two machines can
 * agree on and the only thing that sorts correctly. But "which day was this" is a
 * question about the person, not about UTC: in Tucson (UTC-7) an update typed at 6pm
 * is already tomorrow in UTC, which filed evening work under the wrong date
 * everywhere it mattered -- the day pages, the summaries, the month a change lands
 * in. So the instant is stored as-is and everything that groups or displays a date
 * comes through here.
 */
const p2 = (n) => String(n).padStart(2, '0');
export const localDate = (at = Date.now()) => {
  const d = at instanceof Date ? at : new Date(at);
  return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`;
};
/** HH:MM in the reader's own timezone, for anything a person reads. */
export const localTime = (at) => {
  const d = at instanceof Date ? at : new Date(at);
  return `${p2(d.getHours())}:${p2(d.getMinutes())}`;
};
export const todayISO = () => localDate();

/** "UTC-07:00" — stamped onto generated pages, since the times on them are local. */
export function tzLabel(at = Date.now()) {
  const mins = -(at instanceof Date ? at : new Date(at)).getTimezoneOffset();
  const sign = mins < 0 ? '-' : '+';
  return `UTC${sign}${p2(Math.floor(Math.abs(mins) / 60))}:${p2(Math.abs(mins) % 60)}`;
}

const monthOf = (iso) => iso.slice(0, 7);
const yearOf = (iso) => iso.slice(0, 4);
const ID_ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyz';

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];
const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const monthName = (m) => MONTH_NAMES[Number(m.slice(5, 7)) - 1] || m;
/** Weekday by arithmetic, not by locale: no ICU dependency, same answer everywhere. */
const weekdayOf = (date) => WEEKDAYS[new Date(`${date}T12:00:00Z`).getUTCDay()];

/**
 * n uniformly-random base36 characters.
 *
 * Rejection-samples bytes below 252 (= 36 x 7) so every character is unbiased; a
 * naive `byte % 36` would skew toward the first four letters. Entropy here matters
 * more than it looks: unionEvents() de-duplicates by event id, so two events that
 * collided on an id would silently merge into one and lose a change.
 */
function rand(n) {
  let out = '';
  while (out.length < n) {
    for (const b of crypto.getRandomValues(new Uint8Array(n + 8))) {
      if (b < 252) {
        out += ID_ALPHABET[b % 36];
        if (out.length === n) break;
      }
    }
  }
  return out;
}

/** Random rather than sequential, so two offline machines cannot mint the same id. */
export const newTaskId = () => `T-${rand(6)}`;                 // 36^6 ~= 2.2e9

/** Timestamp first so ids sort chronologically; 10 random chars make collisions negligible. */
const newEventId = (ts) => `${ts}-${rand(10)}`;                // 36^10 ~= 3.7e15

export function makeEvent(type, payload = {}) {
  const ts = new Date().toISOString();
  return { id: newEventId(ts), ts, type, ...payload };
}

const sortEvents = (events) => mergeEvents(events);

/** Union by event id — the merge primitive that makes concurrent edits safe. */
export const unionEvents = (...lists) => mergeEvents(...lists);

/**
 * Is this event past the checkpoint, i.e. not already folded into the snapshot?
 *
 * Compares (ts, id) — the same total order sortEvents uses — rather than ts alone,
 * because two events can share a millisecond and applying one twice would duplicate
 * a note.
 */
export const afterThrough = (e, through) => !through
  || e.ts > through.ts
  || (e.ts === through.ts && String(e.id) > String(through.id));

/* ---------- fold: events -> board state --------------------------------- */

/**
 * Replay events into task state. Unknown-task references are skipped rather than
 * thrown, because a partially-synced peer may legitimately reference a task whose
 * creation event has not arrived yet; the next merge repairs it.
 *
 * `base` is an optional array of already-folded tasks (a checkpoint from
 * data/board.json), so years of history need not be re-read to know the board.
 * Base tasks are copied, never mutated: this runs on every render.
 */
export function foldEvents(events, { base = null } = {}) {
  if (base?.length) throw new Error('Unverified snapshots cannot seed replay. Load authoritative history.');
  return replayEvents(events);
}

/* ---------- the event files ---------------------------------------------- */

/**
 * Field order for a serialised event: what happened first, bookkeeping last.
 * Stable order means a git diff shows the change, not a reshuffle.
 */
const EVENT_KEYS = ['ts', 'type', 'taskId', 'date', 'kind', 'title', 'status',
  'from', 'to', 'priority', 'tags', 'private', 'text', 'fields', 'summary', 'model', 'style', 'id'];

function orderEvent(e) {
  const out = Object.create(null);
  for (const k of EVENT_KEYS) if (Object.hasOwn(e, k)) out[k] = e[k];
  for (const k of Object.keys(e)) if (!Object.hasOwn(out, k)) out[k] = e[k];
  return out;
}

/**
 * A month file, one event per line.
 *
 * Deliberately not JSON.stringify(…, null, 2): pretty-printing spreads one event over
 * a dozen lines, so `git log -p` becomes unreadable at exactly the moment you want to
 * read it. One line per event means one added line per change, and the file is still
 * ordinary JSON that JSON.parse and GitHub's viewer handle.
 */
export function serialiseMonth(month, events, extras = {}) {
  const lines = sortEvents(events).map((e) => `    ${JSON.stringify(orderEvent(e))}`);
  const body = lines.length ? `\n${lines.join(',\n')}\n  ` : '';
  return `{\n${Object.keys(extras).length ? Object.entries(extras).map(([key, value]) => `  ${JSON.stringify(key)}: ${JSON.stringify(value)},\n`).join('') : ''}  "month": ${JSON.stringify(month)},\n  "count": ${lines.length},\n  "events": [${body}]\n}\n`;
}

/* ---------- human-readable rendering ------------------------------------ */

function describeEvent(e, tasks) {
  const title = tasks?.get(e.taskId)?.title;
  const ref = title ? `${e.taskId} "${title}"` : e.taskId;
  switch (e.type) {
    case 'task.create': return `added ${e.taskId} "${e.title}"`;
    case 'task.status': return `${ref}: ${statusLabel(e.from)} → ${statusLabel(e.to)}`;
    case 'task.note':   return `${ref}: note — ${e.text}`;
    case 'task.edit':   return `${ref}: edited ${Object.keys(e.fields || {}).join(', ')}`;
    case 'task.delete': return `${ref}: removed`;
    case 'summary.set': return `${e.kind} summary for ${e.date}`;
    case 'standup.set': return `${e.kind} report copied for ${e.date}`;
    default:            return `${e.type} ${e.taskId || ''}`.trim();
  }
}

/** One-line commit subject plus a bulleted body, so `git log` reads as a work journal. */
function buildCommitMessage(events, tasks) {
  const counts = events.reduce((m, e) => (m[e.type] = (m[e.type] || 0) + 1, m), {});
  const bits = [];
  if (counts['task.create']) bits.push(`${counts['task.create']} new`);
  if (counts['task.status']) bits.push(`${counts['task.status']} moved`);
  if (counts['task.note'])   bits.push(`${counts['task.note']} note${counts['task.note'] > 1 ? 's' : ''}`);
  if (counts['task.edit'])   bits.push(`${counts['task.edit']} edited`);
  if (counts['task.delete']) bits.push(`${counts['task.delete']} removed`);
  if (counts['summary.set']) bits.push('summary');
  if (counts['standup.set']) bits.push('report');

  const subject = `worklog ${todayISO()}: ${bits.join(', ') || `${events.length} changes`}`;
  const body = events.map((e) => `- ${describeEvent(e, tasks)}`).join('\n');
  return `${subject}\n\n${body}\n`;
}

const groupByDay = (events) => {
  const byDay = new Map();
  for (const e of sortEvents(events)) {
    const d = localDate(e.ts);
    if (!byDay.has(d)) byDay.set(d, []);
    byDay.get(d).push(e);
  }
  return byDay;
};

/**
 * One month, rendered. This is the file a human actually reads — GitHub renders it
 * on click, private repo or not, with nothing installed and no Action configured.
 * Newest day first, so the top of the file is the interesting part.
 */
export function renderMonthMd(month, events, tasks) {
  const year = month.slice(0, 4);
  const mm = month.slice(5, 7);
  const byDay = groupByDay(events);
  const days = [...byDay.keys()].sort().reverse();

  const out = [
    `# ${monthName(month)} ${year} — work log`,
    '',
    `[All years](../../../${PATHS.changelog}) · [${year}](README.md) · [Current board](../../BOARD.md) · [Raw events](${mm}.json)`,
    '',
    `_Generated from the event log. ${days.length} day${days.length === 1 ? '' : 's'} logged, `
      + `${events.length} change${events.length === 1 ? '' : 's'}. Newest first. `
      + `Dates and times are local (${tzLabel()}); ${mm}.json keeps the UTC timestamps._`,
    '',
  ];

  if (!days.length) out.push('Nothing logged this month yet.', '');

  for (const d of days) {
    const all = byDay.get(d);
    const sums = all.filter((e) => e.type === 'summary.set');
    const reports = all.filter((e) => e.type === 'standup.set');
    const rest = all.filter((e) => !['summary.set', 'standup.set'].includes(e.type));

    out.push(`## ${d} — ${weekdayOf(d)}`, '');

    // Quoted, not inlined. Two reasons: it is verbatim text that went somewhere else,
    // which a quote says better than a paragraph; and a report written in the markdown
    // style contains its own "## Project" lines, which would otherwise break out and
    // become headings of this page.
    for (const r of reports) {
      out.push(`**${r.kind} report**`, '');
      for (const line of String(r.text || '').split('\n')) out.push(line.trim() ? `> ${line}` : '>');
      out.push('');
    }

    for (const s of sums) {
      if (s.summary?.headline) out.push(`**${s.kind} summary** — ${s.summary.headline}`, '');
      for (const b of s.summary?.bullets || []) out.push(`- ${b.text}`);
      if (s.summary?.bullets?.length) out.push('');
      for (const r of s.summary?.risks || []) out.push(`- ⚠️ ${r}`);
      if (s.summary?.risks?.length) out.push('');
    }

    if (rest.length) {
      out.push('| Time | Change |', '| --- | --- |');
      for (const e of rest) {
        // Escape pipes so a note containing "|" cannot break the table.
        out.push(`| ${localTime(e.ts)} | ${describeEvent(e, tasks).replace(/\|/g, '\\|')} |`);
      }
      out.push('');
    }
  }
  return out.join('\n');
}

/**
 * data/log/<year>/README.md — GitHub renders this the moment you browse into the
 * year folder, which is the whole trick behind "readable without doing anything".
 */
export function renderYearReadme(year, stats) {
  const rows = stats.filter((s) => s.month.startsWith(`${year}-`)).sort((a, b) => b.month.localeCompare(a.month));
  const total = rows.reduce((n, s) => n + (s.events || 0), 0);
  const days = rows.reduce((n, s) => n + (s.days || 0), 0);

  const out = [
    `# ${year} — work log`,
    '',
    `[All years](../../../${PATHS.changelog}) · [Current board](../../BOARD.md)`,
    '',
    `_${days} day${days === 1 ? '' : 's'} logged, ${total} change${total === 1 ? '' : 's'} this year. Newest month first._`,
    '',
    '| Month | Days logged | Changes | Read | Raw |',
    '| --- | --- | --- | --- | --- |',
  ];
  for (const s of rows) {
    const mm = s.month.slice(5, 7);
    out.push(`| ${monthName(s.month)} | ${s.days ?? '—'} | ${s.events ?? '—'} | [${mm}.md](${mm}.md) | [${mm}.json](${mm}.json) |`);
  }
  out.push('', 'Each `.json` is the append-only event log for that month — the source of truth.',
    'Each `.md` is the same month rendered for reading. Both are committed; neither needs tooling.', '');
  return out.join('\n');
}

/**
 * Root CHANGELOG.md — an index, not the history.
 *
 * v1 rendered every event ever into this one file and rewrote it on every push. That
 * does not survive years: the file grows without bound, GitHub stops rendering large
 * markdown, and the diff on every push is the size of your whole career. Now it links
 * to per-month files, so it stays a page long no matter how long you use this.
 */
export function renderChangelogIndex(stats) {
  const byYear = new Map();
  for (const s of stats) {
    const y = yearOf(s.month);
    if (!byYear.has(y)) byYear.set(y, []);
    byYear.get(y).push(s);
  }
  const years = [...byYear.keys()].sort().reverse();

  const out = [
    '# Work log changelog',
    '',
    `**Current board:** [${PATHS.boardMd}](${PATHS.boardMd}) · **How this is laid out:** [${PATHS.logReadme}](${PATHS.logReadme})`,
    '',
    '_An index. Every month is a rendered page you can click straight to; the JSON beside it is the source._',
    '',
  ];

  if (!years.length) out.push('Nothing logged yet.', '');

  for (const y of years) {
    const rows = byYear.get(y).sort((a, b) => b.month.localeCompare(a.month));
    const total = rows.reduce((n, s) => n + (s.events || 0), 0);
    out.push(`## ${y} — ${total} change${total === 1 ? '' : 's'} · [year index](data/log/${y}/)`, '',
      '| Month | Days | Changes | | |', '| --- | --- | --- | --- | --- |');
    for (const s of rows) {
      out.push(`| ${s.month} | ${s.days ?? '—'} | ${s.events ?? '—'} `
        + `| [read](${PATHS.monthMd(s.month)}) | [json](${PATHS.month(s.month)}) |`);
    }
    out.push('');
  }
  return out.join('\n');
}

/** Explains the layout to whoever opens the folder, including future you. Static. */
export function renderLogReadme() {
  return `# Event log

Your work, append-only, one file per month:

\`\`\`
data/log/<year>/<month>.json    the events -- the source of truth
data/log/<year>/<month>.md      the same month, rendered to read
data/log/<year>/README.md       that year's index (this page, one level down)
\`\`\`

Nothing here is generated by CI. Both files are committed together on every push, so
browsing this repo on GitHub — public or private — shows readable history with nothing
installed and no Action to configure.

## Why monthly

One file per month keeps every diff about a month of work rather than about your whole
history, so \`git log -p\` stays readable and the files stay small however many years
accumulate. \`data/board.json\` is a snapshot of the current board and doubles as a
checkpoint, which is why the app can open your board without reading every past month.

## Reading it

\`\`\`sh
git log --oneline                                    # one entry per push
git log -p data/log/$(date +%Y)/$(date +%m).json     # this month's events, in detail
git log --follow -p -- data/log                      # everything, oldest last
\`\`\`

One event per line is on purpose: a new change shows up as one added line.
`;
}

/**
 * data/BOARD.md — the board as a page.
 *
 * Done is capped: completed work is history and history lives in the monthly files,
 * so this file stays a readable page instead of growing for years.
 */
const DONE_SHOWN = 15;

export function renderBoardMd(tasks) {
  const live = [...tasks.values()].filter((t) => !t.deleted);
  const open = live.filter((t) => t.status !== 'done');
  const out = [
    '# Board',
    '',
    // BOARD.md lives in data/, so links are relative to that: the changelog is one
    // level up, the month is a sibling subtree.
    `[Changelog](../${PATHS.changelog}) · [This month](${PATHS.monthMd(monthOf(todayISO())).replace('data/', '')})`,
    '',
    `_Generated on each push, ${todayISO()}. ${open.length} open, ${live.length - open.length} done._`,
    '',
  ];

  for (const s of STATUSES) {
    let col = live.filter((t) => t.status === s.id);
    if (!col.length) continue;
    const total = col.length;

    if (s.id === 'done') {
      col = col.sort((a, b) => String(b.done || b.updated).localeCompare(String(a.done || a.updated))).slice(0, DONE_SHOWN);
      out.push(`## ${s.label} (${total})`, '');
    } else {
      col = col.sort((a, b) => PRIORITIES.indexOf(b.priority) - PRIORITIES.indexOf(a.priority));
      out.push(`## ${s.label} (${total})`, '');
    }

    for (const t of col) {
      const bits = [`\`${t.id}\``];
      if (t.priority && t.priority !== 'normal') bits.push(t.priority);
      if (t.tags?.length) bits.push(t.tags.map((g) => `#${g}`).join(' '));
      bits.push(`updated ${localDate(t.updated)}`);
      out.push(`- **${String(t.title).replace(/\n/g, ' ')}** · ${bits.join(' · ')}`);
      const last = t.notes?.[t.notes.length - 1];
      if (last) out.push(`  - _${localDate(last.ts)}_: ${String(last.text).replace(/\n/g, ' ')}`);
    }
    if (s.id === 'done' && total > DONE_SHOWN) {
      out.push('', `_…and ${total - DONE_SHOWN} more finished earlier. See [the changelog](../${PATHS.changelog})._`);
    }
    out.push('');
  }

  if (!live.length) out.push('No tasks yet.', '');
  return out.join('\n');
}

/**
 * How long a finished task keeps its notes in the snapshot. Past this the task is
 * still listed in full -- so reopening it works and it never vanishes -- but its notes
 * are left in the monthly log, which is where they are already committed.
 */
const NOTES_KEPT_DAYS = 90;

/**
 * Snapshot of live state, and the load checkpoint.
 *
 * `through` names the last event folded in here, which is what lets a boot skip
 * reading every past month: state = these tasks + events after `through`.
 *
 * Notes on long-finished tasks are trimmed rather than carried forever, because this
 * file is downloaded on every boot and rewritten on every push. Without trimming it
 * grows past GitHub's 500 KB / 20,000-line diff limit within a few years -- I measured
 * 931 KB at three years of daily use. `noteCount` records what was left behind so the
 * UI can say so and offer to fetch it, and fold() applies recovered notes idempotently.
 */
export function renderBoardSnapshot(tasks, through) {
  const cutoff = new Date(Date.now() - NOTES_KEPT_DAYS * 86400000).toISOString();
  const live = [...tasks.values()]
    .sort((a, b) => STATUSES.findIndex((s) => s.id === a.status) - STATUSES.findIndex((s) => s.id === b.status)
      || (a.created < b.created ? -1 : 1))
    .map((t) => {
      const stale = t.status === 'done' && String(t.done || t.updated) < cutoff;
      if (!stale || !t.notes?.length) return t;
      return { ...t, notes: [], noteCount: t.notes.length };
    });

  const head = JSON.stringify({
    schema: SCHEMA,
    cacheOnly: true,
    generated: new Date().toISOString(),
    through: through ? { ts: through.ts, id: through.id } : null,
    counts: STATUSES.reduce((m, s) => (m[s.id] = live.filter((t) => !t.deleted && t.status === s.id).length, m), {}),
  }, null, 2);

  const lines = live.map((t) => `    ${JSON.stringify(slimTask(t))}`);
  const body = lines.length ? `\n${lines.join(',\n')}\n  ` : '';
  return `${head.slice(0, -2)},\n  "tasks": [${body}]\n}\n`;
}

/**
 * A task, ready to serialise on one line.
 *
 * One line per task is the same bargain as one line per event: a changed task is a
 * one-line diff instead of a twelve-line reshuffle, and the file stays under GitHub's
 * 20,000-line diff limit for decades rather than years. Fields that fold() defaults
 * anyway (empty tags, no notes, not private, not deleted) are left out; unrecognised
 * fields are always kept, so a future version's data survives a round trip here.
 */
const TASK_KEYS = ['id', 'title', 'status', 'priority', 'tags', 'created', 'updated',
  'done', 'private', 'deleted', 'notes', 'noteCount'];

function slimTask(t) {
  const out = Object.create(null);
  for (const k of TASK_KEYS) {
    const v = t[k];
    if (v == null) continue;
    if (k === 'private' || k === 'deleted') { if (v) out[k] = true; continue; }
    if (Array.isArray(v) && v.length === 0) continue;
    out[k] = v;
  }
  for (const k of Object.keys(t)) if (!TASK_KEYS.includes(k) && t[k] != null) out[k] = t[k];
  return out;
}

/* ---------- the manifest ------------------------------------------------- */

/**
 * The manifest is the index that makes a lazy boot possible: it lists every month
 * with its size, so the app (and the rendered pages) can describe history it has not
 * read. v1 listed bare month strings; those still load, just without counts.
 */
function readManifest(manifest) {
  const stats = new Map();
  if (manifest && !Array.isArray(manifest.months)) throw new Error('Manifest months must be an array.');
  for (const entry of manifest?.months || []) {
    const s = typeof entry === 'string' ? { month: entry } : { ...entry };
    if (typeof s.month !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(s.month)) throw new Error('Invalid manifest month.');
    if (stats.has(s.month)) throw new Error('Repeated manifest month.');
    stats.set(s.month, s);
  }
  return stats;
}

export function renderManifest(stats) {
  return `${JSON.stringify({
    schema: SCHEMA,
    app: 'worklog',
    updated: new Date().toISOString(),
    months: [...stats.values()].sort((a, b) => a.month.localeCompare(b.month)),
  }, null, 2)}\n`;
}

/* ---------- the store ---------------------------------------------------- */

export class Store {
  constructor(repo) {
    this.repo = repo;
    this.remoteEvents = [];   // months actually read, as last seen in the repo
    this.pending = [];        // staged locally, NOT yet published
    this.knownMonths = [];    // every month the manifest knows about
    this.loadedMonths = [];   // the subset we have read
    this.monthStats = new Map();
    this.checkpoint = null;   // {through:{ts,id}, tasks:[…]} from data/board.json
    this.legacyMonths = [];   // months found only at their v1 flat path
    this.manifestSchema = SCHEMA;
    this.loaded = false;
    this._pendingKey = `worklog.pending.${repo.owner}/${repo.repo}#${encodeURIComponent(repo.branch || 'main')}`;
    this._pendingJournal = `worklog.pending-journal.v1.${encodeURIComponent(repo.owner + '/' + repo.repo)}#${encodeURIComponent(repo.branch || 'main')}#`;
    this._persistedPending = [];
    this._pendingRaw = null;
    this._legacyPendingKey = `worklog.pending.${repo.owner}/${repo.repo}`;
    this.envelopes = new Map();
    this.schemas = new Map();
    this._plans = new WeakSet();
    this.authoritative = false;
    this._restorePending();
  }

  /* --- pending-change persistence (survives a closed tab) --- */

  _restorePending() {
    if (this.repo.demo) return;
    try {
      const { pending, raw: saved } = this._readPendingStorage();
      const legacy = localStorage.getItem(this._legacyPendingKey);
      if (!saved && legacy) this.pendingRecovery = { key: this._legacyPendingKey, text: legacy };
      this.pending = pending;
      this._persistedPending = pending;
      this._pendingRaw = saved;
    } catch (error) {
      this.storageError = error.message;
      this.recoveryRequired = true;
    }
  }

  _pendingArray(value) {
    if (!Array.isArray(value)) throw new Error('Stored pending changes must be an array.');
    return value.map(event => { encodeEvent(event); return immutableJSON(event); });
  }

  _withoutEvents(events, removed) {
    return listFromBend(core.acknowledge(listToBend(events, event => encodeEvent(event)), listToBend(removed, event => encodeEvent(event)), true), event => parseJSON(event.canonical));
  }

  _readPendingOperations() {
    if (!Number.isInteger(localStorage.length) || typeof localStorage.key !== 'function') throw new Error('Browser storage cannot enumerate recovery journals.');
    const keys = [];
    for (let index = 0; index < localStorage.length; index++) {
      const key = localStorage.key(index);
      if (typeof key === 'string' && key.startsWith(this._pendingJournal)) keys.push(key);
    }
    const additions = [], removals = [];
    for (const key of keys.sort()) {
      const text = localStorage.getItem(key);
      if (text === null) continue;
      const operation = parseJSON(text);
      if (!operation || operation.version !== 1 || operation.scope !== this._pendingKey) throw new Error('Invalid pending recovery journal.');
      additions.push(this._pendingArray(operation.added));
      removals.push(...this._pendingArray(operation.removed));
    }
    // Complete event equality is supplied by Bend, including unknown envelopes.
    // A removal acknowledges only values observed by its originating operation.
    return { additions, removals };
  }

  _readPendingStorage() {
    const raw = localStorage.getItem(this._pendingKey);
    const base = this._pendingArray(parseJSON(raw === null ? '[]' : raw));
    const { additions, removals } = this._readPendingOperations();
    return { raw, removed: removals, pending: this._withoutEvents(mergeEvents(base, ...additions), removals) };
  }

  _assertPendingIdsAvailable(events) {
    if (this.repo.demo) return;
    let removed;
    try { removed = this._readPendingOperations().removals; }
    catch (error) {
      this.storageError = error.message; this.recoveryRequired = true; this.authoritative = false;
      throw new Error('Pending recovery data needs attention. Existing drafts and stored originals were preserved; recover them before editing.');
    }
    const retired = listToBend(removed, event => encodeEvent(event));
    for (const event of events) {
      const encoded = encodeEvent(event);
      if (core.ids_contains(retired, encoded.id)) throw new Error('This event ID was already discarded or acknowledged. Create a new event instead.');
    }
  }

  _appendPendingOperation(added, removed) {
    if (!added.length && !removed.length) return false;
    for (let attempt = 0; attempt < 4; attempt++) {
      const nonce = globalThis.crypto.randomUUID ? globalThis.crypto.randomUUID()
        : [...globalThis.crypto.getRandomValues(new Uint8Array(16))].map(value => value.toString(16).padStart(2, '0')).join('');
      const key = this._pendingJournal + nonce;
      if (localStorage.getItem(key) !== null) continue;
      localStorage.setItem(key, canonicalJSON({ version: 1, scope: this._pendingKey, added, removed }));
      return true;
    }
    throw new Error('Could not allocate a unique pending recovery journal.');
  }

  _savePending() {
    if (this.repo.demo) return;
    if (this.recoveryRequired) throw new Error('Recover the invalid saved pending data before overwriting it.');
    let journaled = false;
    this.storageNotice = null;
    try {
      const peerChanged = localStorage.getItem(this._pendingKey) !== this._pendingRaw;
      const added = this._withoutEvents(this.pending, this._persistedPending);
      const removed = this._withoutEvents(this._persistedPending, this.pending);
      // Unique append comes first. A stale concurrent snapshot write can no
      // longer erase either operation, even without cross-process compare/swap.
      // Include the whole observed draft, so pre-journal array-only edits also
      // gain recovery evidence. Equivalent deliveries deduplicate in Bend.
      if (added.length || removed.length) journaled = this._appendPendingOperation(this.pending, removed);
      let restored;
      try { restored = this._readPendingStorage(); }
      catch (error) { this.recoveryRequired = true; this.authoritative = false; throw error; }
      const retired = listToBend(restored.removed, value => encodeEvent(value));
      if (added.some(event => core.ids_contains(retired, event.id))) {
        this.recoveryRequired = true; this.authoritative = false;
        const error = new Error('A peer discarded or acknowledged this event ID while it was being staged. It was not accepted; its draft operation was retained for recovery.');
        error.pendingIdRetired = true;
        throw error;
      }
      this.pending = restored.pending;
      this._persistedPending = restored.pending;
      const raw = canonicalJSON(restored.pending);
      localStorage.setItem(this._pendingKey, raw);
      this._pendingRaw = raw;
      this.storageNotice = peerChanged ? 'Changes from another tab were reconciled with this tab. Review the pending list.' : null;
      this.storageError = null;
    }
    catch (error) {
      this.storageError = error.message;
      const failure = new Error(error.pendingIdRetired ? error.message : this.recoveryRequired
        ? 'Pending recovery data needs attention. Stored originals were preserved; keep this tab open and recover the saved data before editing.'
        : journaled ? 'Local storage snapshot failed. Changes remain in the recovery journal and in memory; keep this tab open.'
          : 'Local storage failed. Changes remain in memory; keep this tab open.');
      failure.retainedInMemory = !error.pendingIdRetired;
      throw failure;
    }
  }

  recoverLegacyPending() {
    if (!this.pendingRecovery) return;
    const recovered = parseJSON(this.pendingRecovery.text);
    if (!Array.isArray(recovered)) throw new Error('Legacy pending changes must be an array.');
    recovered.forEach(event => encodeEvent(event));
    this._assertPendingIdsAvailable(recovered);
    this.pending = mergeEvents(this.pending, recovered).map(immutableJSON);
    this._savePending();
    // Keep the original recovery source. Other branches must never inherit it automatically.
    this.pendingRecovery = null;
  }

  /** Stage events locally. Never contacts the network. */
  stage(...events) {
    if (this.recoveryRequired) throw new Error('Recover the invalid saved pending data before editing.');
    if (!this.authoritative || !this.state.complete) throw new Error('Load complete supported history before editing.');
    this._assertPendingIdsAvailable(events.flat());
    let accepted = [...this.pending];
    for (const event of events.flat()) accepted.push(validateCommand(mergeEvents(this.remoteEvents, accepted), event));
    this.pending = accepted;
    this._savePending();
    return this;
  }

  discardPending() {
    this.pending = [];
    this._savePending();
  }

  get hasPending() { return this.pending.length > 0; }

  /**
   * What is staged, in words, for a UI that wants to show it without committing to it.
   *
   * previewCommit() also produces these, but it builds every file first and throws
   * when a touched month has not been read from the repo — right for the publish
   * gate, wrong for a badge someone clicked to see what they had done. This asks
   * only what folding the pending events says, so it always answers.
   */
  get pendingDescriptions() {
    const { tasks } = this.state;
    return this.pending.map((e) => ({
      type: e.type,
      ts: e.ts,
      taskId: e.taskId || null,
      text: describeEvent(e, tasks),
    }));
  }

  /**
   * Bend selects pending destination months and both physical source and local-day
   * destination for historical relocation. Physical envelopes are the evidence of
   * where a published event actually lives; its UTC timestamp is not that evidence.
   */
  get touchedMonths() {
    if (!this.loaded) return [];
    return this._monthPlan(false).groups.filter(group => group.write).map(group => group.month);
  }

  _monthPlan(migration) {
    if (!this.fullyLoaded) throw new Error('Cannot build a commit: complete physical source history has not been read from the repo yet.');
    const sources = this.loadedMonths.map(month => {
      const current = this.envelopes.get(PATHS.month(month));
      const legacy = this.envelopes.get(PATHS.legacyMonth(month));
      return { month, currentExists: !!current, legacyExists: !!legacy, events: [...(current?.events || []), ...(legacy?.events || [])] };
    });
    return planMonths(sources, this.pending, { schemas: [...this.schemas.values()], currentMonth: monthOf(todayISO()), migration });
  }

  /**
   * Current view of the world is authoritative canonical replay. Unverified
   * snapshot markers never suppress late events or deletion provenance.
   */
  get state() {
    if (this._derived?.remote !== this.remoteEvents || this._derived?.pending !== this.pending) {
      const events = mergeEvents(this.remoteEvents, this.pending);
      this._derived = { remote: this.remoteEvents, pending: this.pending, events, state: replayEvents(events) };
    }
    return this._derived.state;
  }

  get events() { this.state; return this._derived.events; }

  get tasks() {
    return [...this.state.tasks.values()].filter((t) => !t.deleted);
  }

  /* --- reading --- */

  /**
   * Pin and verify all physical sources before showing authoritative state.
   * Only verified unchanged raw bodies may bypass network reads.
   */
  async load({ recent = RECENT_MONTHS } = {}) {
    this.authoritative = false;
    this.loaded = false;
    this.envelopes = new Map();
    this.schemas = new Map();
    this.sourceReader = null;
    if (this.repo.pinRevision) await this.repo.pinRevision();
    const index = this.repo.sourceIndex ? await this.repo.sourceIndex() : null;
    if (index) this.sourceReader = createVerifiedSourceReader(this.repo, index);
    const manifest = await this._readJSON(PATHS.manifest);
    this.monthStats = readManifest(manifest);
    this.manifestSchema = Number(manifest?.schema) || 1;

    // Always include the current month, even on a repo that has never been written.
    const cur = monthOf(todayISO());
    if (!this.monthStats.has(cur)) this.monthStats.set(cur, { month: cur });
    this.knownMonths = [...new Set([...this.monthStats.keys(), ...(index?.months || [])])].sort();

    const snap = await this._readJSON(PATHS.board);
    // Schema 1/2 snapshots lack verifiable coverage. They are display caches only.
    this.checkpoint = null;
    this.replayMode = 'authoritative full replay';

    this.remoteEvents = [];
    this.loadedMonths = [];
    this.legacyMonths = [];
    await this.loadMonths(this.knownMonths);
    this.sourceReader?.flush();
    this.sourceCacheStats = this.sourceReader?.stats || null;
    this.loaded = true;
    this.authoritative = this.state.complete && !this.recoveryRequired;
    if (this.authoritative && this.pending.length) {
      const remaining = core.acknowledge(listToBend(this.pending, event => encodeEvent(event)), listToBend(this.remoteEvents, event => encodeEvent(event)), true);
      const recovered = listFromBend(remaining, event => parseJSON(event.canonical));
      if (recovered.length !== this.pending.length) {
        this.pending = recovered;
        try { this._savePending(); } catch { /* storageError remains visible; remote confirmation is authoritative. */ }
      }
    }
    return this;
  }

  /** Read months we have not read yet and merge them in. Safe to call repeatedly. */
  async loadMonths(months) {
    const todo = [...new Set(months)].filter((m) => m && !this.loadedMonths.includes(m));
    if (!todo.length) return this;
    const files = await Promise.all(todo.map((m) => this._readMonth(m)));
    this.remoteEvents = unionEvents(this.remoteEvents, ...files.map((f) => f?.events || []));
    this.loadedMonths = [...this.loadedMonths, ...todo].sort();
    for (let index = 0; index < todo.length; index++) {
      const month = todo[index], events = files[index]?.events || [];
      if (!this.monthStats.has(month)) this.monthStats.set(month, {
        month, events: events.length, days: new Set(events.map(event => localDate(event.ts))).size,
      });
    }
    return this;
  }

  loadYear(year) { return this.loadMonths(this.knownMonths.filter((m) => m.startsWith(`${year}-`))); }
  loadAll() { return this.loadMonths(this.knownMonths); }

  get years() { return [...new Set(this.knownMonths.map(yearOf))].sort().reverse(); }
  yearLoaded(year) { return this.knownMonths.filter((m) => m.startsWith(`${year}-`)).every((m) => this.loadedMonths.includes(m)); }
  get fullyLoaded() { return this.knownMonths.every((m) => this.loadedMonths.includes(m)); }

  /** Month files moved into year folders in v2; fall back to the flat v1 path. */
  async _readMonth(month) {
    const current = await this._readJSON(PATHS.month(month));
    const legacy = await this._readJSON(PATHS.legacyMonth(month));
    if (legacy && !this.legacyMonths.includes(month)) this.legacyMonths.push(month);
    const extras = Object.create(null);
    for (const envelope of [current, legacy]) {
      if (!envelope) continue;
      if (!Array.isArray(envelope.events)) throw new Error('Month events must be an array.');
      if (envelope.month && envelope.month !== month) throw new Error('Month path and envelope disagree.');
      for (const [key, value] of Object.entries(envelope)) {
        if (['month', 'count', 'events', 'schema'].includes(key)) continue;
        if (Object.hasOwn(extras, key) && canonicalJSON(extras[key]) !== canonicalJSON(value)) throw new Error('Conflicting retained month metadata: ' + key);
        extras[key] = value;
      }
    }
    return current || legacy ? { ...extras, events: mergeEvents(current?.events || [], legacy?.events || []) } : null;
  }

  async _readJSON(path) {
    const file = await (this.sourceReader || this.repo).getFile(path);
    if (!file) return null;
    const value = parseJSON(file.text);
    if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error(path + ' must be an object.');
    const schema = value.schema ?? 1;
    if (!Number.isInteger(schema) || schema < 0 || schema > 0xffffffff || !core.schema_allowed(schema)) throw new Error(path + ': unsupported schema ' + schema + '. No write plan is permitted.');
    this.envelopes.set(path, immutableJSON(value));
    this.schemas.set(path, schema);
    return value;
  }

  _monthText(month, events) {
    const extras = Object.create(null);
    const current = this.envelopes.get(PATHS.month(month));
    const legacy = this.envelopes.get(PATHS.legacyMonth(month));
    if (current?.schema !== undefined || legacy?.schema !== undefined) extras.schema = current?.schema ?? legacy.schema;
    for (const path of [PATHS.month(month), PATHS.legacyMonth(month)]) {
      for (const [key, value] of Object.entries(this.envelopes.get(path) || {})) {
        if (!['month', 'count', 'events', 'schema'].includes(key)) extras[key] = value;
      }
    }
    return serialiseMonth(month, events, extras);
  }

  _manifestText(stats) {
    return JSON.stringify({ ...this.envelopes.get(PATHS.manifest), ...parseJSON(renderManifest(stats)) }, null, 2) + '\n';
  }

  _boardText(tasks, through) {
    const previous = this.envelopes.get(PATHS.board) || {};
    const generated = parseJSON(renderBoardSnapshot(tasks, through));
    if (previous.retainedTaskExtensions !== undefined && (!previous.retainedTaskExtensions || typeof previous.retainedTaskExtensions !== 'object' || Array.isArray(previous.retainedTaskExtensions))) throw new Error('Unsupported retained snapshot extension envelope.');
    const extensions = Object.assign(Object.create(null), previous.retainedTaskExtensions || {});
    for (const task of previous.tasks || []) {
      if (!task || typeof task.id !== 'string') continue;
      const unknown = Object.fromEntries(Object.entries(task).filter(([key]) => !TASK_KEYS.includes(key)));
      if (Object.keys(unknown).length) extensions[task.id] = { ...extensions[task.id], ...unknown };
    }
    generated.tasks = generated.tasks.map(task => ({ ...extensions[task.id], ...task }));
    const output = { ...previous, ...generated,
      ...(Object.keys(extensions).length ? { retainedTaskExtensions: extensions } : {}) };
    const lines = output.tasks.map(task => '    ' + JSON.stringify(task));
    delete output.tasks;
    const head = JSON.stringify(output, null, 2);
    return head.slice(0, -2) + ',\n  "tasks": [' + (lines.length ? '\n' + lines.join(',\n') + '\n  ' : '') + ']\n}\n';
  }

  _sealPlan(plan) {
    if (!this.loaded || !this.authoritative || !this.state.complete) throw new Error('Complete supported authoritative history is required before a write plan.');
    const sealed = immutableJSON({ ...plan, target: this.repo.slug || this.repo.owner + '/' + this.repo.repo,
      branch: this.repo.branch || 'main', base: this.repo.readRevision || null,
      sourceSchemas: [...this.schemas.values()], pending: this.pending,
      deletions: plan.deletions || [] });
    this._plans.add(sealed);
    return sealed;
  }

  _approvedPlan(plan) {
    if (!plan || !this._plans.has(plan)) throw new Error('An exact preview from this store must be approved first.');
    const execution = { ...plan, target: this.repo.slug || this.repo.owner + '/' + this.repo.repo,
      branch: this.repo.branch || 'main', base: this.repo.readRevision || null };
    if (!publication.approved(listToBend([...this.schemas.values()]), canonicalJSON(plan), canonicalJSON(execution))) throw new Error('The approved publication plan changed. Preview it again.');
    return plan;
  }

  /* --- publishing --- */

  /**
   * Describe the commit that push() would make. Purely local; safe to call freely.
   * The UI shows this for confirmation, because nothing goes to the repo unasked.
   *
   * Every file here is bounded by one month of work or by the current board, so the
   * commit is the same size in year five as in week one.
   */
  /* --- upgrading a repo written by an older version --------------------- */

  /**
   * Does this repo predate the current layout?
   *
   * A v1 repo is not broken -- v1 wrote no `through` marker, so load() reads every
   * month and the board comes out complete and correct. What it lacks is the layout:
   * months sit flat in data/log/, nothing is rendered as markdown, and CHANGELOG.md
   * holds the whole history in one file. So this is an offer, never a requirement,
   * and nothing here runs until the user asks for it.
   */
  get needsMigration() {
    return this.loaded && (this.legacyMonths.length > 0 || this.manifestSchema < SCHEMA);
  }

  /**
   * The upgrade commit: every month rewritten into its year directory with a rendered
   * page beside it, fresh indexes, and the old flat files removed in the same commit.
   *
   * Unlike previewCommit() this is deliberately proportional to the whole history --
   * it is a one-off, and it is the only way to render months written before the
   * renderers existed. It needs the full history loaded first, because rewriting a
   * month from a partial read would drop events.
   */
  migrationCommit() {
    if (!this.needsMigration) return null;
    if (!this.fullyLoaded) throw new Error('Load the full history before upgrading: this rewrites every month.');

    const planned = this._monthPlan(true);
    const merged = planned.events;
    const through = merged[merged.length - 1] || null;
    const { tasks } = foldEvents(merged);

    const written = planned.groups.filter(group => group.write);
    const months = written.map(group => group.month);
    const stats = new Map();
    const eventsIn = new Map();
    for (const group of written) {
      const m = group.month;
      eventsIn.set(m, group.events);
      stats.set(m, {
        ...this.monthStats.get(m),
        month: m,
        events: group.count,
        days: group.days,
        updated: new Date().toISOString(),
      });
    }
    const statList = [...stats.values()];
    const years = [...new Set(months.map(yearOf))];

    const files = [
      ...months.flatMap((m) => [
        { path: PATHS.month(m),   text: this._monthText(m, eventsIn.get(m)) },
        { path: PATHS.monthMd(m), text: renderMonthMd(m, eventsIn.get(m), tasks) },
      ]),
      ...years.map((y) => ({ path: PATHS.yearReadme(y), text: renderYearReadme(y, statList) })),
      { path: PATHS.board,     text: this._boardText(tasks, through) },
      { path: PATHS.boardMd,   text: renderBoardMd(tasks) },
      { path: PATHS.changelog, text: renderChangelogIndex(statList) },
      { path: PATHS.logReadme, text: renderLogReadme() },
      { path: PATHS.manifest,  text: this._manifestText(stats) },
    ];

    // Only ever delete a flat file whose events this same commit writes elsewhere.
    const deletions = planned.groups.filter(group => group.deleteLegacy).map(group => PATHS.legacyMonth(group.month));

    const s = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;
    const message = `worklog: upgrade data layout to schema ${SCHEMA}

Months move into per-year directories with a rendered page beside each one, so this
repo reads as markdown on GitHub with nothing installed and no Action. CHANGELOG.md
becomes an index, and data/board.json remains a display cache. Authoritative
replay uses verified source bodies rather than trusting snapshot coverage.

${s(months.length, 'month')} rewritten, ${s(deletions.length, 'old file')} removed, ${s(merged.length, 'event')} preserved unchanged.

Co-Authored-By: Claude <noreply@anthropic.com>
`;

    return this._sealPlan({ files, deletions, message, months, count: merged.length });
  }

  /**
   * Perform the upgrade. Call only after the user has seen migrationCommit().
   * No event is altered, so this is safe to retry and safe to skip.
   */
  async migrate(approvedPlan) {
    const plan = this._approvedPlan(approvedPlan);
    return this._executeApproved(plan);
  }

  previewCommit() {
    if (!this.hasPending) return null;

    const planned = this._monthPlan(false);
    const merged = planned.events;
    const through = merged[merged.length - 1] || null;
    const { tasks } = replayEvents(merged);

    const written = planned.groups.filter(group => group.write);
    const eventsIn = new Map(written.map(group => [group.month, group.events]));
    const touched = written.map(group => group.month);

    // Month stats, refreshed for what we touched and carried over for what we did not.
    const stats = new Map([...this.monthStats].map(([m, s]) => [m, { ...s }]));
    for (const group of written) {
      const m = group.month;
      stats.set(m, {
        ...stats.get(m),
        month: m,
        events: group.count,
        days: group.days,
        updated: new Date().toISOString(),
      });
    }
    const statList = [...stats.values()].sort((a, b) => a.month.localeCompare(b.month));
    const touchedYears = [...new Set(touched.map(yearOf))];

    const files = [
      ...touched.flatMap((m) => [
        { path: PATHS.month(m),   text: this._monthText(m, eventsIn.get(m)) },
        { path: PATHS.monthMd(m), text: renderMonthMd(m, eventsIn.get(m), tasks) },
      ]),
      ...touchedYears.map((y) => ({ path: PATHS.yearReadme(y), text: renderYearReadme(y, statList) })),
      { path: PATHS.board,     text: this._boardText(tasks, through) },
      { path: PATHS.boardMd,   text: renderBoardMd(tasks) },
      { path: PATHS.changelog, text: renderChangelogIndex(statList) },
      { path: PATHS.logReadme, text: renderLogReadme() },
      { path: PATHS.manifest,  text: this._manifestText(stats) },
    ];

    return this._sealPlan({
      files,
      message: buildCommitMessage(this.pending, tasks),
      changes: this.pending.map((e) => describeEvent(e, tasks)),
      count: this.pending.length,
    });
  }

  /**
   * Publish staged events as a single commit. Call only after the user confirms.
   *
   * A conflict reloads authoritative sources while retaining pending work. The
   * caller must present a new exact preview before another publication attempt.
   */
  async preparePublish() {
    if (!this.loaded) await this.load();
    // The pinned source index determines existing physical history. A brand new
    // pending destination has no file to read and is created by the checked plan.
    await this.loadAll();
    return this.previewCommit();
  }

  async push(approvedPlan) {
    return this._executeApproved(this._approvedPlan(approvedPlan));
  }

  async _executeApproved(plan) {
    let result;
    try {
      result = await this.repo.commitFiles(plan.files, plan.message, { deletions: plan.deletions, expectedBase: plan.base });
    } catch (error) {
      if (error instanceof ConflictError) await this.load();
      throw error;
    }
    this.remoteEvents = mergeEvents(this.remoteEvents, plan.pending);
    const remaining = core.acknowledge(listToBend(this.pending, event => encodeEvent(event)), listToBend(plan.pending, event => encodeEvent(event)), true);
    this.pending = listFromBend(remaining, event => parseJSON(event.canonical));
    let warning = null;
    try { this._savePending(); } catch (error) { warning = error.message; }
    try { await this.load(); } catch (error) { warning = 'Published successfully, but refresh failed: ' + error.message; }
    return { ...result, count: plan.count, warning };
  }
}

