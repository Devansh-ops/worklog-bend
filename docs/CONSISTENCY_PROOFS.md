# Consistent input collections have a merge result

`proof/Consistent.bend` proves success existence for the actual `Core.merge`. Its premises concern only finite input collections. They do not assume that the algorithm succeeds or that an output already has the required properties.

The complete module passed Bend 2.0.40 with the real Lean 4.34.0 verdict kernel on 2026-11-08:

```sh
sh scripts/bend-linux.sh proof/Consistent.bend --verdict
```

Observed result: `ALL PROOFS CHECK`, exit 0. The checked `proof/Membership.bend` and `proof/Equality.bend` dependencies are included in this repository. Run from the repository root in Linux or WSL after the documented toolchain setup. The proof changes no runtime algorithm or compiler code.

## Input predicates and public API

`agrees(a,b)` is the finite implication that matching event IDs require actual True `Core.event_eq(a,b)`. Full event equality includes every modeled decoded field and the retained canonical envelope, rather than just an ID or canonical-string token.

`compatible(event,events)` checks agreement with every entry. `consistent(events)` checks compatibility of each head with its tail and then the tail recursively. This admits nonempty collections, distinct events and repeated identical deliveries while excluding conflicting content for the same ID.

`included(xs,global)` checks actual complete-event membership for every entry using `Core.exact_contains`. This is a reusable finite Boolean predicate, not a function argument that assumes an output conclusion. `included_reflexive` supplies inclusion of any collection in itself, and `sort_included` transfers input inclusion through the actual Base ID sort.

The public theorem APIs are:

- `merge_success_from_global(left,right,global,valid,inclusion)`, with `valid : {consistent(global) == True{} : Bool}` and `inclusion : {included(left ++ right,global) == True{} : Bool}`.
- `merge_success(left,right,valid)`, with `valid : {consistent(left ++ right) == True{} : Bool}`.

Both return `Outputs(Core.merge(left,right))`, the dependent pair `(events, equality)` where `equality` proves `{Core.merge(left,right) == T.Merged{events} : T.MergeResult}`. A caller receives an actual success witness; success is not an input premise.

The module also exposes `global_members_agree`, which derives agreement of any two exact members of a consistent global collection, and `global_member_compatible`, which covers both earlier and later occurrences. These use checked full-event equality reflection and symmetry, so checking only adjacent input records is not silently assumed sufficient.

## Proof construction and nonvacuity

Finite inclusion equals the Boolean complement of “some entry is not a member of the global collection.” The generic, separately checked `Membership.sort` theorem preserves this actual predicate through Base merge-sort. Thus the scan receives only global members without assuming that sorting has a desired output or relying on an abstract ordering axiom.

Structural induction follows the actual `Core.scan_ids`. The previous event and next event are members of the same consistent global collection, so matching IDs cannot yield unequal full content. The actual conflict Boolean is therefore False. The empty case is a `Merged` constructor, and the recursive cases preserve that success. A dependent result extractor constructs the concrete event-list witness.

The module's nonempty witness uses two faithful synthetic create events plus an identical repeated delivery. A second witness calls the general theorem on reordered and duplicated nonempty inputs and obtains the actual merge result. A forged same-ID event keeps the first event's canonical string but changes its decoded title: its collection is proved inconsistent and the actual merge is proved to return `EventConflict`. This checks that the precondition is meaningful and that complete typed content matters.

A separate deliberately false temporary law claimed that this conflicting collection was consistent. The real checker rejected its attempted proof with a False/True mismatch and exit 1. The temporary negative fixture is ignored worktree evidence, not a successful application law.

These results establish success existence on consistent input and the stated supporting predicates. They do not by themselves prove orderedness, uniqueness, full output-content preservation, collision completeness, commutativity, associativity or idempotence. Those are separate obligations combined with this witness by the root merge-law work. Host JSON validation, source-file coverage, generated JavaScript and effects remain outside these typed model proofs.
