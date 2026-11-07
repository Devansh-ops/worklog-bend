# Checked canonical merge algebra

`proof/Algebra.bend` establishes commutativity, associativity and idempotence for the actual `Core.merge` on arbitrary finite consistent input collections. Public statements have no output-success, ordering, uniqueness, membership-correctness or desired-result premise.

The complete module, including its nonempty applications, passed the real Bend 2.0.40 and Lean 4.34.0 verdict route on 2026-11-08:

```powershell
wsl --distribution Ubuntu --exec sh -lc 'cd /mnt/c/Users/desehgal/Documents/temp/worklog-bend-order && sh /mnt/c/Users/desehgal/Documents/personal/tanmay/worklog-test/scripts/bend-linux.sh proof/Algebra.bend --verdict'
```

Observed result: `ALL PROOFS CHECK`, exit 0. This worktree borrowed the separately checked Canonical, ChronologicalSort, Count, Equality, Membership, MergeSets, Sort and Unique dependencies. They are not changed or included in this commit. The actual merge implementation is unchanged.

## Universal public laws

| Law and proof API | Sole product precondition | Actual conclusion |
| --- | --- | --- |
| `merge_commutative(left,right,valid)` | `Consistent.consistent(left ++ right)` is True. | `Core.merge(left,right) == Core.merge(right,left)`. |
| `merge_idempotent(events,valid)` | `Consistent.consistent(events)` is True. | `Core.merge(events,events) == Core.merge(events,Nil{})`. |
| `merge_associative(xs,ys,zs,valid)` | `Consistent.consistent(xs ++ (ys ++ zs))` is True. | Merging `(xs merge ys)` with `zs` equals merging `xs` with `(ys merge zs)`. |

The consistency predicate is the independently checked finite input predicate: matching IDs require full modeled event equality, including decoded fields and the retained canonical envelope. It admits nonempty sets and identical repeated deliveries; it excludes actual same-ID/content conflicts. It does not encode algorithm success or an output property.

Associativity is expressed with `merge_after_left(result,right)` and `merge_after_right(left,result)`. Each helper only matches an actual MergeResult, calls the unchanged Core.merge on a Merged list, or propagates an EventConflict. These are logical composition helpers for the typed result, not an alternative runtime merge algorithm. Consistency derives success for every intermediate and final merge.

Idempotence concerns canonical event sets. Raw delivery lists can contain duplicates or be out of order, so the correct result is their canonical normalization. The theorem does not claim that a duplicate raw list is already identical to a canonical output.

## How the claims are established

The proof derives success from Consistent's actual scan theorem and finite inclusion in a consistent global collection. It inspects actual MergeResult constructors. Conflict cases are refuted by that derived success proof, rather than assumed absent.

For every successful result, MergeSets proves exact complete-event membership equality with the input union. Unique proves unique IDs, and ChronologicalSort plus the actual scan termination branch prove chronological ordering. Canonical's independently checked normal-form theorem then proves that two ordered unique outputs with identical full event sets are propositionally equal. Finite inclusion, transitivity, append composition and append associativity transport the input sets needed by the three laws.

Internal helpers can observe a successful-result equality to extract its already proved properties. The public laws do not ask callers for such a result or assume those properties. Every success and every output relation used by the public laws is derived from input consistency and the actual implementation.

The pinned compiler could construct but could not pattern-match the dependent `Consistent.Outputs` pair without an inference error for its type-level lambda. The proof uses the already checked `Consistent.HasOutput` proposition and explicit MergeResult constructor matching instead. This changes neither the claimed input conditions nor the runtime implementation and introduces no axiom or gate waiver.

## Witnesses and limits

Three nonempty applications call the general commutativity, associativity and idempotence proofs on faithful synthetic create events, with reordering and duplicate delivery. A fourth checked witness computes their normalized two-event result. No law is justified solely by these examples; the universal proofs quantify over arbitrary finite lists.

A separate deliberately false temporary law claimed that the original reversed, duplicated raw array remained unchanged. The real `--verdict` command rejected it with a concrete canonical-list mismatch and exit 1. This counterexample prevents conflating canonical idempotence with raw sequence identity. The temporary negative fixture is ignored worktree evidence, not a successful application law.

These proofs concern complete modeled Bend event values and the actual pure merge algorithm. They do not establish JSON/UTF-8 decoding, host timestamp normalization, verified Git source coverage, compiler translation, generated JavaScript, browser effects, checkpoint projection correctness or data migration. Those boundaries require their own checked models and executed adapter/browser regressions.
