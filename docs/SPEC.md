# Worklog Bend specification

Status: proposed implementation contract. Every Bend implementation and proof is
pending. This document describes the full rebuild, not a completed port.

The reference is Worklog at upstream commit
`53bff74016df38a9c88f6cf94c7b556225dd79fb`. The README describes product intent;
the JavaScript and tests supply examples and compatibility fixtures. Where source
behavior contradicts a stated requirement, preserve the requirement and add a
regression test. The observations below come from reading code, not reproducing
failures with a running application.

## Product and runtime contract

Recreate the complete personal work board and readable Git ledger. The user owns
a separate data repository, stages work in the browser, and explicitly approves
each publish. AI remains optional and starts off. A static deployment must work
under a repository subpath, without a backend or database.

Use Bend2 for domain types, validated commands, deterministic state transitions,
event reconciliation, data projections, privacy projections, report logic, and
publish planning. Use JavaScript, HTML, and CSS for browser capabilities and
presentation. A build step for Bend-generated assets is acceptable; the deployed
application must remain static. Do not require a compiler download in the user's
browser or claim that the existing JavaScript application is already a Bend port.

## Feature inventory and acceptance behavior

| ID | Feature | Required behavior and reference |
| --- | --- | --- |
| F01 | Setup and connection | Welcome flow, owner/repo/branch validation, reconnect, repository visibility, readable errors, public read access without a token, private access with a token, and locked-token read-only skip. Distinguish missing, empty, unseeded, and ready repositories. See `js/bootstrap.js`, `js/github.js`, `js/ui/setup.js`. |
| F02 | Data repository creation | Default to private, offer public explicitly, preview starter files, optionally include three example tasks, handle initial commits and existing unseeded branches. Never overwrite an unrelated existing repository without a concrete review step. Generate the app's actual URL in the data README. |
| F03 | Board | Six columns: `backlog`, `todo`, `in_progress`, `blocked`, `review`, `done`. Create, open, edit, drag to move, delete with confirmation, and reopen completed work. Keyboard users must also be able to change status in the task dialog. |
| F04 | Task details | Title, priority (`low`, `normal`, `high`, `urgent`), ordered tags, private flag, created/updated/completed instants, notes and note history. Preserve task IDs. Search IDs, titles, tags, and notes; retain counts, priority then recency ordering, age indicators, and reveal/highlight from references. See `js/ui/board.js`. |
| F05 | Local staging | Every accepted edit becomes an event and updates the board immediately. Show unpublished count and a readable list. Persist per repository and branch, restore after reload, confirm discarding, and warn before leaving with pending work. Report storage failures and keep recoverable state. Staging performs no HTTP requests. |
| F06 | Publish | Load required history before preparing the preview; show actual message, changed paths, and deletions. Commit all approved files atomically. Preserve pending work on network, authentication, validation, and conflict errors. Clear only events acknowledged by the successful commit, including when new edits arrive during an in-flight publish. |
| F07 | Concurrent edits | Reconcile by event ID and deterministic `(ts, id)` order. Retry a bounded number of Git ref conflicts. Preserve both peers' events and unrelated repository files. Detect conflicting content for one event ID rather than silently selecting one. A materially changed plan requires another preview. |
| F08 | Ledger and readable files | Preserve month JSON, one event per line; board JSON, one task per line; rendered month Markdown; board Markdown; year indexes; log README; root CHANGELOG index; manifest counts. Generated links must work in GitHub repository browsing. See data layout below. |
| F09 | Long history | Boot from validated snapshot plus recent months, normally three, rather than all years. Load a year or all history on demand. Keep all task records; completed-task note trimming after 90 days must leave an accurate count and a way to recover notes. Cap the rendered board's done list at 15 with a history link. |
| F10 | Compatibility and migration | Load legacy schema 1 flat month paths and schema 2 year paths. Offer the one-commit layout upgrade with preview, event preservation, and deletion only of files whose contents are safely relocated. Refuse unsupported future schemas before staging changes intended for publish or generating any destructive write. |
| F11 | Wiki | Task index by status, tag index and pages, dated journal index/pages, task metadata and history, related tasks by tag, notes, summaries, and recorded reports. Link bare `T-xxxxxx` and `[[T-xxxxxx]]` references safely. Indicate unloaded history and trimmed notes. See `js/ui/wiki.js`. |
| F12 | Brain dump | Accept user text, disclose its transmission, interpret with the selected provider, validate proposals, and show one checkbox per create/status/note/edit proposal with rationale. Proposals start selected; applying them is a separate user action and stages events only. Discarding proposals changes no domain state. See `js/ui/braindump.js`, `js/ai.js`. |
| F13 | Executive summary | Morning summarizes the previous seven local calendar days and current standing state; evening summarizes today's local activity. Structured headline, task-linked bullets, risks, and next actions, with bounded lengths/counts. Record `summary.set`, retain history, signal staleness, confirm regeneration, and use earlier summaries only when permitted by privacy rules. |
| F14 | Standup | Work with AI off. Morning greeting plus optional in-flight/blocked plan; evening one item per task touched by create/status/note that day. Prefer that day's notes, fall back to title. Group by first tag or flat list; order groups deterministically. Support plain/Markdown format, editable preamble, own note, manual edits, rebuild/update awareness, and optional AI write-up that preserves edits. Never expose internal IDs in generated team-facing text. |
| F15 | Report recording | Successful clipboard copy records the exact copied text as `standup.set`; clipboard failure records nothing. Preserve latest report by `(date, kind)` after publish/reload, recent history, and reminder acknowledgement. The record proves copying, not delivery to a team channel. See `js/ui/standup.js`, `js/standup.js`. |
| F16 | AI providers | No AI; browser WebGPU/WebLLM; Ollama, llama.cpp, and LM Studio; Hugging Face; OpenAI, Anthropic, Google, OpenRouter; custom OpenAI-compatible endpoint. Keep model selection/discovery, provider-specific keys, endpoint override, progress, errors, and model load/unload controls. Verify current external API behavior during implementation. |
| F17 | AI transport | Support structured `json_schema`, then `json_object`, then plain prompting when an endpoint rejects a format. Drop only identified unsupported sampling parameters, handle token-limit parameter variants, bound retries, validate model output, and distinguish authentication, quota, rate-limit, CORS/network, malformed output, and service failures. Never use a model result as trusted commands. |
| F18 | AI privacy and consent | Filter private/deleted tasks and their task-linked history, withhold note-derived content when notes are disabled, and default to no AI. Disclose the actual endpoint, model, selected context, and user-authored free text before first cloud use. Remember consent per normalized destination and provider, re-ask on changes, allow forgetting consent, and show where requests go. See privacy contract below. |
| F19 | Credentials | Retain optional passphrase lock, default enabled, with per-load unlock, read-only skip, passphrase feedback, per-provider token storage, and forget action. Use WebCrypto PBKDF2-SHA256/AES-GCM with stored KDF parameters, random salt and IV; preserve compatible existing records. Tokens and passphrases must stay out of events, generated files, logs, URLs, and prompts. See `js/vault.js`. |
| F20 | Reminder | Default 17:30 local, configurable or off. At or after the configured time, once per local day, mention pending work, missing evening summary, and missing evening sign-off for people who use reports. Support disabling from the reminder. No reminder when there is nothing missing. Inject the clock in domain logic. |
| F21 | Shell and layout | Board, brain dump, summary, standup, wiki as simultaneous panes; shareable `?panes=...`; saved valid layout; responsive capacity and focus preservation; global search; theme auto/light/dark; header status, loading/error states, and settings. Remain usable around 400px with horizontally scrolling columns. See `js/app.js`, `index.html`, `css/`. |
| F22 | Demo | `?demo=1` with synthetic history, no token prompt, no persistent demo edits, and no publish to a real repository. Include deterministic keyword interpreter for brain dump and summaries. Keep deliberate use of an already configured provider behind the same consent and privacy rules; never send demo or user data automatically. |
| F23 | Local CLI and setup tooling | Preserve static serving, browser opening, demo flag, port/host selection, no-open/help/version behavior, path confinement, GET/HEAD handling, port conflicts, and clean shutdown. Keep setup/scaffold workflows and self-hosted relative paths working with the generated Bend assets. See `bin/worklog.mjs`, `scripts/`. |
| F24 | Accessibility and safe rendering | Named controls, focus management, usable dialogs, keyboard task actions, readable mobile panes, safe text insertion, safe link handling, and copy failure recovery. Malicious task/model text must render as text rather than executable HTML. |

## Data and state contract

The existing event families are `task.create`, `task.status`, `task.note`,
`task.edit`, `task.delete`, `summary.set`, and `standup.set`. UTC instants order
events; local dates determine human day views and month filing. The environment
supplies a clock and explicit calendar context. A seven-day window means calendar
days, including daylight-saving changes, rather than seven fixed 24-hour periods.

Validate timestamps, IDs, enums, dates, task references, bounded text, and
container shapes at input boundaries. New commands must never produce invalid
events. Historical unknown task references must remain recoverable until missing
history arrives; show diagnostics rather than discarding the underlying record.
Specify legacy defaults explicitly. Setting status through any supported command
must update completion metadata consistently. Unknown event types and fields in a
supported schema must survive round trips; unsupported semantics must prevent a
destructive publish rather than disappear during projection.

| Path | Role |
| --- | --- |
| `data/manifest.json` | Schema, months, and per-month statistics. |
| `data/board.json` | Validated snapshot and checkpoint metadata, including note availability. |
| `data/BOARD.md` | Readable current board. |
| `data/log/YYYY/MM.json` | Canonically ordered events for the local month. |
| `data/log/YYYY/MM.md` | Same month's readable events, summaries, and reports. |
| `data/log/YYYY/README.md` | Year index. |
| `data/log/README.md` | Ledger guide and index. |
| `CHANGELOG.md` | Small index linking years and months. |
| `data/log/YYYY-MM.json` | Legacy read path until an approved migration removes it. |

The exact same event ID with identical content denotes one event. The same ID
with different content is a conflict. Sorting and set union are deterministic
only under this consistency rule. Fold equality is about the canonical event
set, not arbitrary application order of status changes.

A checkpoint is valid only for events it actually covers. A previously unseen,
older timestamp must not disappear merely because it sorts before `through`.
Choose and document a sound coverage/reconciliation strategy before implementing
checkpoint laws. Preserve summaries, reports, deletion/privacy metadata, and
recoverable notes across snapshot reloads. Recovery must not rewind task status,
duplicate notes, resurrect deletion, or lower updated timestamps.

Month relocation must load and reconcile all affected source and destination
files, including historical UTC/local month boundary cases. A timezone change
must not lose or duplicate events. Calendar policy and any persisted metadata
change require an explicit compatibility decision, not an implicit schema bump.

## Privacy contract and reference defects

For generated model context, use an allowlist of task IDs eligible for this
request, not only a blocklist of currently visible private tasks. Apply it to
board fields, task-linked historical events, summary references, operation
targets, and any retained derived context. A private task that was deleted or
removed from the live board must remain excluded. Preserve enough privacy
provenance or withhold context whose eligibility cannot be established.

User-authored free text is different: a brain dump, manual report draft, or an
edited report may mention anything. The application cannot reliably infer which
task it describes. Show that text verbatim in the disclosure. Do not describe it
as filtered. Stored report text and old generated headlines must not be silently
reused as summary context through an unfiltered secondary path. If their
provenance does not satisfy the current private-task and notes policy, withhold
them by default or provide a separate explicit disclosure choice.

`sendNotes=false` withholds automatic note-derived context across every request
path, including historical notes and derived summaries. It does not promise to
remove similar words that the user typed into an explicitly disclosed free-text
field. Display consent from the same immutable request object that the transport
will send. Retries may change supported transport options, not broaden context.
Classify locality from the resolved destination; a remote override of a preset
named Ollama must not inherit a local-only privacy claim.

Code-review observations to reproduce with synthetic regression fixtures:

| Observation | Source and required refinement |
| --- | --- |
| Summary filtering considers only private IDs in the supplied task list. Deleted tasks are absent from `app.tasks`, so task-linked older events can evade that blocklist. | `js/app.js`, `js/ai.js:summarise`. Project eligible IDs consistently from validated state and privacy metadata. |
| The summary window excludes `summary.set` but admits `standup.set` free text; `previous.headline` is inserted separately. Consent counts board notes, not all of this context. | `js/ai.js:summaryWindow`, `summarise`; `js/ui/summary.js`; `js/ui/consent.js`. Build one policy-checked request and disclose its real contents. Distinguish task-linked data from free text. |
| Output sanitizers consider all known task IDs, rather than only the request's eligible targets. | `js/ai.js:sanitiseOperations`, `clampSummary`. Reject invented, stale, private, or deleted targets and revalidate selected proposals against current state. |
| Locality is inherited from a provider preset despite URL override. | `js/providers.js:resolveEndpoint`, `js/ui/consent.js:isCloud`. Determine trust and consent for the actual destination. |
| Future manifest schemas and snapshot schemas are not rejected; writers emit schema 2. | `js/store.js:load`, `renderManifest`, `renderBoardSnapshot`. Validate all relevant versions before any write plan, including migration and retry paths. |
| Reports at/before the checkpoint are not replayed, although summaries and notes are. | `js/store.js:state`. Restore `standup.set` state so published reports and reminder acknowledgement persist. |
| Event union silently keeps the first content for a repeated ID, and a timestamp checkpoint alone cannot establish complete coverage of late events. | `js/store.js:unionEvents`, `afterThrough`. Add explicit collision and coverage rules before claiming merge/checkpoint laws. |

These are planned corrections, not reproduced test results or completed fixes.

## Candidate laws and their limits

These are natural-language candidates for `LAWS.bend`, not checked Bend syntax or
proofs. Phase 1 must confirm what the pinned compiler accepts. State law
preconditions as types or explicit hypotheses; include witnesses and negative
fixtures so a law cannot pass because valid states are impossible to construct.

| Law candidate | Preconditions and intended claim |
| --- | --- |
| Canonical merge | For validated event collections with consistent ID/content mapping, merge is associative, commutative, and idempotent; output has unique IDs, canonical order, and exactly the input ID set. Conflicting content returns an explicit error. |
| Replay determinism | Equal canonical event sets and equal initial state produce equal task, summary, and report projections. Accepted commands preserve task/status/priority/date invariants. |
| Checkpoint refinement | For a valid coverage witness, snapshot plus uncovered events refines full replay. State exactly which notes are trimmed, how they recover, and which history is required. Include late/backdated events as a counterexample to an insufficient witness. |
| Recovery preservation | Loading older covered notes/summaries/reports is idempotent and does not rewind status or timestamps, resurrect deleted tasks, or erase existing records. |
| Privacy projection | Every task-linked output refers only to the eligible allowlist; notes-disabled projections contain no fields derived from note text. Changing excluded task content cannot change structured context. Model user-authored free text as an explicit separate input. |
| Proposal validity | Sanitized proposals use allowed operations/enums/targets; applying no selected proposals changes no state; only selected, revalidated proposals can become events. |
| Calendar/window bounds | With a supplied valid calendar mapping, evening events are on the requested day and morning events are within the preceding seven days, excluding today. Host timezone conversion requires separate tests. |
| Standup structure | At most one mechanical item per eligible touched task; task IDs absent from the generated team projection; grouping preserves all items; formatting cannot create work items. User edits remain explicit data. |
| Publish/migration preservation | A valid plan retains every source event, emits consistent counts/links, and deletes only relocated legacy files. Plans for unsupported schema versions contain no writes. Failed effects do not acknowledge pending events. |
| Round-trip refinement | Parse/render preserves supported event semantics, IDs, unknown retained data, and deterministic ordering. Prove the modeled codec properties, then test actual JSON/UTF-8 adapter behavior. |
| Reminder decision | Disabled, before-time, already-fired, and complete-day inputs are not due; otherwise the declared missing-work conditions determine one decision for the supplied day. |

Proofs establish only the modeled Bend semantics accepted by the pinned checker
and, where available, its verdict kernel. They do not establish correctness of
the compiler, emitted JavaScript, DOM, HTTP, GitHub, WebCrypto, WebGPU, provider
output, storage, or human-entered text. Boundary and browser tests are required.

## Completion criteria

Every feature F01 through F24 must have an implementation location, acceptance
test or justified manual check, and recorded outcome. Preserve MIT licensing and
upstream history. Do not mark the rebuild complete while a feature, required
proof, migration guard, privacy path, browser boundary, or deployment artifact is
still a stub. Record any compiler or external-service limitation explicitly and
keep the affected phase pending.
