import Base

def weight(value: Bool) -> Nat:
  match value:
    case False{}:
      0n
    case True{}:
      1n

# Exact predicate occurrence-count preservation through the actual Base sort.
# No comparator order premise is needed. Counts establish multiplicity, not just membership.

def count(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(weight(p(context, h)), count(~A, ~K, ~p, context, t))

def state_count(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, acc: List<&2, A>, xs: List<&2, A>, ys: List<&2, A>) -> Nat:
  Nat.add(count(~A, ~K, ~p, context, acc), Nat.add(count(~A, ~K, ~p, context, xs), count(~A, ~K, ~p, context, ys)))

def runs_count(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>) -> Nat:
  match runs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(count(~A, ~K, ~p, context, h), runs_count(~A, ~K, ~p, context, t))

def add_associative(a: Nat, b: Nat, c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, value => 1n+value, Nat.add(p, Nat.add(b, c)), Nat.add(Nat.add(p, b), c), add_associative(p, b, c))

def add_zero(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, value => 1n+value, Nat.add(p, 0n), p, add_zero(p))

def add_succ_right(a: Nat, b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, value => 1n+value, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add_succ_right(p, b))

def add_commutative(a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      Equal.sym(Nat, Nat.add(b, 0n), b, add_zero(b))
    case Succ{+p}:
      Equal.trans(Nat, 1n+Nat.add(p, b), 1n+Nat.add(b, p), Nat.add(b, 1n+p),
        Equal.cong(Nat, Nat, value => 1n+value, Nat.add(p, b), Nat.add(b, p), add_commutative(p, b)),
        Equal.sym(Nat, Nat.add(b, 1n+p), 1n+Nat.add(b, p), add_succ_right(b, p)))

def add_false_right(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, value => 1n+value, Nat.add(p, 0n), p, add_false_right(p))

def add_move_left(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(b, Nat.add(a, c)) : Nat}:
  Equal.trans(Nat, Nat.add(a, Nat.add(b, c)), Nat.add(Nat.add(a, b), c), Nat.add(b, Nat.add(a, c)), add_associative(a, b, c),
    Equal.trans(Nat, Nat.add(Nat.add(a, b), c), Nat.add(Nat.add(b, a), c), Nat.add(b, Nat.add(a, c)),
      Equal.cong(Nat, Nat, total => Nat.add(total, c), Nat.add(a, b), Nat.add(b, a), add_commutative(a, b)),
      Equal.sym(Nat, Nat.add(b, Nat.add(a, c)), Nat.add(Nat.add(b, a), c), add_associative(b, a, c))))

def add_pair_swap(a: Nat, b: Nat) -> {Nat.add(a, Nat.add(b, 0n)) == Nat.add(b, Nat.add(a, 0n)) : Nat}:
  add_move_left(a, b, 0n)

def append(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>, +ys: List<&2, A>) -> {count(~A, ~K, ~p, context, List.append(&2, A, xs, ys)) == Nat.add(count(~A, ~K, ~p, context, xs), count(~A, ~K, ~p, context, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Nat,
        count(~A, ~K, ~p, context, List.append(&2, A, h <> t, ys)),
        Nat.add(weight(p(context, h)), Nat.add(count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, ys))),
        Nat.add(count(~A, ~K, ~p, context, h <> t), count(~A, ~K, ~p, context, ys)),
        Equal.cong(Nat, Nat, member => Nat.add(weight(p(context, h)), member),
          count(~A, ~K, ~p, context, List.append(&2, A, t, ys)), Nat.add(count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, ys)),
          append(~A, ~K, ~p, context, t, ys)),
        add_associative(weight(p(context, h)), count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, ys)))

def reverse(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, xs: List<&2, A>, +acc: List<&2, A>) -> {count(~A, ~K, ~p, context, List.reverse.go(&2, A, xs, acc)) == Nat.add(count(~A, ~K, ~p, context, xs), count(~A, ~K, ~p, context, acc)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Nat,
        count(~A, ~K, ~p, context, List.reverse.go(&2, A, h <> t, acc)),
        Nat.add(count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, h <> acc)),
        Nat.add(count(~A, ~K, ~p, context, h <> t), count(~A, ~K, ~p, context, acc)),
        reverse(~A, ~K, ~p, context, t, h <> acc),
        Equal.trans(Nat,
          Nat.add(count(~A, ~K, ~p, context, t), Nat.add(weight(p(context, h)), count(~A, ~K, ~p, context, acc))),
          Nat.add(weight(p(context, h)), Nat.add(count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, acc))),
          Nat.add(Nat.add(weight(p(context, h)), count(~A, ~K, ~p, context, t)), count(~A, ~K, ~p, context, acc)),
          add_move_left(count(~A, ~K, ~p, context, t), weight(p(context, h)), count(~A, ~K, ~p, context, acc)),
          add_associative(weight(p(context, h)), count(~A, ~K, ~p, context, t), count(~A, ~K, ~p, context, acc))))

def concat(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>) -> {count(~A, ~K, ~p, context, List.concat(&2, A, runs)) == runs_count(~A, ~K, ~p, context, runs) : Nat}:
  match runs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Nat, count(~A, ~K, ~p, context, List.concat(&2, A, h <> t)),
        Nat.add(count(~A, ~K, ~p, context, h), count(~A, ~K, ~p, context, List.concat(&2, A, t))), runs_count(~A, ~K, ~p, context, h <> t),
        append(~A, ~K, ~p, context, h, List.concat(&2, A, t)),
        Equal.cong(Nat, Nat, member => Nat.add(count(~A, ~K, ~p, context, h), member),
          count(~A, ~K, ~p, context, List.concat(&2, A, t)), runs_count(~A, ~K, ~p, context, t), concat(~A, ~K, ~p, context, t)))

def select_left(+a: Nat, +x: Nat, +xt: Nat, +y: Nat, +yt: Nat) ->
  {Nat.add(Nat.add(x, a), Nat.add(xt, Nat.add(y, yt))) == Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))) : Nat}:
  Equal.trans(Nat,
    Nat.add(Nat.add(x, a), Nat.add(xt, Nat.add(y, yt))), Nat.add(x, Nat.add(a, Nat.add(xt, Nat.add(y, yt)))),
    Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))),
    Equal.sym(Nat, Nat.add(x, Nat.add(a, Nat.add(xt, Nat.add(y, yt)))), Nat.add(Nat.add(x, a), Nat.add(xt, Nat.add(y, yt))),
      add_associative(x, a, Nat.add(xt, Nat.add(y, yt)))),
    Equal.trans(Nat,
      Nat.add(x, Nat.add(a, Nat.add(xt, Nat.add(y, yt)))), Nat.add(a, Nat.add(x, Nat.add(xt, Nat.add(y, yt)))),
      Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))),
      add_move_left(x, a, Nat.add(xt, Nat.add(y, yt))),
      Equal.cong(Nat, Nat, member => Nat.add(a, member), Nat.add(x, Nat.add(xt, Nat.add(y, yt))),
        Nat.add(Nat.add(x, xt), Nat.add(y, yt)), add_associative(x, xt, Nat.add(y, yt)))))

def select_right(+a: Nat, +x: Nat, +xt: Nat, +y: Nat, +yt: Nat) ->
  {Nat.add(Nat.add(y, a), Nat.add(Nat.add(x, xt), yt)) == Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))) : Nat}:
  Equal.trans(Nat,
    Nat.add(Nat.add(y, a), Nat.add(Nat.add(x, xt), yt)), Nat.add(y, Nat.add(a, Nat.add(Nat.add(x, xt), yt))),
    Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))),
    Equal.sym(Nat, Nat.add(y, Nat.add(a, Nat.add(Nat.add(x, xt), yt))), Nat.add(Nat.add(y, a), Nat.add(Nat.add(x, xt), yt)),
      add_associative(y, a, Nat.add(Nat.add(x, xt), yt))),
    Equal.trans(Nat,
      Nat.add(y, Nat.add(a, Nat.add(Nat.add(x, xt), yt))), Nat.add(a, Nat.add(y, Nat.add(Nat.add(x, xt), yt))),
      Nat.add(a, Nat.add(Nat.add(x, xt), Nat.add(y, yt))),
      add_move_left(y, a, Nat.add(Nat.add(x, xt), yt)),
      Equal.cong(Nat, Nat, member => Nat.add(a, member), Nat.add(y, Nat.add(Nat.add(x, xt), yt)),
        Nat.add(Nat.add(x, xt), Nat.add(y, yt)), add_move_left(y, Nat.add(x, xt), yt))))

def merge_step(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, +acc: List<&2, A>, +x: A, +xt: List<&2, A>, +y: A, +yt: List<&2, A>, order: Bool) -> {Bool.pick(Nat, order, state_count(~A, ~K, ~p, context, x <> acc, xt, y <> yt), state_count(~A, ~K, ~p, context, y <> acc, x <> xt, yt)) == state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Nat}:
  match order:
    case False{}:
      select_right(count(~A, ~K, ~p, context, acc), weight(p(context, x)), count(~A, ~K, ~p, context, xt), weight(p(context, y)), count(~A, ~K, ~p, context, yt))
    case True{}:
      select_left(count(~A, ~K, ~p, context, acc), weight(p(context, x)), count(~A, ~K, ~p, context, xt), weight(p(context, y)), count(~A, ~K, ~p, context, yt))

def choose_merge(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, acc: List<&2, A>, x: A, xt: List<&2, A>, y: A, yt: List<&2, A>, order: Bool, left: {count(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (x <> acc, xt, y <> yt))) == state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Nat}, right: {count(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (y <> acc, x <> xt, yt))) == state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Nat}) -> {count(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, List.merge.step(A, acc, x, xt, y, yt, order))) == state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt) : Nat}:
  match order:
    case False{}:
      right
    case True{}:
      left

def merge_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, +acc: List<&2, A>, +xs: List<&2, A>, +ys: List<&2, A>) -> {count(~A, ~K, ~p, context, List.merge.go(~A, ~le, fuel, (acc, xs, ys))) == state_count(~A, ~K, ~p, context, acc, xs, ys) : Nat}:
  match fuel:
    case 0n:
      Equal.trans(Nat, count(~A, ~K, ~p, context, List.merge.go(~A, ~le, 0n, (acc, xs, ys))),
        Nat.add(count(~A, ~K, ~p, context, acc), count(~A, ~K, ~p, context, List.append(&2, A, xs, ys))),
        state_count(~A, ~K, ~p, context, acc, xs, ys),
        reverse(~A, ~K, ~p, context, acc, List.append(&2, A, xs, ys)),
        Equal.cong(Nat, Nat, member => Nat.add(count(~A, ~K, ~p, context, acc), member),
          count(~A, ~K, ~p, context, List.append(&2, A, xs, ys)), Nat.add(count(~A, ~K, ~p, context, xs), count(~A, ~K, ~p, context, ys)), append(~A, ~K, ~p, context, xs, ys)))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          reverse(~A, ~K, ~p, context, acc, Nil{})
        case Nil{} y <> yt:
          reverse(~A, ~K, ~p, context, acc, y <> yt)
        case x <> xt Nil{}:
          Equal.trans(Nat, count(~A, ~K, ~p, context, List.reverse.go(&2, A, acc, x <> xt)),
            Nat.add(count(~A, ~K, ~p, context, acc), count(~A, ~K, ~p, context, x <> xt)), state_count(~A, ~K, ~p, context, acc, x <> xt, Nil{}),
            reverse(~A, ~K, ~p, context, acc, x <> xt),
            Equal.cong(Nat, Nat, member => Nat.add(count(~A, ~K, ~p, context, acc), member), count(~A, ~K, ~p, context, x <> xt), Nat.add(count(~A, ~K, ~p, context, x <> xt), 0n),
              Equal.sym(Nat, Nat.add(count(~A, ~K, ~p, context, x <> xt), 0n), count(~A, ~K, ~p, context, x <> xt), add_false_right(count(~A, ~K, ~p, context, x <> xt)))))
        case +x <> +xt +y <> +yt:
          choose_merge(~A, ~K, ~p, ~le, context, f, acc, x, xt, y, yt, le(x, y), Equal.trans(Nat, count(~A, ~K, ~p, context, List.merge.go(~A, ~le, f, (x <> acc, xt, y <> yt))),
              state_count(~A, ~K, ~p, context, x <> acc, xt, y <> yt), state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt),
              merge_membership(~A, ~K, ~p, ~le, context, f, x <> acc, xt, y <> yt), merge_step(~A, ~K, ~p, context, acc, x, xt, y, yt, True{})), Equal.trans(Nat, count(~A, ~K, ~p, context, List.merge.go(~A, ~le, f, (y <> acc, x <> xt, yt))),
              state_count(~A, ~K, ~p, context, y <> acc, x <> xt, yt), state_count(~A, ~K, ~p, context, acc, x <> xt, y <> yt),
              merge_membership(~A, ~K, ~p, ~le, context, f, y <> acc, x <> xt, yt), merge_step(~A, ~K, ~p, context, acc, x, xt, y, yt, False{})))

def pair_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, +context: K, +x: A, +y: A, order: Bool) -> {count(~A, ~K, ~p, context, List.sort.pair(A, x, y, order)) == count(~A, ~K, ~p, context, [x, y]) : Nat}:
  match order:
    case False{}:
      add_pair_swap(weight(p(context, y)), weight(p(context, x)))
    case True{}:
      {==}

def pairs_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, xs: List<&2, A>) -> {runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, xs)) == count(~A, ~K, ~p, context, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      add_false_right(count(~A, ~K, ~p, context, [h]))
    case +x <> +y <> +t:
      Equal.trans(Nat,
        runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, x <> y <> t)),
        Nat.add(count(~A, ~K, ~p, context, [x, y]), runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))), count(~A, ~K, ~p, context, x <> y <> t),
        Equal.cong(Nat, Nat, member => Nat.add(member, runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))),
          count(~A, ~K, ~p, context, List.sort.pair(A, x, y, le(x, y))), count(~A, ~K, ~p, context, [x, y]), pair_membership(~A, ~K, ~p, context, x, y, le(x, y))),
        Equal.trans(Nat,
          Nat.add(count(~A, ~K, ~p, context, [x, y]), runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t))), Nat.add(count(~A, ~K, ~p, context, [x, y]), count(~A, ~K, ~p, context, t)), count(~A, ~K, ~p, context, x <> y <> t),
          Equal.cong(Nat, Nat, member => Nat.add(count(~A, ~K, ~p, context, [x, y]), member), runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, t)), count(~A, ~K, ~p, context, t), pairs_membership(~A, ~K, ~p, ~le, context, t)),
          Equal.sym(Nat, count(~A, ~K, ~p, context, x <> y <> t), Nat.add(count(~A, ~K, ~p, context, [x, y]), count(~A, ~K, ~p, context, t)), append(~A, ~K, ~p, context, [x, y], t))))

def pass_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, runs: List<&2, List<&2, A>>, +n: Nat) -> {runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, runs)) == runs_count(~A, ~K, ~p, context, runs) : Nat}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case +r1 <> +r2 <> +rest:
      Equal.trans(Nat,
        runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)),
        Nat.add(Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))), runs_count(~A, ~K, ~p, context, r1 <> r2 <> rest),
        Equal.cong(Nat, Nat, member => Nat.add(member, runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))),
          count(~A, ~K, ~p, context, List.merge.go(~A, ~le, n, (Nil{}, r1, r2))), Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), merge_membership(~A, ~K, ~p, ~le, context, n, Nil{}, r1, r2)),
        Equal.trans(Nat,
          Nat.add(Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest))),
          Nat.add(Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), runs_count(~A, ~K, ~p, context, rest)), runs_count(~A, ~K, ~p, context, r1 <> r2 <> rest),
          Equal.cong(Nat, Nat, member => Nat.add(Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), member),
            runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, rest)), runs_count(~A, ~K, ~p, context, rest), pass_membership(~A, ~K, ~p, ~le, context, rest, n)),
          Equal.sym(Nat, Nat.add(count(~A, ~K, ~p, context, r1), Nat.add(count(~A, ~K, ~p, context, r2), runs_count(~A, ~K, ~p, context, rest))),
            Nat.add(Nat.add(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2)), runs_count(~A, ~K, ~p, context, rest)), add_associative(count(~A, ~K, ~p, context, r1), count(~A, ~K, ~p, context, r2), runs_count(~A, ~K, ~p, context, rest)))))

def go_membership(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, fuel: Nat, +n: Nat, runs: List<&2, List<&2, A>>) -> {count(~A, ~K, ~p, context, List.sort.go(~A, ~le, fuel, n, runs)) == runs_count(~A, ~K, ~p, context, runs) : Nat}:
  match fuel:
    case 0n:
      concat(~A, ~K, ~p, context, runs)
    case 1n+f:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          Equal.sym(Nat, Nat.add(count(~A, ~K, ~p, context, r), 0n), count(~A, ~K, ~p, context, r), add_false_right(count(~A, ~K, ~p, context, r)))
        case +r1 <> +r2 <> +rest:
          Equal.trans(Nat,
            count(~A, ~K, ~p, context, List.sort.go(~A, ~le, 1n+f, n, r1 <> r2 <> rest)), runs_count(~A, ~K, ~p, context, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)), runs_count(~A, ~K, ~p, context, r1 <> r2 <> rest),
            go_membership(~A, ~K, ~p, ~le, context, f, n, List.sort.pass(~A, ~le, n, r1 <> r2 <> rest)),
            pass_membership(~A, ~K, ~p, ~le, context, r1 <> r2 <> rest, n))

def sort(~A: Data, ~K: Data, ~p: K -> A -> Bool, ~le: A -> A -> Bool, +context: K, xs: List<&2, A>) -> {count(~A, ~K, ~p, context, List.sort(~A, ~le, xs)) == count(~A, ~K, ~p, context, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      +ys = {h <> t : List<&2, A>}
      +n = List.length(&2, A, ys)
      Equal.trans(Nat, count(~A, ~K, ~p, context, List.sort(~A, ~le, ys)), runs_count(~A, ~K, ~p, context, List.sort.pairs(~A, ~le, ys)), count(~A, ~K, ~p, context, ys),
        go_membership(~A, ~K, ~p, ~le, context, n, n, List.sort.pairs(~A, ~le, ys)), pairs_membership(~A, ~K, ~p, ~le, context, ys))
