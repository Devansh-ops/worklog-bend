# Replay and recovery proof scope

`proof/Replay.bend` checks typed equalities against the actual `Core` functions.
It adds no runtime implementation, axioms, foreign calls or snapshot trust rule.
The compiler is the pinned Bend 2.0.40 build used by the repository.

The universally quantified results are:

- `fold_append`: folding concatenated events is exactly folding the left part,
  then the right part, from any supplied state. This is a structural induction
  over the actual recursive fold, including all state fields and diagnostics.
- `normalform_replay`, `normalform_model`, `normalform_history`: identical exact
  canonical merge results produce identical replay results and actual Core
  automatic model and history projections, including the notes policy and date
  window. The premise concerns full typed events and canonical envelopes, not
  just IDs, timestamps, task state, or a through marker.
- `recovery_refines_full`: if merging authoritative covered and incoming events
  produces exactly the canonical full-history normal form, Core reconciliation
  returns exactly full replay. The input coverage premise is explicit; this
  theorem does not establish coverage from an untrusted snapshot.
- `note_keeps_status`, `note_keeps_completion`, `later_status_wins`: attaching a
  note preserves task status and completion, and the subsequently folded status
  update determines status. These are universal helper facts. They do not claim
  that appending an older note directly to a later state preserves `updated`.
- `latest_record`, `latest_summary`, `latest_report`: for arbitrary prior record
  lists/state, the last applied write is retrieved by the actual date/kind key
  with its exact ID, timestamp and content. A structural induction follows the
  actual replacement recursion. This is latest in fold order; chronological
  order is supplied by Core normalization. It makes no false claim that
  arbitrary `fold_sorted` input is already chronological.
- `task_update_keeps_records`: every actual existing-task update branch retains
  the complete summary/report lists, including missing-task and after-deletion
  diagnostic branches. Supporting facts cover actual state insertion and
  diagnostic construction.

The conditional normal-form results express determinism once exact coverage
has been established. They are not substitutes for merge set preservation,
canonical uniqueness, merge algebra or the host's verification of fetched
source bytes. Those obligations belong to the separate merge/canonical proofs
and host adapter tests. Equality of a result with itself is not assumed as a
recovery premise.

Nonempty checked witnesses exercise the actual public entry points:

- `late_note_recovery_witness` reconciles create/status history with a newly
  fetched backdated note. Exact expected state has the recovered note, Done
  status, later completion and later updated timestamp.
- `full_private_replay_witness` replays eight shuffled events. The exact whole
  expected state retains a deleted private task's title, private flag, tag,
  historical note and completion; the newer same-date/kind summary and report
  survive with exact content; completeness is true and diagnostics are empty.
- `private_context_witness` and `private_history_witness` check that this same
  nonempty history emits neither current-task context nor historical task
  activity, even with notes enabled. Saved summaries/reports remain in replay
  state and do not become automatic model context.

The witness canonical strings are synthetic opaque encodings. The proofs check
their preservation, not JSON encoding or host date validation. The general
deleted/private exclusion and tombstone helper laws remain in the root law set.
These witnesses supplement those universal laws rather than claiming an
unproved universal full-replay provenance theorem for arbitrary future events.

Executed validation:

```sh
sh /mnt/c/Users/desehgal/Documents/personal/tanmay/worklog-test/scripts/bend-linux.sh proof/Replay.bend --verdict
```

Result: `ALL PROOFS CHECK`. The replay helpers used here are unchanged between
the isolated worktree Core and root `fb808b6`; that root revision additionally
checks prospective command completeness before accepting staged commands.

A temporary negative module asserted that directly applying an older 02:00
note to a task updated at 05:00 keeps `updated` at 05:00. The same real compiler
returned exit 1 and `SOME PROOFS FAIL`, distinguishing 02:00 from 05:00. The
temporary module was removed. This catches the false incremental-tail claim:
authoritative recovery must normalize the complete covered plus incoming
events before folding. No unverified snapshot or watermark is accepted as
evidence of complete event coverage by these proofs.
