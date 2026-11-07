# Bend domain core interface

Initial implementation checked and executed on 2026-11-08 using pinned Bend 2.0.40. This document describes the implementation boundary, the generated-value interface. Important pure-domain laws have separate kernel-checked statements and scope review in LAW_REVIEW.md; this is not a claim that every possible relation is proved.

## Build and runtime

`bend/Core.bend` imports `bend/Types.bend`. Use the pinned Linux/WSL compiler route in the toolchain documentation because the exact pin's native Windows multi-file resolver mishandles drive paths. The emitted `js/generated/core.mjs` is a static browser ES module with a default export object; no compiler is needed to run that asset. Build it from the repository root with the pinned wrapper:

```sh
sh scripts/bend-linux.sh bend/Core.bend -o js/generated/core.mjs
node test/bend-core.mjs
```

During the independent worktree implementation, the wrapper and compiler cache were provided by the sibling toolchain worktree; integration must rerun the build and tests with its installed pin. The initial emitted artifact ran under Node 25.8.1. The 20 runtime checks include 80 generated independent merge examples and a 1,200-event duplicate-history case. These checks are finite runtime evidence, not universal proofs.

## Values

All data constructors use the actual generated object ABI with a `$` tag and named fields. Strings inside records are native strings. Booleans are JavaScript booleans. A list is `{$:'Nil'}` or `{$:'Con',head,tail}`. A maybe value is `{$:'None'}` or `{$:'Some',value}`. Copy/validate all untrusted host data before calling these exports; the emitted functions do not enforce host object types.

`Status` constructors are `SBacklog`, `STodo`, `SProgress`, `SBlocked`, `SReview`, and `SDone`. Priority constructors are `PLow`, `PNormal`, `PHigh`, `PUrgent`. Every constructor is in `bend/Types.bend`; its named fields are the bridge contract. Lists and maybes have explicit `&2` quantities so domain values are safely copyable in checked Bend.

An event is `Ev{id,ts,day,payload,canonical}`. The host validates its original JSON, rejects duplicate keys/nonfinite or inexact host numbers, normalizes instants to fixed-width UTC ISO strings, supplies valid calendar dates, and decodes the typed payload. `canonical` is the canonical complete normalized source envelope, including retained unknown fields. Object-key order is irrelevant; array order remains meaningful. `event_eq` additionally compares every typed field and payload, so forged host values sharing one canonical string but differing typed bodies are still detected as conflicts. The host must still ensure those two representations agree before use. Unicode comparisons use scalar order, not locale collation.

Summary payload `body` is its preserved canonical JSON representation. Standup payload text is the exact copied report string. Opaque event kinds retain their full source envelope in `canonical`; replay emits an explicit unsupported diagnostic and marks state incomplete. No destructive plan may use incomplete semantics.

## Public operations

| Export | Contract |
| --- | --- |
| `merge(left,right)` | Returns `Merged{events}` or `EventConflict{id}`. Sorts by ID to validate/deduplicate complete equal events, then sorts by normalized `(ts,id)`. Same-ID different content is always an error. |
| `replay(events)` | Canonicalizes and folds authoritative history, returning `Replayed{state}` or `ReplayConflict{id}`. The state keeps all tasks including deletion/private tombstones, per-event notes, latest summaries/reports by date/kind, and diagnostics. |
| `reconcile(covered,incoming)` | Reconciles the complete authoritative covered source events with incoming events and fully replays. It never treats a timestamp watermark or an untrusted snapshot as coverage. |
| `stage(events,event)` | Returns `StageAccepted{event}` or `StageRejected{reason}` for a new manual command. Rejects duplicate event IDs, incomplete state, missing/deleted targets, opaque operations, and invalid bounded new text. |
| `proposal_stage(events,event)` | Applies the same command checks and requires existing model-operation targets to be currently public/live and known. New create proposals are allowed for separate user selection/approval. |
| `context(state,sendNotes)` | Returns only public/live `ContextTask` records, or an empty list when state is incomplete. With notes off, the `notes` field is structurally empty. |
| `context_events(state,events,sendNotes,startDay,endDay)` | Returns only typed `ContextEvent` records for current eligible tasks within the inclusive supplied calendar interval. Notes-off excludes note events entirely. Summary, report, deletion, opaque data, canonical envelopes, and unknown extensions are absent structurally. |
| `eligible_target(state,id)` | True only for a known public/live target in complete authoritative state. |
| `schema_allowed(version)` | Accepts exactly 1 and 2. The host must first validate the schema integer before converting to U32, so wrapping cannot turn a future schema into an accepted one. |
| `acknowledge(pending,committed,success)` | Failure returns all pending events. Success removes only events exactly equal to the approved committed events. New or changed pending content remains. |

`completion`, `eligible`, `chosen_notes`, `project`, `context_notes`, and equality helpers are exposed for the independently reviewed universal laws. Internal helpers are generated exports but are not an adapter API; callers should use the public operations above.

## Commands, recovery, and remaining gates

All three completion paths (created-done, status change, status edit) use the event instant. Reopening clears completion; unrelated title/tag/privacy edits preserve it. Canonical replay makes `updated` nondecreasing. Two note IDs retain two notes even with the same timestamp/text. Deletes preserve tombstones. Later ordinary commands cannot resurrect a deleted ID. Unsupported, after-delete, duplicate-create, and missing-reference history produce explicit diagnostics instead of silently claiming a complete projection. An authoritative earlier create can repair a missing-reference diagnosis on a subsequent full replay.

New titles are nonblank and at most 200 Unicode scalar values; notes/reports are nonblank and at most 20,000; tags are at most 50 items, each nonblank and at most 64 scalars. Legacy history is not truncated or rejected merely for exceeding those new-command limits. Status/priority validity is represented by typed enums. The host separately validates timestamp/date syntax, IDs, full JSON compatibility, supported schemas, and source envelopes. These checks must run on every source and conflict reload before staging or publication.

The first implementation deliberately provides authoritative full replay, not an unproved bounded snapshot shortcut. Verified raw-source caching supplies bounded unchanged/changed network reads while retaining complete canonical replay. Universal canonical merge algebra and important recovery/record/privacy laws are checked; LAW_REVIEW.md distinguishes conditional coverage, helper facts and witnesses. Incremental snapshot-tail replay is not implemented or claimed. Browser transport, storage, JSON, compiler output, and user-authored free text are outside the modeled proof guarantees.

## Deterministic reports and reminders

`bend/Reports.bend` imports the same checked core and emits `js/generated/reports.mjs`. It keeps report selection and reminder decisions in Bend while the browser renders strings and uses clipboard/timers. Compile with the pinned Linux wrapper and execute `node test/bend-reports.mjs` independently.

`report_items(state, events, sendNotes, day, morning, includePlan)` returns report items containing `taskId`, normalized `task` title, first-tag `project` (or `Misc`), `didToday` note fragments, and `firstTs`. Evening selects at most one item for each currently public/live task touched by create/status/note on the supplied local day. Edits alone do not invent work items. Canonical event reconciliation de-duplicates delivery and orders notes. Morning lists only in-progress/blocked work when includePlan is true. Incomplete semantic state or input event collisions return no items. Output ordering uses first activity instant and an ordinal task-ID tie-breaker.

Whitespace shaping matches ECMAScript whitespace, including Unicode spaces. Notes flatten to one line; one trailing period is removed while ellipses remain. The display uses joined note fragments or falls back to the task title. With `sendNotes=false`, a note-only touched task still receives a title-based item, but its automatic note fragments are absent.

`model_report` accepts the same parameters and returns `ModelItem{task,project,didToday}`. Internal IDs and timestamps are structurally absent. This does not promise to remove similar-looking identifiers that users explicitly typed into their own titles/notes. User-edited free report text requires its separate verbatim disclosure.

`reminder_decision(enabled, alreadyFired, nowMinutes, targetMinutes, hasPending, hasEveningSummary, hasSignOff)` returns `ReminderOff{}` or `ReminderDue{pending,missingSummary,missingSignOff}`. The host supplies validated local minutes and whether the reminder fired on the supplied current local day. The function rejects minute values outside 0..1439, waits until the target minute, suppresses already-fired/disabled/complete-day cases, and otherwise reports exact missing-work flags. The host handles calendar conversion, HH:MM parsing, timer scheduling, and recording acknowledgement. Runtime tests exercise the independent Boolean/minute decision table; universal laws remain separately reviewed.

## Owner board, search, and wiki projections

`bend/Views.bend` emits `js/generated/views.mjs`. It selects and sorts visible domain values while JavaScript creates DOM nodes, localizes dates, and renders safe text. Private tasks remain visible to their owner; this view API is deliberately separate from AI/team-context eligibility. Deleted task tombstones are absent from live indexes but remain addressable with `wiki_task` for their historical record.

Board sorting uses urgent/high/normal/low priority, then most-recent normalized updated instant, then Unicode scalar task-ID order. Wiki task indexes use recency then ID. The final ID tie-breaker fixes unstable equal-time reference sorting and avoids locale-dependent ordering. `board_tasks`, `wiki_tasks`, `status_tasks`, `wiki_status_tasks`, `for_status`, `sort_board`, and `sort_wiki` expose these selections. `status_counts` and `status_counts_tasks` return all six `StatusCount{status,count}` records, including zero-count columns.

Search has one explicit host normalization boundary. `search_text(task)` in Bend selects and joins only task ID, title, ordered tags, and note text. The adapter applies ECMAScript default Unicode `toLowerCase` to that exact string and supplies `SearchKey{taskId,foldedText}` records. It trims and lowercases the query with the same host rules. `search_tasks(state,keys,query)` and `wiki_search_tasks` own matching, live-task filtering, and deterministic output sorting. This preserves expanding Unicode lowercase mappings and contextual case behavior; the pin's Base lowercase only handles ASCII and would regress the existing UI. The adapter rejects duplicate key IDs and validates that keys came from the same immutable state revision. Nonempty searches without a task's normalized key do not match it. Empty queries show live tasks. This is substring search, with exact internal whitespace and no implicit Unicode normalization or locale-specific casefold promise.

`tag_index` and `tag_counts` return `TagCount{tag,count}` records ordered by descending number of tasks, then scalar tag order. A task with a duplicate tag counts once for that topic, correcting the reference index's duplicate counting. Tags remain case-sensitive exact strings in indexes and related-task matching. `tag_tasks` and `related_tasks` use the same owner-visible live task set. `wiki_task(state,id)` returns a maybe task including a tombstone; `task_history(events,id)` returns complete canonical task-linked history, including deletion and private records, for the owner's wiki.

`day_events(events,day)` and `day_index(events)` use supplied local calendar dates already validated by the adapter, never infer a day from UTC text. The index is newest-day-first and returns `DayCount{day,count}`. Duplicate event delivery is de-duplicated before counting; same-ID conflicting content yields no misleading partial journal. `day_summaries` and `day_reports` return retained latest records for the requested day, consistently morning before evening.

Counts are modeled as Nat rather than wrapping U32 counters. The generated ABI uses JavaScript numbers for nested Nat fields and raises an error beyond its checked immediate capacity rather than silently wrapping. The adapter retains practical collection bounds and displays failures honestly. Thirteen independent generated-runtime checks cover sorting, all six counters, private owner visibility, Unicode search, missing keys, duplicate tags, related tasks, canonical history/date selection, record persistence, and input ownership. These examples are finite runtime evidence; no universal view-sorting/search theorem is claimed here.
