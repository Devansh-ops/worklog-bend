# Pending changes across browser tabs

Pending events remain scoped to the exact configured repository and branch.
The familiar `worklog.pending.<owner>/<repo>#<branch>` array is retained for
compatibility and inspection, but it is now a snapshot cache. A stale tab may
overwrite that snapshot without destroying another tab's durable operations.

Every changed pending collection first appends a uniquely named operation under
`worklog.pending-journal.v1.<encoded-repository>#<encoded-branch>#<nonce>`.
The nonce uses `crypto.randomUUID`, or 128 random bits where UUID support is
unavailable. Existing keys are checked and never deliberately overwritten.
The operation contains a version, exact scope, full observed pending events as
additions and full removed events. Equivalent repeated additions deduplicate.
Keeping the complete observed draft also promotes older array-only drafts into
recovery evidence on the next edit. Only after that append succeeds does the store
reconcile the persisted snapshot and journal and write a compatibility snapshot.
Changed raw snapshots are detected; normal peer changes are reconciled and
reported through the existing storage warning.

On restore, every snapshot and journal value passes the strict JSON parser,
array checks and domain event codec. The existing compiled Bend merge combines
complete additions, including retained unknown envelopes. Compiled exact
acknowledgement subtracts removed values. Changed collections and exact removal
deltas use that acknowledgement function, rather than JavaScript equality.
Malformed data or conflicting same-ID contents enter read-only recovery mode;
their original raw values are not overwritten.

Removal records describe only exact immutable events observed by the originating
tab. Discarding the displayed draft cannot discard an unseen peer event.
Successful publication removes only its exact approved pending events, so work
staged elsewhere during the request survives. Historical additions do not
resurrect an event after it has been discarded or acknowledged. Event IDs are
immutable identities. The store checks journal retirement IDs before accepting
staged commands or branchless legacy recovery and rejects reuse explicitly.
Newly created commands receive new IDs as usual. A retirement racing the initial
check produces a read-only recovery failure instead of silently reporting a
command accepted and dropping it from the restored draft.

The journal carries candidate local edits, not evidence of authoritative remote
history, repository coverage, publication approval or successful delivery.
Normal complete replay, schema, command, privacy and publication gates remain
required. Existing branchless pending data still requires explicit recovery
into the chosen branch and its original is retained.

This is synchronous durability, not an atomic compare-and-swap implementation
or a claim of immediate cross-tab UI synchronization. Independent random-key
appends survive racing snapshot writes; another tab's edits become visible when
the store next reconciles or reloads. Neither network publication nor storage
effects become automatically authorized by that reconciliation.

If the operation append fails, the new edits remain in the current tab's memory
and the previous persisted data remains available. Keep that tab open. If the
snapshot write fails after the append, the accepted operation is already in the
recovery journal and can be restored by a fresh tab. A malformed snapshot after
a new append retains both its original raw data and the newly appended operation,
and disables further editing and publication. Malformed journal entries prevent
checking retired IDs, so new commands are refused before changing the current
draft; existing drafts survive.
Export and inspect the affected browser storage before repairing malformed or
conflicting entries; this change does not silently repair or delete them.

Journals are append-only in this version, including after discard/publication.
They retain old event content and consume browser storage over time. There is
no automatic compaction, deletion, encryption or cross-device synchronization.
An explicit browser-site-data deletion removes this local recovery evidence;
Git contains only events that were separately approved and published.

Synthetic integration tests cover two stale stores, a deliberately interleaved
stale snapshot overwrite, observed-only discard, peer edits during approved
publication, reload/new-edit nonresurrection, repository/branch separation,
malformed snapshots/journals, conflicting event identities, and quota failure
on either the journal append or the following snapshot write. These adapter
checks supplement the Bend domain laws; they are not universal storage proofs.
