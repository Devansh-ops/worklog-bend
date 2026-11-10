# Checked comparison-order support

`proof/Order.bend` imports only the pinned compiler's Base library. It contains supporting mathematical theorems for the event merge proofs; it does not change the runtime comparator, compiler, domain core or product requirements.

The complete module passed the real Bend 2.0.40 `--verdict` route with Bun 1.3.10 and Lean 4.34.0 on 2026-11-08:

```sh
sh scripts/bend-linux.sh proof/Order.bend --verdict
```

Observed result: `ALL PROOFS CHECK`, exit 0. Run the command from this repository root in a Linux or WSL shell; see BEND_TOOLCHAIN.md for PowerShell commands.

## Public theorem API

Import `proof/Order.bend` with an alias and call these proof functions. `a`, `b`, `c`, and `s` are arbitrary Bend `String` values. There is no validity predicate that could make the quantified domain empty.

| Function | Checked proposition |
| --- | --- |
| `string_le_refl(s)` | `String.is_le(s,s)` is True. |
| `string_le_trans(a,b,c,ab,bc)` | If the actual `a <= b` and `b <= c` comparator results are True, the actual `a <= c` result is True. |
| `string_le_total(a,b)` | At least one of the actual `a <= b` and `b <= a` results is True. |
| `string_le_antisym(a,b,ab,ba)` | If both actual directions are True, `a` and `b` are propositionally equal strings. |
| `string_le_from_equal(a,b,equality)` | Propositional string equality implies the actual `a <= b` result is True. |
| `string_eq_le(a,b,equality)` | An actual True `String.eq(a,b)` result implies the actual `a <= b` result is True. |

The two transitivity hypotheses and the two antisymmetry hypotheses have type `{String.is_le(x,y) == True{} : Bool}` for their respective directions. They are input relations, not assumptions that the desired output relation or algorithm result is correct.

## Construction and scope

The internal `chain` comparison table states the constrained composition of three comparisons. Equal comparisons preserve the other direction, two strict comparisons in the same direction preserve that direction, and opposite strict directions impose no conclusion. A finite constructor proof shows that lexicographic composition preserves this table when both component tables hold.

Structural induction then establishes this property for arbitrary fixed-length Words, using the actual tail-dominant `Word.cmp.fin`, and for U32. Structural induction over arbitrary Strings uses the actual `String.order.go`, explicit composition rewrites and the proved U32 property. No transitivity, totality or antisymmetry property of these comparators is assumed during those inductions.

Reflexivity and comparison-equality reflection are reproduced locally from the independently reviewed root proofs to avoid an import cycle. Totality and antisymmetry follow from the comparison chain for `(a,b,a)` together with actual reflexivity. Antisymmetry additionally uses the proved comparator-to-propositional-equality reflection. The literal distinct-order witness checks `"a" <= "b"` and rejects the reverse direction, demonstrating that the domain is inhabited and the order is not the universal relation.

The finite constructor branches were enumerated while writing the support proof, then checked as universal typed proof definitions by the real compiler and verdict kernel. They are not a finite runtime test substituted for string induction. No unsafe axiom, foreign effect, proof hole, compiler patch or circular root-law import is used.

These results establish comparator properties only. They do not establish merge-sort correctness, merge uniqueness, collision completeness, commutativity, associativity or idempotence. Those claims require their own proofs over the actual algorithms. Host Unicode case conversion, untrusted JSON validation, generated JavaScript and browser effects remain separate adapter obligations.

## Additive lexicographic support

The same real verdict route also accepted the additive key/tie comparison API. `lex_le(ak,at,bk,bt)` uses the actual equality-flag selector: compare ties when `String.eq(ak,bk)` is True, otherwise compare keys. This is the chronological timestamp/ID relation shape, with timestamps supplied as keys and event IDs as ties.

| Function | Checked proposition |
| --- | --- |
| `lex_le_refl(key,tie)` | Every key/tie pair is below itself. |
| `lex_le_trans(ak,at,bk,bt,ck,ct,ab,bc)` | Two actual accepted comparisons imply the third comparison. |
| `lex_le_total(ak,at,bk,bt)` | At least one comparison direction is accepted. |
| `lex_le_keys_equal(ak,at,bk,bt,ab,ba)` | Both accepted directions imply propositional key equality. |
| `lex_le_ties_equal(ak,at,bk,bt,ab,ba)` | Both accepted directions imply propositional tie equality. |
| `lex_le_antisym(ak,at,bk,bt,ab,ba)` | Both accepted directions imply propositional equality of the entire `(key,tie)` pair. |
| `string_equality_from_equal(a,b,equality)` | Propositional equality implies actual True String equality. |
| `string_eq_true_reverse(a,b,equality)` | Actual True equality in one direction implies actual True equality in the reverse direction. |

The key/tie induction reuses the proved comparison-chain composition for both independent String components. The equality-flag selector is explicitly bridged to the composed Cmp result, then reflexivity, transitivity, totality and antisymmetry follow without assuming a lexicographic-order axiom. A literal same-key/different-tie witness distinguishes the two directions.

An additional temporary import fixture proved totality of the actual `Core.event_le` for arbitrary domain events. Its proof uses a necessary explicit constructor bridge: match the Boolean flag to prove `Core.event_le_tie(ai,bi,at,bt,flag) == Order.lex_choose(at,ai,bt,bi,flag)`. The kernel does not silently identify two differently named selectors on a neutral flag, even when their branches agree. The fixture passed `--verdict` with exit 0. The independent root-law integration must retain that explicit bridge when lifting these support lemmas to production events.

A separate deliberately false temporary law claimed `lex_le("same","b","same","a") == True`. Its attempted reflexivity proof was rejected with `SOME PROOFS FAIL`, a False/True type mismatch and exit 1. This failure came from the actual comparator result, rather than a missing compiler or kernel. These temporary fixtures are ignored worktree evidence, not shipped application code or additional universal merge claims.
