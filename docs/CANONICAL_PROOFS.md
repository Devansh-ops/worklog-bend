# Canonical event normal-form uniqueness

Checked on 2026-11-08 with pinned Bend 2.0.40, Bun 1.3.10 and the real Lean 4.34.0 verdict kernel. This support theorem composes the actual production complete-event equality, chronological ordering and ID-uniqueness predicates. No runtime or compiler code was changed.

## Exact theorem and hypotheses

`Canonical.normal_form_unique(xs, ys, sorted_x, sorted_y, unique_x, unique_y, in_x, in_y)` proves propositional equality of the two complete event lists from:

- Both lists satisfy `Sort.ordered(Core.event_le, ...)`, meaning each head is chronologically less than or equal to every later event and the tail has that same property.
- Both satisfy the actual structural `Unique.unique_ids` predicate.
- `Canonical.included(xs, ys)` and `Canonical.included(ys, xs)` hold. Inclusion checks each complete event with actual `Core.exact_contains`, which includes all decoded fields and the canonical retained source envelope.

These are independently meaningful input properties. No hypothesis asserts equality of the output lists, assumes a correct merge result or assumes the desired algebra. There is no additional ID-to-content consistency assumption: exact-event membership together with unique IDs already supplies the necessary content correspondence between the two lists.

The finite Boolean inclusion predicates keep the evidence reusable without relying on unsupported dependent template proof callbacks. They do not change set semantics into a weaker ID-only test. The root merge proofs must actually establish these hypotheses from the implementation before applying this theorem.

## Proof argument

Every exact member of an ordered list is bounded below by its head. Therefore each head precedes the other head, using the opposite inclusion. The checked chronological comparator's antisymmetry on keys gives equal head IDs.

Exact membership of the first head in the second list must then occur at the second head. If it occurred in the second tail, complete-event equality reflection would imply that the tail contains the head ID, contradicting actual structural ID uniqueness. Full event equality reflection identifies the heads, including payload, timestamps, calendar date and retained canonical content.

The proof removes the identified head from both inclusions. Each source tail lacks that head's ID, so no tail event can obtain its only membership witness from the removed head. Both tails remain ordered and structurally unique. Structural induction on the first list then gives tail equality and hence equality of the complete lists.

Empty/nonempty mismatches are refuted by the actual inclusion predicate. The proof does not silently discard duplicate event delivery or redefine complete event equality.

## Nonvacuous and negative checks

The module constructs a two-event, nonempty chronological list with distinct IDs and complete synthetic note-event envelopes. The compiler checks that ordering, unique IDs and both inclusions all hold, and applies the universal theorem to those concrete premises.

`duplicate_set_is_not_unique` demonstrates the necessary distinction: `[a]` and `[a,a]` have the same complete-event set, but the latter fails actual unique-ID checking. An isolated negative fixture claiming that duplicated list is unique is rejected. This prevents interpreting set equality alone as list equality.

The positive command executed from the proof worktree was:

```powershell
wsl --distribution Ubuntu --exec sh -lc 'cd /mnt/c/Users/desehgal/Documents/temp/worklog-bend-sort && sh /mnt/c/Users/desehgal/Documents/personal/tanmay/worklog-test/scripts/bend-linux.sh proof/Canonical.bend --verdict'
```

It returned `ALL PROOFS CHECK`, exit 0. The same verdict route on ignored `tmp/canonical-negative.bend` returned exit 1 with an equality mismatch for `deliberately_duplicate_is_unique`. Missing tools or an unsupported kernel model are not counted as negative-test success.

## Dependencies and remaining scope

The theorem uses independently checked `proof/Equality.bend`, `proof/Unique.bend` and their membership/count support, plus `proof/Sort.bend`, `proof/ChronologicalSort.bend` and `proof/Order.bend`. Those files are maintained by their respective owners. In particular, `Equality.event_equality_sound` reflects the actual full production equality predicate, and `ChronologicalSort.time_id_equal` refers to the actual timestamp/ID selector through its explicit lexicographic bridge.

The initial checked dependency commits were Equality `5a55913`, Unique `eeaafef`, Count `b8ace79`, Membership `0159ef3`, Sort `64475b9`, ChronologicalSort `6824001` and Order `77c98b7` following `28a4dae`. These dependencies were borrowed without modification for the independent check; the canonical proof commit contains only its own module and review document.

This module establishes canonical normal-form uniqueness. It is not by itself a proof that merge always succeeds on consistent inputs, refuses every conflicting ID mapping, or has the required output event set and unique IDs. The root laws must compose those separate implementation results to obtain commutativity, associativity and idempotence. It does not certify the JavaScript codec, compiler translation, persistence, GitHub or browser effects.
