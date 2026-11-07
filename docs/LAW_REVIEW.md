# Independent domain law review

Reviewed 2026-11-08. This file distinguishes required product invariants from actual mechanically checked results. A finite fixture is a behavioral witness or counterexample, not a universal proof.

## Requirements retained

The accepted requirements remain those in SPEC and DOMAIN_CONTRACTS. In particular, merge must reject inconsistent content for an ID, preserve every distinct event, and have a unique canonical result independent of arrival order. Deletion preserves a tombstone and privacy provenance. Eligibility is a positive set of authoritative public live task IDs. Notes-off withholds every automatically note-derived field, including secondary summary/report paths. A timestamp watermark is not checkpoint coverage. Publication executes the exact approved immutable plan against its approved read revision, then acknowledges only that plan's unchanged pending events.

No proof may replace these claims with an assumption that its own result is correct. Valid-state predicates must have concrete inhabited witnesses, and collision-free preconditions must not accidentally rule out all nonempty inputs. A function's purity makes repeated evaluation deterministic, but reflexivity alone does not establish event membership, canonical ordering, merge algebra, or compatibility.

## Representation obligations

- An Event constructor with both a canonical JSON string and decoded fields permits inconsistent pairs. Comparing only the string does not establish equality of arbitrary Bend Event values. Either compare all modeled fields as well, or explicitly scope claims to a certified decoder image and test that certification boundary independently.
- Raw JSON structural equality includes retained unknown fields and array order. Duplicate object keys must be rejected before ordinary JSON parsing erases them. Bend proofs over normalized values do not establish that host behavior.
- Normalized UTC string order and ordinal event-ID order need a specified comparator and actual order lemmas for universal sorting/merge algebra. Runtime sample agreement is useful but insufficient.
- A checkpoint coverage ID set alone is insufficient for applying late events directly onto a snapshot. A late older status must be inserted before newer covered statuses. Authoritative canonical replay is the safe fallback until stronger verified reconstruction exists.
- A privacy proof must cover task-linked historical events and secondary context as well as current board tasks. Free text explicitly selected by the user remains separate disclosed input, with no semantic-redaction promise.
- A Git fast-forward does not prove preservation of a peer's events if file contents were prepared against a different read revision. The effect adapter must bind its parent and base tree to the approved plan and reject a mismatch.

## Required proof families

| Family | Required universal claim | Independent witness or counterexample |
| --- | --- | --- |
| Merge | Membership, uniqueness, order, associativity, commutativity, idempotence on consistent inputs; conflict on inconsistent IDs. | Two equal-time distinct events, repeated identical delivery, same ID with changed nested/unknown content. |
| Commands | Accepted commands preserve status/priority/completion/deletion invariants. | Create done, status done, edit done, reopen; edit cannot resurrect tombstone. |
| Replay | Canonical event equality yields projection equality; recovery does not rewind newer state or lose report/summary records. | Old note, newer done, deleted private task, two report revisions. |
| Checkpoint | Snapshot plus verified uncovered reconstruction equals full replay under explicit coverage/order hypotheses. | Late status between covered create and covered done must retain done after full replay. |
| Privacy | Private/deleted/unknown tasks cannot enter structured context or allowed targets; notes-off has no automatic note-derived fields; excluded-content changes cannot influence structured output. | One public live task and one private deleted task with canary notes/history. |
| Schema and plans | Unsupported semantics produce no destructive plan; migrations preserve source event sets and delete only completely relocated files. | Future manifest/snapshot/month and mixed legacy/current paths. |
| Approval | Executed values equal approved values; failed effects acknowledge nothing; success acknowledges only planned unchanged events. | Stage event B while approved A publishes; peer changes base before and after ref comparison. |
| Calendar | Summary windows and reminder decisions use explicit valid local calendar inputs. | DST boundaries, already-fired day, disabled and before-time reminders. |

## Actual checks

Checked against the exact core implementation from commit `fb6d379` (the proof worktree cherry-pick is `0998dee`). Bend 2.0.40 at source commit `70607d7f740e3b3f4a1edc61069df8ab88491696`, Bun 1.3.10, and Lean 4.34.0 accepted root `PROOF.bend --verdict` with `ALL PROOFS CHECK` and exit 0. The source and toolchain version/integrity checks are independent of this law review.

There are 45 law declarations. This count includes supporting comparator/equality lemmas and two existential witnesses, and must not be described as 45 independent application guarantees.

| Checked scope | Actual claim |
| --- | --- |
| Completion | All six typed statuses obey the independent completion specification. Create-done into empty state and status/edit-to-done record completion; reopening to todo clears it; a nonstatus edit preserves completion. |
| Deletion | Delete sets a tombstone. Edit/note helpers preserve its flag. The actual update guard returns an after-delete diagnostic instead of applying payloads to a deleted task. |
| Privacy | A private or deleted task is ineligible. Prepending an arbitrary private/deleted task cannot change the entire structured context list. Incomplete state and unknown event semantics withhold all structured context. |
| Notes | Notes-off projection contains no direct notes, for every task and every input task list. The context type has no old-summary/report/history field. This does not certify actual provider request bytes or the separately disclosed free text. |
| Pending | Failed publication and empty approval preserve the whole pending list. An event absent from the exact committed event collection remains pending. |
| Schema | Versions numerically unequal to both supported versions are refused by the domain version predicate. An explicit schema 999 witness inhabits these premises. No write-plan/migration theorem is implied. |
| Identity and duplicate delivery | Universal full-field Event equality reflexivity includes all payload variants and retained canonical content. Two identical deliveries of any one complete event merge to that one event. This is not a theorem about arbitrary input-list merge algebra. |
| Supporting order and witnesses | Word/U32/String comparator reflexivity and String equality reflexivity. A concrete public live task inhabits eligibility, and schema 999 inhabits the refusal premises. |

The complete verification command in this worktree used the pinned sibling wrapper:

```powershell
wsl --distribution Ubuntu --exec sh -lc 'cd /mnt/c/Users/desehgal/Documents/temp/worklog-bend-laws; sh /mnt/c/Users/desehgal/Documents/temp/worklog-bend-toolchain/scripts/bend-linux.sh PROOF.bend --verdict'
$env:BEND_LINUX_WRAPPER = 'C:\Users\desehgal\Documents\temp\worklog-bend-toolchain\scripts\bend-linux.sh'
node test/proof/negative.mjs
```

Both returned exit 0. The mutation harness first requires the unmodified root verdict to succeed, then makes isolated copies of the actual production core under ignored `tmp/proof-negative-*` directories. Deliberately returning notes with notes-off failed at `Laws.notes_off_omits_all_direct_notes` with exit 1. Deliberately ignoring the private flag failed at `Laws.private_is_ineligible` with exit 1. The harness requires the named law failure, so a missing compiler/kernel cannot masquerade as a successful rejection. It preserves diagnostic text in each temporary directory and changes no production files. After integration the default wrapper path is `scripts/bend-linux.sh`, so the environment override is unnecessary.

Native Windows Bun accepted single-file checks but the pinned compiler rejected ordinary multi-file Windows import paths. These domain checks therefore used the working WSL route. The compiler source was not modified to bypass that limitation.

## Outstanding obligations

Phase 3 is not fully proved or accepted by this work. Required outstanding families include general-list merge membership, uniqueness, ordering, commutativity, associativity, idempotence, and complete content-conflict rejection; full replay/refinement and report/summary recovery; checkpoint coverage and incremental-tail refinement; command validity as a whole; migration and write-plan preservation; actual approval/effect correspondence; calendar/reminder/report laws; and lossless codecs.

The checked notes and eligibility laws concern the actual Bend structured-context functions. All provider byte paths, stale proposals, endpoint classification, explicit free-text disclosure, retry behavior, browser effects, Git ref races, JSON validation, unknown-field retention, and actual generated JavaScript still need separate adapter/integration/browser tests. The no-notes claim must not be broadened into semantic redaction of arbitrary titles, tags, or user-authored text. The failed-publication theorem concerns the acknowledgement function's failure input; the host must correctly classify effect outcomes, including ambiguous network failures.

No law uses unsafe axioms or foreign effects. Proof guarantees remain scoped to the modeled values accepted by the pinned checker and verdict kernel; the compiler translation and host boundaries are not proved by these results.
