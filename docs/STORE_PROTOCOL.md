# Authoritative replay and publication protocol

Implemented boundary checks and integration tests are recorded in Git history and `test/store-integration.mjs`. The accepted pure-domain and host-boundary scopes are recorded separately in LAW_REVIEW.md and STATUS.md.

The JavaScript store delegates canonical merge, replay, accepted commands, eligibility, supported-version decisions and exact pending-event acknowledgement to generated Bend. The host validates raw JSON, timestamps, calendars, file envelopes and compiler-value shapes. Duplicate object keys and inexact numeric values fail before conversion can discard information. Unknown event envelopes survive canonical reconciliation; unsupported semantics make the state incomplete and prevent editing, AI context and write plans.

All GitHub source reads are pinned to one immutable commit. Schema 1/2 snapshots have no trustworthy coverage witness, so they remain display caches. Current loading deliberately reads authoritative history and runs canonical replay rather than trusting a timestamp watermark. This fixes late-event loss and report/deletion provenance loss. A complete pinned Git tree and hash-verified raw-source cache provide bounded warm network reads. Cold loads verify full history; there is no incremental snapshot-tail claim. Snapshot output marks `cacheOnly` and retains deletion/private tombstones even when old note text is trimmed.

Manifest, board and every loaded month schema are checked independently. An unsupported future version produces no plan. Month paths and envelope months must agree. Both current and legacy month sources are reconciled; conflicting event content or incompatible retained metadata prevents migration. Month/manifest extension data is retained. A migration deletes only the legacy paths whose reconciled contents appear in the exact proposed destination files.

`preparePublish()` completes source reads before returning an immutable preview. Its identity includes repository, branch, read revision, all exact file contents and deletions, message, source versions and pending events. The UI exposes exact content and supplies that same object to `push(plan)`. Copies, missing approvals, changed destinations and changed base revisions are refused. The Bend publication gate compares complete canonical encodings and the shared domain version policy.

GitHub writes compare the current branch with the approved parent before creating a tree, use that parent's tree to preserve unrelated files, and update the ref without force. A peer change before the parent lookup cannot be silently accepted as a new base. A later race becomes a conflict. Conflict reload keeps pending work and requires another explicit preview; it does not silently retry a materially changed plan. Initial commits use one atomic Git tree/ref route and have no partial contents-API fallback.

Successful writes acknowledge only the approved events with identical full content through the Bend policy. Events staged during a request remain pending. Failed effects acknowledge nothing. A successful commit followed by a storage or reload problem is reported as published with a warning rather than misrepresented as an unsuccessful commit. A later authoritative load removes only exact pending duplicates confirmed in the repository. An ambiguous network error keeps pending events until such confirmation, rather than guessing success.

Pending storage is scoped by repository and branch. Legacy unscoped storage requires an explicit recovery choice and remains available as its original recovery source. Malformed pending data is not overwritten; storage failures keep recoverable in-memory events and show an error. Demo stores never read or write pending localStorage.

The twenty-nine independent integration groups cover exact approval, immutable bytes, in-flight edits, pre-write revision conflicts, network failure, three future-schema locations, legacy/current merge and metadata, collisions, late checkpoints/reports, branch recovery, pinned GitHub read URLs and stale-parent refusal before mutations. Their fake transport credentials are synthetic. They do not establish real GitHub service availability, browser storage quotas, or a universal migration/refinement theorem.

## Verified source cache and recovery

The remote Git tree at the pinned revision supplies the complete month source
index, including files absent from the manifest. Cached raw JSON is accepted only
after matching that tree entry's Git blob hash. Every source is decoded and
canonically replayed; schema 1/2 snapshots cannot certify coverage. See
SOURCE_CACHE.md for cold, warm and changed-source read counts.

A localStorage quota failure keeps accepted pending edits in memory and displays
a persistent recovery warning. Malformed saved events keep the store read-only
and preserve the original storage value. These failure cases are adapter tests,
not claims about universal browser storage availability.

Month grouping, event/day counts, touched source/destination months and migration
legacy-deletion flags come from bend/Planning.bend through the validated
planMonths bridge. Physical envelopes establish where events actually lived,
including historical sources filed outside the UTC timestamp month.

Pending snapshot writes are backed by unique append-only exact-add/remove
operations. Stale tabs cannot erase unseen peer drafts; discard/acknowledgement
removes only observed exact values. Retired IDs cannot be silently restaged.
See PENDING_RECOVERY.md for malformed/quota handling and journal retention limits.
