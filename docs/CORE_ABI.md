# Bend domain core interface

Initial implementation checked and executed on 2026-11-08 using pinned Bend 2.0.40. This document describes the implementation boundary, not completion of Phase 3 or a claim that every candidate law is proved. The independent root laws/proofs remain separate review work.

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

The first implementation deliberately provides authoritative full replay, not an unproved bounded snapshot shortcut. A trusted incremental coverage cache and lazy note history still require explicit schema/compatibility work and tests. The implementation does not yet establish the complete universal sorted-merge algebra, checkpoint refinement, or all report/rendering/reminder laws. All such gaps must remain visible in STATUS and the phase gate. Browser transport, storage, JSON, compiler output, and user-authored free text are outside the modeled proof guarantees.
