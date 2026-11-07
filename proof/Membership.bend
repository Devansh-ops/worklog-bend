import Base

# Generic Boolean-predicate preservation through the actual Base merge-sort.
# No comparator order premise is needed for membership preservation.

def any(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(p(context, h), any(~A, ~K, ~p, context, t))

def state_any(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, acc: List<&2, A>, xs: List<&2, A>, ys: List<&2, A>) -> Bool:
  Bool.or(any(~A, ~K, ~p, context, acc), Bool.or(any(~A, ~K, ~p, context, xs), any(~A, ~K, ~p, context, ys)))

def runs_any(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>) -> Bool:
  match runs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(any(~A, ~K, ~p, context, h), runs_any(~A, ~K, ~p, context, t))

def or_associative(a: Bool, b: Bool, c: Bool) -> {Bool.or(a, Bool.or(b, c)) == Bool.or(Bool.or(a, b), c) : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def or_commutative(a: Bool, b: Bool) -> {Bool.or(a, b) == Bool.or(b, a) : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def or_false_right(a: Bool) -> {Bool.or(a, False{}) == a : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def or_move_left(a: Bool, b: Bool, c: Bool) -> {Bool.or(a, Bool.or(b, c)) == Bool.or(b, Bool.or(a, c)) : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def or_pair_swap(a: Bool, b: Bool) -> {Bool.or(a, Bool.or(b, False{})) == Bool.or(b, Bool.or(a, False{})) : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def append(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>, +ys: List<&2, A>) -> {any(~A, ~K, ~p, context, List.append(&2, A, xs, ys)) == Bool.or(any(~A, ~K, ~p, context, xs), any(~A, ~K, ~p, context, ys)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        any(~A, ~K, ~p, context, List.append(&2, A, h <> t, ys)),
        Bool.or(p(context, h), Bool.or(any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, ys))),
        Bool.or(any(~A, ~K, ~p, context, h <> t), any(~A, ~K, ~p, context, ys)),
        Equal.cong(Bool, Bool, member => Bool.or(p(context, h), member),
          any(~A, ~K, ~p, context, List.append(&2, A, t, ys)), Bool.or(any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, ys)),
          append(~A, ~K, ~p, context, t, ys)),
        or_associative(p(context, h), any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, ys)))

def reverse(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>, +acc: List<&2, A>) -> {any(~A, ~K, ~p, context, List.reverse.go(&2, A, xs, acc)) == Bool.or(any(~A, ~K, ~p, context, xs), any(~A, ~K, ~p, context, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        any(~A, ~K, ~p, context, List.reverse.go(&2, A, h <> t, acc)),
        Bool.or(any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, h <> acc)),
        Bool.or(any(~A, ~K, ~p, context, h <> t), any(~A, ~K, ~p, context, acc)),
        reverse(~A, ~K, ~p, context, t, h <> acc),
        Equal.trans(Bool,
          Bool.or(any(~A, ~K, ~p, context, t), Bool.or(p(context, h), any(~A, ~K, ~p, context, acc))),
          Bool.or(p(context, h), Bool.or(any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, acc))),
          Bool.or(Bool.or(p(context, h), any(~A, ~K, ~p, context, t)), any(~A, ~K, ~p, context, acc)),
          or_move_left(any(~A, ~K, ~p, context, t), p(context, h), any(~A, ~K, ~p, context, acc)),
          or_associative(p(context, h), any(~A, ~K, ~p, context, t), any(~A, ~K, ~p, context, acc))))

def concat(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>) -> {any(~A, ~K, ~p, context, List.concat(&2, A, runs)) == runs_any(~A, ~K, ~p, context, runs) : Bool}:
  match runs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool, any(~A, ~K, ~p, context, List.concat(&2, A, h <> t)),
        Bool.or(any(~A, ~K, ~p, context, h), any(~A, ~K, ~p, context, List.concat(&2, A, t))), runs_any(~A, ~K, ~p, context, h <> t),
        append(~A, ~K, ~p, context, h, List.concat(&2, A, t)),
        Equal.cong(Bool, Bool, member => Bool.or(any(~A, ~K, ~p, context, h), member),
          any(~A, ~K, ~p, context, List.concat(&2, A, t)), runs_any(~A, ~K, ~p, context, t), concat(~A, ~K, ~p, context, t)))

def select_left(+a: Bool, +x: Bool, +xt: Bool, +y: Bool, +yt: Bool) ->
  {Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))) == Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))) : Bool}:
  Equal.trans(Bool,
    Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))), Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))),
    Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
    Equal.sym(Bool, Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))), Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))),
      or_associative(x, a, Bool.or(xt, Bool.or(y, yt)))),
    Equal.trans(Bool,
      Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))), Bool.or(a, Bool.or(x, Bool.or(xt, Bool.or(y, yt)))),
      Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
      or_move_left(x, a, Bool.or(xt, Bool.or(y, yt))),
      Equal.cong(Bool, Bool, member => Bool.or(a, member), Bool.or(x, Bool.or(xt, Bool.or(y, yt))),
        Bool.or(Bool.or(x, xt), Bool.or(y, yt)), or_associative(x, xt, Bool.or(y, yt)))))

def select_right(+a: Bool, +x: Bool, +xt: Bool, +y: Bool, +yt: Bool) ->
  {Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)) == Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))) : Bool}:
  Equal.trans(Bool,
    Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)), Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))),
    Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
    Equal.sym(Bool, Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))), Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)),
      or_associative(y, a, Bool.or(Bool.or(x, xt), yt))),
    Equal.trans(Bool,
      Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))), Bool.or(a, Bool.or(y, Bool.or(Bool.or(x, xt), yt))),
      Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
      or_move_left(y, a, Bool.or(Bool.or(x, xt), yt)),
      Equal.cong(Bool, Bool, member => Bool.or(a, member), Bool.or(y, Bool.or(Bool.or(x, xt), yt)),
        Bool.or(Bool.or(x, xt), Bool.or(y, yt)), or_move_left(y, Bool.or(x, xt), yt))))

def merge_step(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, +acc: List<&2, A>, +x: A, +xt: List<&2, A>, +y: A, +yt: List<&2, A>, order: Bool) -> {Bool.pick(Bool, order, state_any(~A, ~K, ~p, context, x <> acc, xt, y <> yt), state_any(~A, ~K, ~p, context, y <> acc, x <> xt, yt)) == state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Bool}:
  match order:
    case False{}:
      select_right(any(~A, ~K, ~p, context, acc), p(context, x), any(~A, ~K, ~p, context, xt), p(context, y), any(~A, ~K, ~p, context, yt))
    case True{}:
      select_left(any(~A, ~K, ~p, context, acc), p(context, x), any(~A, ~K, ~p, context, xt), p(context, y), any(~A, ~K, ~p, context, yt))

def choose_merge(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, acc: List<&2, A>, x: A, xt: List<&2, A>, y: A, yt: List<&2, A>, order: Bool, left: {any(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (x <> acc, xt, y <> yt))) == state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Bool}, right: {any(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (y <> acc, x <> xt, yt))) == state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Bool}) -> {any(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, List.merge.step(A, acc, x, xt, y, yt, order))) == state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Bool}:
  match order:
    case False{}:
      right
    case True{}:
      left

def merge_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, +acc: List<&2, A>, +xs: List<&2, A>, +ys: List<&2, A>) -> {any(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (acc, xs, ys))) == state_any(~A, ~K, ~p, context, acc, xs, ys) : Bool}:
  match fuel:
    case 0n:
      Equal.trans(Bool, any(~A, ~K, ~p, context, List.merge.go(~A, ~le, 0n, (acc, xs, ys))),
        Bool.or(any(~A, ~K, ~p, context, acc), any(~A, ~K, ~p, context, List.append(&2, A, xs, ys))),
        state_any(~A, ~K, ~p, context, acc, xs, ys),
        reverse(~A, ~K, ~p, context, acc, List.append(&2, A, xs, ys)),
        Equal.cong(Bool, Bool, member => Bool.or(any(~A, ~K, ~p, context, acc), member),
          any(~A, ~K, ~p, context, List.append(&2, A, xs, ys)), Bool.or(any(~A, ~K, ~p, context, xs), any(~A, ~K, ~p, context, ys)), append(~A, ~K, ~p, context, xs, ys)))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          reverse(~A, ~K, ~p, context, acc, Nil{})
        case Nil{} y <> yt:
          reverse(~A, ~K, ~p, context, acc, y <> yt)
        case x <> xt Nil{}:
          Equal.trans(Bool, any(~A, ~K, ~p, context, List.reverse.go(&2, A, acc, x <> xt)),
            Bool.or(any(~A, ~K, ~p, context, acc), any(~A, ~K, ~p, context, x <> xt)), state_any(~A, ~K, ~p, context, acc, x <> xt, Nil{}),
            reverse(~A, ~K, ~p, context, acc, x <> xt),
            Equal.cong(Bool, Bool, member => Bool.or(any(~A, ~K, ~p, context, acc), member), any(~A, ~K, ~p, context, x <> xt), Bool.or(any(~A, ~K, ~p, context, x <> xt), False{}),
              Equal.sym(Bool, Bool.or(any(~A, ~K, ~p, context, x <> xt), False{}), any(~A, ~K, ~p, context, x <> xt), or_false_right(any(~A, ~K, ~p, context, x <> xt)))))
        case +x <> +xt +y <> +yt:
          choose_merge(~A, ~K, ~p, ~le, context, f, acc, x, xt, y, yt, le(x, y), Equal.trans(Bool, any(~A, ~K, ~p, context, List.merge.go(~A, ~le, f, (x <> acc, xt, y <> yt))),
              state_any(~A, ~K, ~p, context, x <> acc, xt, y <> yt), state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt),
              merge_membership(~A, ~K, ~p, ~le, context, f, x <> acc, xt, y <> yt), merge_step(~A, ~K, ~p, context, acc, x, xt, y, yt, True{})), Equal.trans(Bool, any(~A, ~K, ~p, context, List.merge.go(~A, ~le, f, (y <> acc, x <> xt, yt))),
              state_any(~A, ~K, ~p, context, y <> acc, x <> xt, yt), state_any(~A, ~K, ~p, context, acc, x <> xt, y <> yt),
              merge_membership(~A, ~K, ~p, ~le, context, f, y <> acc, x <> xt, yt), merge_step(~A, ~K, ~p, context, acc, x, xt, y, yt, False{})))

def pair_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, +x: A, +y: A, order: Bool) -> {any(~A, ~K, ~p, context, List.sort.pair(A, x, y, order)) == any(~A, ~K, ~p, context, [x, y]) : Bool}:
  match order:
    case False{}:
      or_pair_swap(p(context, y), p(context, x))
    case True{}:
      {==}

def pairs_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, xs: List<&2, A>) -> {runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, xs)) == any(~A, ~K, ~p, context, xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      or_false_right(any(~A, ~K, ~p, context, [h]))
    case +x <> +y <> +t:
      Equal.trans(Bool,
        runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, x <> y <> t)),
        Bool.or(any(~A, ~K, ~p, context, [x, y]), runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))), any(~A, ~K, ~p, context, x <> y <> t),
        Equal.cong(Bool, Bool, member => Bool.or(member, runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))),
          any(~A, ~K, ~p, context, List.sort.pair(A, x, y, le(x, y))), any(~A, ~K, ~p, context, [x, y]), pair_membership(~A, ~K, ~p, context, x, y, le(x, y))),
        Equal.trans(Bool,
          Bool.or(any(~A, ~K, ~p, context, [x, y]), runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))), Bool.or(any(~A, ~K, ~p, context, [x, y]), any(~A, ~K, ~p, context, t)), any(~A, ~K, ~p, context, x <> y <> t),
          Equal.cong(Bool, Bool, member => Bool.or(any(~A, ~K, ~p, context, [x, y]), member), runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t)), any(~A, ~K, ~p, context, t), pairs_membership(~A, ~K, ~p, ~le, context, t)),
          Equal.sym(Bool, any(~A, ~K, ~p, context, x <> y <> t), Bool.or(any(~A, ~K, ~p, context, [x, y]), any(~A, ~K, ~p, context, t)), append(~A, ~K, ~p, context, [x, y], t))))

def pass_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>, +n: Nat) -> {runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, runs)) == runs_any(~A, ~K, ~p, context, runs) : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case +r1 <> +r2 <> +rest:
      Equal.trans(Bool,
        runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)),
        Bool.or(Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))), runs_any(~A, ~K, ~p, context, r1 <> r2 <> rest),
        Equal.cong(Bool, Bool, member => Bool.or(member, runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))),
          any(~A, ~K, ~p, context, List.merge.go(~A, ~le, n, (Nil{}, r1, r2))), Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), merge_membership(~A, ~K, ~p, ~le, context, n, Nil{}, r1, r2)),
        Equal.trans(Bool,
          Bool.or(Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))),
          Bool.or(Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), runs_any(~A, ~K, ~p, context, rest)), runs_any(~A, ~K, ~p, context, r1 <> r2 <> rest),
          Equal.cong(Bool, Bool, member => Bool.or(Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), member),
            runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest)), runs_any(~A, ~K, ~p, context, rest), pass_membership(~A, ~K, ~p, ~le, context, rest, n)),
          Equal.sym(Bool, Bool.or(any(~A, ~K, ~p, context, r1), Bool.or(any(~A, ~K, ~p, context, r2), runs_any(~A, ~K, ~p, context, rest))),
            Bool.or(Bool.or(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2)), runs_any(~A, ~K, ~p, context, rest)), or_associative(any(~A, ~K, ~p, context, r1), any(~A, ~K, ~p, context, r2), runs_any(~A, ~K, ~p, context, rest)))))

def go_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, +n: Nat, runs: List<&2, List<&2, A>>) -> {any(~A, ~K, ~p, context, List.sort.go(~A, ~le, fuel, n, runs)) == runs_any(~A, ~K, ~p, context, runs) : Bool}:
  match fuel:
    case 0n:
      concat(~A, ~K, ~p, context, runs)
    case 1n+f:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          Equal.sym(Bool, Bool.or(any(~A, ~K, ~p, context, r), False{}), any(~A, ~K, ~p, context, r), or_false_right(any(~A, ~K, ~p, context, r)))
        case +r1 <> +r2 <> +rest:
          Equal.trans(Bool,
            any(~A, ~K, ~p, context, List.sort.go(~A, ~le, 1n+f, n, r1 <> r2 <> rest)), runs_any(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)), runs_any(~A, ~K, ~p, context, r1 <> r2 <> rest),
            go_membership(~A, ~K, ~p, ~le, context, f, n, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)),
            pass_membership(~A, ~K, ~p, ~le, context, r1 <> r2 <> rest, n))

def sort(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, xs: List<&2, A>) -> {any(~A, ~K, ~p, context, List.sort(~A, ~le, xs)) == any(~A, ~K, ~p, context, xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      +ys = {h <> t : List<&2, A>}
      +n = List.length(&2, A, ys)
      Equal.trans(Bool, any(~A, ~K, ~p, context, List.sort(~A, ~le, ys)), runs_any(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, ys)), any(~A, ~K, ~p, context, ys),
        go_membership(~A, ~K, ~p, ~le, context, n, n, List.sort.pairs(~A, ~le, ys)), pairs_membership(~A, ~K, ~p, ~le, context, ys))
