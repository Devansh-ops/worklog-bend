# Actual event-ID sort ordering proof

Checked on 2026-11-08 with pinned Bend 2.0.40, Bun 1.3.10 and the real Lean 4.34.0 verdict kernel. `proof/Sort.bend` is a support module for the root merge laws. It imports the unchanged production `Core.event_id_le`, actual Base sorting implementation and independently checked `proof/Order.bend`.

## Checked statement

`Sort.sort_ordered(xs)` proves, for every list of typed domain events:

```text
Sort.ordered(Core.event_id_le, Base.List.sort(Core.event_id_le, xs)) = True
```

There is no input-sortedness, consistency, output-correctness or valid-state assumption. `ordered` states full forward pair order: each head is less than or equal to every later element, and the tail has the same property. Equal IDs may appear more than once; this theorem deliberately does not infer full event equality from equal IDs. Collision and duplicate handling belong to the production scan and their separate laws.

The `actual_id_sort_is_ordered` and `actual_pair_sort_is_ordered` law declarations expose the arbitrary-list and arbitrary-pair claims. A concrete reversed distinct-ID pair checks the nonempty execution route. These witnesses are typed sorting-model values, not claims about JSON codec validity or task replay.

## Proof structure

The proof follows the real Base implementation rather than a replacement sorting function:

- The reverse accumulator is descending, each input run is ordered, and every accumulated element is bounded by both remaining runs.
- `merge_ordered` proves the actual fuelled `List.merge.go` output ordered when its fuel covers the total remaining input length. The zero-fuel concatenation branch is admitted only after proving both remaining inputs empty.
- `merge_length` proves length preservation for every fuel amount, including the actual fallback branches. Arithmetic lemmas establish exact run sizes and remaining fuel bounds.
- Initial pair runs are ordered and their total size equals the original input length.
- Each pass preserves total size and ordered runs. Its run count cannot increase, and a pass on at least two runs reduces the count sufficiently for the next sort fuel value.
- `sort_go_ordered` uses those size and run-count bounds. At zero fuel, its premises force zero or one run; it does not assume arbitrary concatenated runs are ordered.
- The public theorem supplies these established invariants to the actual `List.sort` entry point.

The relation is the checked Unicode scalar string order on event IDs. Transitivity and totality call the actual `Order.string_le_trans` and `Order.string_le_total` support proofs. The comparator remains a preorder on complete events because different content can share one ID.

## Execution and limitations

From this worktree the executed positive command was:

```powershell
wsl --distribution Ubuntu --exec sh -lc 'cd /mnt/c/Users/desehgal/Documents/temp/worklog-bend-sort && sh /mnt/c/Users/desehgal/Documents/personal/tanmay/worklog-test/scripts/bend-linux.sh proof/Sort.bend --verdict'
```

It returned exit 0 and `ALL PROOFS CHECK`. An isolated deliberately unsorted distinct-ID pair claim in ignored `tmp/sort-negative.bend` was rejected with exit 1 and an equality mismatch. Missing tools or a kernel error do not count as that negative result.

A first generic formulation used a dependent template proof callback for transitivity. The standard checker accepted it, but BendTT reported an unsupported template model. The committed theorem avoids that unsupported route by referring directly to the independently proved, actual production ID comparator. No compiler or sorting algorithm was patched and no verdict gate was waived.

This module does not yet prove chronological `(timestamp,id)` sort ordering, full scan uniqueness, collision completeness, canonical output uniqueness or merge associativity/commutativity/idempotence. The root law review tracks those obligations. Input/output membership is established by the separate generic membership module. None of these proof results certifies JavaScript emission, JSON, storage, browser behavior or GitHub effects.

## Addendum: actual chronological ordering

The additive `proof/ChronologicalSort.bend` now establishes the corresponding universal statement for actual production `Core.event_le`, whose key is timestamp followed by event ID. Its public API is:

```text
ChronologicalSort.sort_ordered(xs):
  Sort.ordered(Core.event_le, Base.List.sort(Core.event_le, xs)) = True
```

This uses the same `Sort.ordered` predicate as the ID theorem and accepts arbitrary typed event lists without assuming input order or consistency. The actual timestamp/ID selector is connected to `Order.lex_le` by a checked Boolean-selector bridge. It does not rely on an invalid neutral-term definitional-equality shortcut. Independent lexicographic support comes from Order commit `77c98b7`, following scalar order commit `28a4dae`.

`time_trans`, `time_total` and `time_reflexive` establish the actual comparator's preorder laws. `time_id_equal` and `time_stamp_equal` show that mutual chronological order gives equal ID and timestamp keys, respectively. They do not infer equality of the remaining event payload or canonical content from keys alone.

The module reuses comparator-independent Boolean, reverse-accumulator, arithmetic and list helpers from `Sort.bend`. Its merge, run and fuel induction follows the same previously reviewed argument while invoking the actual chronological comparator throughout. Concrete witnesses check both equal-time ID ties and timestamp priority over an oppositely ordered ID pair.

The executed positive command replaced `proof/Sort.bend` above with `proof/ChronologicalSort.bend` and returned `ALL PROOFS CHECK`, exit 0, through the real verdict kernel. An isolated `tmp/chronological-negative.bend` claiming that the later timestamp may precede the earlier one was rejected with an equality mismatch and exit 1.

Together these two modules prove ordering of both actual production sort passes. They still do not by themselves establish full scan uniqueness, conflict completeness, canonical-output extensional uniqueness, or the associative/commutative/idempotent merge laws. Those remain distinct root obligations until their proofs are checked.
