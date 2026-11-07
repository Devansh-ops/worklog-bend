# Domain and law contract review

Reviewed 2026-11-07 against upstream `53bff74016df38a9c88f6cf94c7b556225dd79fb` and the preserved JavaScript source. This is preparatory requirements review. Phase 1 remains a prerequisite for accepted Bend contracts; nothing here is a compiler-checked law or completed runtime fix.

## Model boundary

The domain receives validated immutable values, explicit current instant, calendar mapping, generated IDs, repository read revision, and effect outcomes. It returns projections, accepted events, diagnostics, immutable AI requests, and immutable write plans. The host owns UTF-8/JSON, browser dates and timezones, storage, cryptography, HTTP, DOM, clipboard, and model execution. Host adapters must preserve the values and identities modeled by proofs and receive their own tests.

Event equality means structural equality of the complete validated JSON value, including retained unknown fields. Object-key order is irrelevant; array order is significant. Duplicate JSON object keys must be rejected before JSON parsing loses them. Missing legacy defaults normalize explicitly before semantic comparison, while the lossless envelope retains original data. Finite JSON numbers only; no host undefined, NaN, Infinity, functions, or prototype-dependent properties cross the bridge. The codec must test these assumptions rather than infer them from a proof about Bend values.

## Events, replay, and commands

`Event` contains an opaque nonempty bounded ID, normalized UTC instant, known event payload or retained opaque payload, and extension data. IDs are not constrained to a new generator's spelling because legacy data and synthetic upstream fixtures use varied formats. New task IDs retain `T-xxxxxx` compatibility, with collision rejection. Task statuses and priorities are exactly the six and four values in SPEC F03/F04. New input text and collection bounds must be constants shared by validators and projection codecs; finalize their compatibility treatment before implementation.

Commands validate the current state and supplied IDs before accepting any event. An AI proposal is never a command until selected and revalidated. Historical unknown task references remain in the event set with diagnostics; they must not disappear from serialization. A later load repairs their projection when the creation arrives. Missing-reference diagnostics differ from a new command targeting an unknown task, which is rejected.

`task.create(status=done)`, `task.status(to=done)`, and `task.edit(fields.status=done)` all set completion time to that event's instant. Reopening clears it. Title/priority/tags/privacy changes preserve it. Replaying an older recovered note cannot lower `updated`, alter status, undo deletion, or rewrite completion time. Distinct note event IDs remain distinct notes even if timestamp and text match. Recovery de-duplicates by event identity, not `(timestamp,text)`. The reference currently initializes a created-done task with `done=null` and does not update `done` for status edits (`js/store.js:foldEvents`); these are required corrections, not parity targets.

Deletion preserves a tombstone and its privacy provenance, while excluding the task from the live board and generated AI context. Normal create/edit/status commands cannot resurrect a deleted ID. There is no implicit undelete command. Unknown event semantics may invalidate a projection's completeness; preserve the opaque records and enter a diagnostic read-only state rather than producing a destructive write using incomplete semantics.

## Canonical event reconciliation

`merge(left,right)` returns either a conflict describing the repeated ID or the canonical unique event sequence sorted by normalized `(instant,id)` using a specified ordinal ID order. Different IDs with equal timestamps both survive. Identical complete content for a repeated ID denotes one event; different content is an error regardless of input order. Never select one side by list order, latest arrival, or lexicographic content.

`js/store.js:unionEvents` currently retains the first content it sees. The intended merge laws apply only to collision-free inputs and quantify over valid inhabited values. Failure laws additionally establish that an inconsistent ID mapping cannot return success. Deterministic replay means equal canonical input sets produce equal task, summary, and report projections, not that applying arbitrary status changes in arbitrary order commutes.

Witnesses in `test/fixtures/contracts/reconciliation.json` cover an inhabited valid set, equal-timestamp peers, duplicate delivery, an actual ID/content collision, a late event, and a covered report. Their expected outcomes are independent contract expectations, not results from executing the current implementation.

## Checkpoint coverage and recovery

A `(timestamp,id)` watermark is an ordering boundary, not a coverage witness. An unseen event can sort before it. Even replaying every event absent from a covered-ID set onto a snapshot is unsound: a late old status must be applied before a newer covered status. The correct final state requires canonical full replay or a sound equivalent reconstruction of the affected history.

Proposed compatibility decision for Phase 2:

1. Pin all repository reads to one immutable commit. Read manifest, snapshot, month blobs, and tree metadata at that revision so concurrent branch changes cannot mix versions.
2. Treat legacy snapshots lacking coverage metadata as display caches only. Before trusted domain edits, AI context, or publish, load the necessary authoritative history; a full-history fallback is acceptable and must be visible. An old snapshot cannot prove that a missing task was public, absent, or deleted.
3. Introduce checkpoint metadata only through an explicit previewed schema migration, with a version discriminator supported by both manifest and snapshot readers. Do not silently insert a new interpretation into schema 2. Keep legacy schema 1/2 readers.
4. A proposed checkpoint records the exact canonical source coverage in the proof model, complete state including deleted/privacy tombstones and latest reports/summaries, recoverable note identities/counts, and a binding to its covered source files at an immutable revision. A host representation may use per-source blob identifiers plus a canonical event commitment, but a hash is not itself a theorem of coverage or snapshot correctness.
5. For a cached checkpoint already verified by this client against its sources, unchanged covered blobs permit reuse. Changed/added sources require verification. Use an incremental tail only when every additional event sorts after the covered sequence and coverage/semantics are verified. A late event, collision, missing source, unsupported semantics, or unverified imported checkpoint triggers authoritative replay. Do not trust self-asserted snapshot metadata from an arbitrary repository without validation.
6. Record a server-side atomic manifest/snapshot/source relationship through one commit. Test both stale blobs and internally inconsistent imported checkpoints. A new client may need one full replay to establish trust; do not promise universal bounded boot without proving a sound alternative.

The bounded recent-month path is a performance goal conditional on verified coverage. Correctness takes precedence when that condition fails. Lazy recovery can independently load older notes without changing authoritative status, but only when each note's event identity and task binding are established. Report/summary recovery chooses the maximum `(instant,id)` for each `(local date,kind)`; records must survive snapshot reload and history trimming.

Reference evidence: `Store.state` replays all notes and summaries but excludes covered `standup.set`; `renderBoardSnapshot` drops deleted tasks and stores no report/summary map; `afterThrough` filters any older unknown status/create/delete. These paths cannot establish the stronger laws. A summary older than the normally loaded three months also lacks a persistence guarantee unless represented in a verified checkpoint.

## Privacy and immutable requests

Eligibility is a positive set of task IDs whose validated current authoritative state is known, public, live, and permitted by this request. Unknown, deleted, or private tasks do not enter it. Apply the same set to board fields, historical events, summary references, operation targets, and every automatically derived secondary path. Privacy provenance must survive deletion and snapshot trimming; absent metadata defaults to withholding context until authoritative history establishes eligibility.

When notes are disabled, no automatic note-derived strings enter any provider request, including old generated summaries, saved report text, retry prompts, or fallback messages. Stored free-form headlines/reports lack reliable provenance in legacy data and are withheld by default. They may be included only as separately disclosed verbatim user-selected text, never silently labeled filtered. User-authored brain dumps or manually edited reports are explicit free-text inputs; the policy cannot promise semantic redaction of those strings.

Build one immutable request value containing resolved provider and normalized actual URL, model, eligibility revision, context, included note policy, free-text inputs, and transport messages. The disclosure is a projection of this exact value; transport may not independently recompute context after approval. Revalidate eligibility before dispatch. A task becoming private/deleted while a dialog is open invalidates its request. A stale model response is revalidated against current eligibility and state before selected operations are staged.

Locality comes from the actual normalized destination, never a preset label. In-browser model execution is local. Explicit loopback destinations can be classified local after URL validation; remote overrides of Ollama/LM Studio/llama.cpp need remote consent. Destination normalization includes scheme, canonical host, effective port, and relevant API base path; do not strip path/query components that change recipient or accidentally disclose credential-bearing query parameters. Reject credentials in URLs. Cross-origin redirects require rejection or explicit redisclosure rather than silently broadening approval.

Remembered consent authorizes a normalized provider/destination policy, not arbitrary changed content invisibly. Every request still derives its displayed standing disclosure from its immutable request object, and explicit free text remains visible. Cancellation, AI-off mode, and demo rules must yield no provider request. Structured-output fallbacks may alter supported format options but cannot add context or broaden the eligible target set.

Reference evidence: `summarise` builds a blocklist only from supplied private tasks, `summaryWindow` includes `standup.set`, and `previous.headline` is appended separately. `disclosure` counts board notes only. `sanitiseOperations` and `clampSummary` recognize every supplied task ID, including private IDs. `isCloud` trusts endpoint.local. These are separate paths requiring canary transport tests; a pure projection proof cannot validate actual outgoing bytes.

## Schema and lossless migration

Supported input schemas are legacy 1 and 2 until a new schema is deliberately implemented. Missing schema has a narrowly documented legacy default; malformed schema values, nonintegers, and future versions return typed errors before any publish/migration plan. Existing month files have no schema field (`serialiseMonth`); interpret that shape only under a supported manifest and preserve additional envelope fields. An explicit future schema in any participating manifest, snapshot, or month is a refusal, including on conflict reload.

Retain unknown fields in supported events, tasks, manifest/month envelopes and snapshot metadata. Preserve opaque event types losslessly, mark semantics incomplete, and block writes whose safety depends on them. Do not overwrite schema N with schema 2, discard an unknown operation, or silently recompute counts from a partial history. A read-only error must preserve pending local data and source files.

Migration loads and validates every affected source and destination at the same base revision, reconciles collisions, and produces one atomic plan. If both legacy and current paths exist, reconcile both rather than preferring the current path and ignoring the legacy one. An event near a UTC/local month boundary may relocate; preserve event identity/content and clear stale copies only in that same plan. Delete only source files whose complete contents are represented at approved destinations. Unknown envelope fields require an explicit retention mapping before deletion is safe.

Calendar filing uses supplied local date mappings. Preserve original UTC instants. A timezone policy change cannot implicitly refold/rewrite unrelated history. Tests must include duplicate source paths, opposite-side month boundaries, unknown fields, future schemas, malformed JSON, and source/destination collisions.

## Exact publication approval and effects

A `WritePlan` is immutable and contains repository identity, normalized owner/name, branch, expected base commit and base tree, exact file paths/content, deletions, message, source coverage, and the exact acknowledged pending event IDs/content. Its identity covers every field. Domain plan generation performs no effects. The UI shows full content or a selectable exact diff, not only filenames/counts, and approves this plan identity.

Effects execute only the approved plan against its expected base. The adapter uses that base commit as parent and compares current branch state before creating writes; a revision mismatch returns conflict before mutation. Updating the ref with force=false protects a race after that comparison. Preserving unrelated files means extending the approved base tree, not fetching a newer tree and overwriting its month files with stale content.

Important reference race: `GithubRepo.commitFiles` fetches the latest branch ref as parent after the store prepared files. If a peer changed a month after the store read it but before that ref GET, the stale month payload can fast-forward on top of the peer without a 422 conflict. Binding the approved read revision prevents this loss. Refuse to treat a successful fast-forward alone as evidence of event preservation.

`Store.push` also rebuilds the preview after app approval, retries with a new plan without redisclosure, and clears all current pending events after await. Required behavior: retain the immutable approved plan; on base conflict reload/validate/reconcile sources, return a fresh preview for new approval when any bound field changes; acknowledge only the committed plan's event IDs with identical content. Newly staged events remain pending even if they arrive while effects run. Failure or cancellation acknowledges none. On ambiguous network failure after ref update, inspect the resulting commit for the exact plan before acknowledging or retrying.

The same approval rules apply to migration, repository bootstrap, and data repository setup. No automatic network write on staging, preview, model proposal generation, or clipboard copy. Clipboard success stages the exact copied `standup.set`; failure stages nothing. Copying a report is not delivery to a team channel.

Pending localStorage must be scoped by normalized repository identity and branch. The legacy unscoped key cannot be assigned to whichever branch happens to open first. Offer an explicit local recovery choice naming candidate destination/branch, preserve the old key until validated new storage succeeds, and de-duplicate by event identity. Storage quota/serialization failures retain recoverable in-memory state and report failure.

## Proof obligations and independent checks

| ID | Obligation and nonvacuous witness | Boundary checks outside proof |
| --- | --- | --- |
| L01 | Consistent merge has union membership, unique IDs, canonical order, associativity, commutativity, idempotence. Witness: two distinct equal-time creates plus duplicate delivery. | JSON equality, Unicode/order normalization, input ownership, ID generator collisions. |
| L02 | Inconsistent content for an existing ID returns conflict. Witness: same ID with different titles. | Unknown nested fields and malformed raw JSON. |
| L03 | Canonical replay is deterministic; accepted commands preserve enum/completion/deletion invariants. Witness: create, complete, reopen, note. | Generated JS constructors and mutable arrays. |
| L04 | Verified checkpoint refinement equals full replay under stated coverage and ordering premises. Witness: covered create/report then a later status; late older status must trigger fallback. | Commit-pinned reads, host blob/commit binding and untrusted metadata. |
| L05 | Covered-history recovery is idempotent and cannot rewind status/time, undo deletion, or lose latest report/summary. Witness: done task with old note and two report revisions. | Real storage/reload and lazy network reads. |
| L06 | Structured AI context contains only eligible IDs and approved field provenance; excluded task changes cannot affect it. Witness: one eligible task plus private-deleted history. | Intercept actual provider bytes, all fallback/redirect paths, explicit free text. |
| L07 | Notes-off omits automatic note-derived values; no selected proposals produces no events; every accepted target is currently eligible. Witness: eligible title with a secret note and stale target proposal. | UI selection, asynchronous eligibility changes, provider parsing. |
| L08 | Future/unsupported semantics produce no destructive plan; migration preserves full source event sets and deletes only completely relocated sources. Witness: valid schema 1 with a boundary-month event; future-schema refusal. | UTF-8 round-trip, JSON envelopes, source file reads, tree API. |
| L09 | Executable plans equal approved values; success acknowledges only planned events; failure acknowledges none. Witness: approved event A and event B staged during commit. | Git ref races, ambiguous failures, DOM approval dispatch. |
| L10 | Summary windows and reminder decisions follow explicit valid calendar inputs. Witness: seven-day morning range plus before-time/already-fired/complete-day cases. | DST/timezone conversion and once-per-load scheduling. |

Before accepting laws, construct each witness using the real compiler, check proofs and deliberately false/open fixtures, inspect quantifier preconditions for impossible valid states, and review laws independently from implementations. No proof may rely on foreign effects or unsafe axioms. A theorem about modeled event lists does not certify the compiler, emitted JavaScript, GitHub, browser APIs, or arbitrary user-authored text.
