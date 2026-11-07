import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Order.bend as Order
import ./Sort.bend as S

def event_time(event: T.DomainEvent) -> String:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      ts

def choose_bridge(ai: String, bi: String, at: String, bt: String, same: Bool) ->
  {Core.event_le_tie(ai, bi, at, bt, same) == Order.lex_choose(at, ai, bt, bi, same) : Bool}:
  match same:
    case False{}:
      {==}
    case True{}:
      {==}

def event_lex(a: T.DomainEvent, b: T.DomainEvent) ->
  {Core.event_le(a, b) == Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)) : Bool}:
  match a b:
    case T.Ev{ai, +at, ad, ap, ac} T.Ev{bi, +bt, bd, bp, bc}:
      choose_bridge(ai, bi, at, bt, String.eq(at, bt))

def lex_accepted(+a: T.DomainEvent, +b: T.DomainEvent, accepted: {Core.event_le(a, b) == True{} : Bool}) ->
  {Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)) == True{} : Bool}:
  Equal.trans(Bool, Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)), Core.event_le(a, b), True{},
    Equal.sym(Bool, Core.event_le(a, b), Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)), event_lex(a, b)), accepted)

def time_trans(+a: T.DomainEvent, +b: T.DomainEvent, +c: T.DomainEvent,
  ab: {Core.event_le(a, b) == True{} : Bool}, bc: {Core.event_le(b, c) == True{} : Bool}) -> {Core.event_le(a, c) == True{} : Bool}:
  Equal.trans(Bool, Core.event_le(a, c), Order.lex_le(event_time(a), Core.event_id(a), event_time(c), Core.event_id(c)), True{},
    event_lex(a, c),
    Order.lex_le_trans(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b), event_time(c), Core.event_id(c), lex_accepted(a, b, ab), lex_accepted(b, c, bc)))

def time_total(+a: T.DomainEvent, +b: T.DomainEvent) -> {Bool.or(Core.event_le(a, b), Core.event_le(b, a)) == True{} : Bool}:
  Equal.trans(Bool, Bool.or(Core.event_le(a, b), Core.event_le(b, a)),
    Bool.or(Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)), Order.lex_le(event_time(b), Core.event_id(b), event_time(a), Core.event_id(a))), True{},
    Order.or_cong(Core.event_le(a, b), Core.event_le(b, a),
      Order.lex_le(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)), Order.lex_le(event_time(b), Core.event_id(b), event_time(a), Core.event_id(a)), event_lex(a, b), event_lex(b, a)),
    Order.lex_le_total(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b)))

def time_reflexive(+a: T.DomainEvent) -> {Core.event_le(a, a) == True{} : Bool}:
  Equal.trans(Bool, Core.event_le(a, a), Order.lex_le(event_time(a), Core.event_id(a), event_time(a), Core.event_id(a)), True{},
    event_lex(a, a), Order.lex_le_refl(event_time(a), Core.event_id(a)))

def time_id_equal(+a: T.DomainEvent, +b: T.DomainEvent, ab: {Core.event_le(a, b) == True{} : Bool}, ba: {Core.event_le(b, a) == True{} : Bool}) -> {Core.event_id(a) == Core.event_id(b) : String}:
  Order.lex_le_ties_equal(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b), lex_accepted(a, b, ab), lex_accepted(b, a, ba))

def time_stamp_equal(+a: T.DomainEvent, +b: T.DomainEvent, ab: {Core.event_le(a, b) == True{} : Bool}, ba: {Core.event_le(b, a) == True{} : Bool}) -> {event_time(a) == event_time(b) : String}:
  Order.lex_le_keys_equal(event_time(a), Core.event_id(a), event_time(b), Core.event_id(b), lex_accepted(a, b, ab), lex_accepted(b, a, ba))

def lower_trans(  +a: T.DomainEvent, +b: T.DomainEvent, xs: List<&2, T.DomainEvent>, +ab: {Core.event_le(a, b) == True{} : Bool}, +bound: {S.all_le(~Core.event_le, b, xs) == True{} : Bool}) -> {S.all_le(~Core.event_le, a, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +xt:
      S.and_intro(Core.event_le(a, x), S.all_le(~Core.event_le, a, xt),
        time_trans(a, b, x, ab, S.all_le_head(~Core.event_le, b, x, xt, bound)),
        lower_trans(a, b, xt, ab, S.all_le_tail(~Core.event_le, b, x, xt, bound)))

def lower_sorted(  +a: T.DomainEvent, +b: T.DomainEvent, +xs: List<&2, T.DomainEvent>, +ab: {Core.event_le(a, b) == True{} : Bool}, sorted: {S.ordered(~Core.event_le, b <> xs) == True{} : Bool}) -> {S.all_le(~Core.event_le, a, b <> xs) == True{} : Bool}:
  S.and_intro(Core.event_le(a, b), S.all_le(~Core.event_le, a, xs), ab,
    lower_trans(a, b, xs, ab, S.ordered_head(~Core.event_le, b, xs, sorted)))

def merge_choice(fuel: Nat,
  acc: List<&2, T.DomainEvent>, x: T.DomainEvent, xt: List<&2, T.DomainEvent>, y: T.DomainEvent, yt: List<&2, T.DomainEvent>, order: Bool,
  left: {order == True{} : Bool} -> {S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (x <> acc, xt, y <> yt))) == True{} : Bool},
  right: {order == False{} : Bool} -> {S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (y <> acc, x <> xt, yt))) == True{} : Bool}) ->
  {S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order))) == True{} : Bool}:
  match order:
    case False{}:
      right({==})
    case True{}:
      left({==})

def merge_ordered(  fuel: Nat, +acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  +descending_acc: {S.descending(~Core.event_le, acc) == True{} : Bool},
  +sorted_xs: {S.ordered(~Core.event_le, xs) == True{} : Bool}, +sorted_ys: {S.ordered(~Core.event_le, ys) == True{} : Bool},
  +bound_xs: {S.all_pairs(~Core.event_le, acc, xs) == True{} : Bool}, +bound_ys: {S.all_pairs(~Core.event_le, acc, ys) == True{} : Bool},
  +enough: {Nat.is_le(Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)), fuel) == True{} : Bool}) ->
  {S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (acc, xs, ys))) == True{} : Bool}:
  match fuel:
    case 0n:
      match xs ys:
        case Nil{} Nil{}:
          S.reverse_ordered(~Core.event_le, acc, Nil{}, descending_acc, {==}, S.pairs_empty_right(~Core.event_le, acc))
        case Nil{} y <> yt:
          Empty.absurd({S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, 0n, (acc, Nil{}, y <> yt))) == True{} : Bool}, S.false_clash(enough))
        case x <> xt Nil{}:
          Empty.absurd({S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, 0n, (acc, x <> xt, Nil{}))) == True{} : Bool}, S.false_clash(enough))
        case x <> xt y <> yt:
          Empty.absurd({S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, 0n, (acc, x <> xt, y <> yt))) == True{} : Bool}, S.false_clash(enough))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          S.reverse_ordered(~Core.event_le, acc, Nil{}, descending_acc, {==}, S.pairs_empty_right(~Core.event_le, acc))
        case Nil{} y <> yt:
          S.reverse_ordered(~Core.event_le, acc, y <> yt, descending_acc, sorted_ys, bound_ys)
        case x <> xt Nil{}:
          S.reverse_ordered(~Core.event_le, acc, x <> xt, descending_acc, sorted_xs, bound_xs)
        case +x <> +xt +y <> +yt:
          merge_choice(f, acc, x, xt, y, yt, Core.event_le(x, y),
            order_proof => merge_ordered(f, x <> acc, xt, y <> yt,
              S.and_intro(S.before(~Core.event_le, acc, x), S.descending(~Core.event_le, acc), S.pairs_to_head(~Core.event_le, acc, x, xt, bound_xs), descending_acc),
              S.ordered_tail(~Core.event_le, x, xt, sorted_xs), sorted_ys,
              S.and_intro(S.all_le(~Core.event_le, x, xt), S.all_pairs(~Core.event_le, acc, xt), S.ordered_head(~Core.event_le, x, xt, sorted_xs), S.pairs_to_tail(~Core.event_le, acc, x, xt, bound_xs)),
              S.and_intro(S.all_le(~Core.event_le, x, y <> yt), S.all_pairs(~Core.event_le, acc, y <> yt), lower_sorted(x, y, yt, order_proof, sorted_ys), bound_ys), enough),
            order_proof => merge_ordered(f, y <> acc, x <> xt, yt,
              S.and_intro(S.before(~Core.event_le, acc, y), S.descending(~Core.event_le, acc), S.pairs_to_head(~Core.event_le, acc, y, yt, bound_ys), descending_acc),
              sorted_xs, S.ordered_tail(~Core.event_le, y, yt, sorted_ys),
              S.and_intro(S.all_le(~Core.event_le, y, x <> xt), S.all_pairs(~Core.event_le, acc, x <> xt),
                lower_sorted(y, x, xt, S.total_from_false(Core.event_le(x, y), Core.event_le(y, x), time_total(x, y), order_proof), sorted_xs), bound_xs),
              S.and_intro(S.all_le(~Core.event_le, y, yt), S.all_pairs(~Core.event_le, acc, yt), S.ordered_head(~Core.event_le, y, yt, sorted_ys), S.pairs_to_tail(~Core.event_le, acc, y, yt, bound_ys)),
              S.fuel_right(f, xt, yt, enough)))

def merge_length_choice(fuel: Nat, acc: List<&2, T.DomainEvent>, x: T.DomainEvent, xt: List<&2, T.DomainEvent>, y: T.DomainEvent, yt: List<&2, T.DomainEvent>, order: Bool,
  left: {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (x <> acc, xt, y <> yt))) == S.merge_size(acc, x <> xt, y <> yt) : Nat},
  right: {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (y <> acc, x <> xt, yt))) == S.merge_size(acc, x <> xt, y <> yt) : Nat}) ->
  {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order))) == S.merge_size(acc, x <> xt, y <> yt) : Nat}:
  match order:
    case True{}:
      left
    case False{}:
      right

def merge_length(fuel: Nat, +acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) ->
  {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, fuel, (acc, xs, ys))) == S.merge_size(acc, xs, ys) : Nat}:
  match fuel:
    case 0n:
      Equal.trans(Nat,
        List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, acc, List.append(&2, T.DomainEvent, xs, ys))),
        Nat.add(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys))), S.merge_size(acc, xs, ys),
        S.reverse_length(acc, List.append(&2, T.DomainEvent, xs, ys)),
        Equal.cong(Nat, Nat, n => Nat.add(List.length(&2, T.DomainEvent, acc), n),
          List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys)), Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)), S.append_length(xs, ys)))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          S.reverse_length(acc, Nil{})
        case Nil{} y <> yt:
          S.reverse_length(acc, y <> yt)
        case +x <> +xt Nil{}:
          Equal.trans(Nat,
            List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, acc, x <> xt)), Nat.add(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, x <> xt)), S.merge_size(acc, x <> xt, Nil{}),
            S.reverse_length(acc, x <> xt),
            Equal.cong(Nat, Nat, n => Nat.add(List.length(&2, T.DomainEvent, acc), n),
              List.length(&2, T.DomainEvent, x <> xt), Nat.add(List.length(&2, T.DomainEvent, x <> xt), 0n),
              Equal.sym(Nat, Nat.add(List.length(&2, T.DomainEvent, x <> xt), 0n), List.length(&2, T.DomainEvent, x <> xt), S.add_zero_right(List.length(&2, T.DomainEvent, x <> xt)))))
        case +x <> +xt +y <> +yt:
          merge_length_choice(f, acc, x, xt, y, yt, Core.event_le(x, y),
            Equal.trans(Nat,
              List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, f, (x <> acc, xt, y <> yt))), S.merge_size(x <> acc, xt, y <> yt), S.merge_size(acc, x <> xt, y <> yt),
              merge_length(f, x <> acc, xt, y <> yt), S.size_left(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt))),
            Equal.trans(Nat,
              List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, f, (y <> acc, x <> xt, yt))), S.merge_size(y <> acc, x <> xt, yt), S.merge_size(acc, x <> xt, y <> yt),
              merge_length(f, y <> acc, x <> xt, yt), S.size_right(List.length(&2, T.DomainEvent, acc), 1n+List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt))))

def runs_ordered(runs: List<&2, List<&2, T.DomainEvent>>) -> Bool:
  match runs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(S.ordered(~Core.event_le, h), runs_ordered(t))

def run_head(+h: List<&2, T.DomainEvent>, +t: List<&2, List<&2, T.DomainEvent>>, all: {runs_ordered(h <> t) == True{} : Bool}) -> {S.ordered(~Core.event_le, h) == True{} : Bool}:
  S.and_left(S.ordered(~Core.event_le, h), runs_ordered(t), all)

def run_tail(+h: List<&2, T.DomainEvent>, +t: List<&2, List<&2, T.DomainEvent>>, all: {runs_ordered(h <> t) == True{} : Bool}) -> {runs_ordered(t) == True{} : Bool}:
  S.and_right(S.ordered(~Core.event_le, h), runs_ordered(t), all)

def pair_order_choice(+x: T.DomainEvent, +y: T.DomainEvent, order: Bool,
  forward: {order == True{} : Bool} -> {Core.event_le(x, y) == True{} : Bool},
  reverse: {order == False{} : Bool} -> {Core.event_le(y, x) == True{} : Bool}) ->
  {S.ordered(~Core.event_le, List.sort.pair(T.DomainEvent, x, y, order)) == True{} : Bool}:
  match order:
    case True{}:
      S.and_intro(S.all_le(~Core.event_le, x, [y]), S.ordered(~Core.event_le, [y]),
        S.and_intro(Core.event_le(x, y), True{}, forward({==}), {==}), {==})
    case False{}:
      S.and_intro(S.all_le(~Core.event_le, y, [x]), S.ordered(~Core.event_le, [x]),
        S.and_intro(Core.event_le(y, x), True{}, reverse({==}), {==}), {==})

def pair_ordered(+x: T.DomainEvent, +y: T.DomainEvent) -> {S.ordered(~Core.event_le, List.sort.pair(T.DomainEvent, x, y, Core.event_le(x, y))) == True{} : Bool}:
  pair_order_choice(x, y, Core.event_le(x, y), proof => proof,
    proof => S.total_from_false(Core.event_le(x, y), Core.event_le(y, x), time_total(x, y), proof))

def pairs_ordered(xs: List<&2, T.DomainEvent>) -> {runs_ordered(List.sort.pairs(~T.DomainEvent, ~Core.event_le, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case +x <> +y <> +t:
      S.and_intro(S.ordered(~Core.event_le, List.sort.pair(T.DomainEvent, x, y, Core.event_le(x, y))), runs_ordered(List.sort.pairs(~T.DomainEvent, ~Core.event_le, t)), pair_ordered(x, y), pairs_ordered(t))

def pairs_size(xs: List<&2, T.DomainEvent>) -> {S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, xs)) == List.length(&2, T.DomainEvent, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case +x <> +y <> +t:
      Equal.trans(Nat,
        S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, x <> y <> t)), Nat.add(2n, S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, t))), 2n+List.length(&2, T.DomainEvent, t),
        Equal.cong(Nat, Nat, n => Nat.add(n, S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, t))),
          List.length(&2, T.DomainEvent, List.sort.pair(T.DomainEvent, x, y, Core.event_le(x, y))), 2n, S.pair_length(x, y, Core.event_le(x, y))),
        Equal.cong(Nat, Nat, n => 2n+n, S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, t)), List.length(&2, T.DomainEvent, t), pairs_size(t)))

def pairs_count(xs: List<&2, T.DomainEvent>) -> {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_le, xs)), List.length(&2, T.DomainEvent, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case x <> y <> +t:
      S.nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_le, t)), List.length(&2, T.DomainEvent, t), pairs_count(t))

def pass_size(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat) ->
  {S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, runs)) == S.runs_size(runs) : Nat}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case +r1 <> +r2 <> +rest:
      Equal.trans(Nat,
        S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, r1 <> r2 <> rest)),
        Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest))), S.runs_size(r1 <> r2 <> rest),
        Equal.cong(Nat, Nat, size => Nat.add(size, S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest))),
          List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_le, n, (Nil{}, r1, r2))), Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), merge_length(n, Nil{}, r1, r2)),
        Equal.trans(Nat,
          Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest))),
          Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), S.runs_size(rest)), S.runs_size(r1 <> r2 <> rest),
          Equal.cong(Nat, Nat, size => Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), size),
            S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest)), S.runs_size(rest), pass_size(rest, n)),
          S.add_associative(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), S.runs_size(rest))))

def pass_count(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat) ->
  {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_le, n, runs)), List.length(&2, List<&2, T.DomainEvent>, runs)) == True{} : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case r1 <> r2 <> +rest:
      S.nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest)), List.length(&2, List<&2, T.DomainEvent>, rest), pass_count(rest, n))

def pass_ordered(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat,
  +sorted: {runs_ordered(runs) == True{} : Bool}, +size_bound: {Nat.is_le(S.runs_size(runs), n) == True{} : Bool}) ->
  {runs_ordered(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, runs)) == True{} : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      sorted
    case +r1 <> +r2 <> +rest:
      S.and_intro(
        S.ordered(~Core.event_le, List.merge.go(~T.DomainEvent, ~Core.event_le, n, (Nil{}, r1, r2))),
        runs_ordered(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest)),
        merge_ordered(n, Nil{}, r1, r2, {==}, run_head(r1, r2 <> rest, sorted), run_head(r2, rest, run_tail(r1, r2 <> rest, sorted)), {==}, {==},
          S.pair_fuel_bound(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), S.runs_size(rest), n, size_bound)),
        pass_ordered(rest, n, run_tail(r2, rest, run_tail(r1, r2 <> rest, sorted)),
          S.tail_size_bound(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), S.runs_size(rest), n, size_bound)))

def pass_fuel(+f: Nat, +n: Nat, r1: List<&2, T.DomainEvent>, r2: List<&2, T.DomainEvent>, +rest: List<&2, List<&2, T.DomainEvent>>,
  enough: {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, r1 <> r2 <> rest), 1n+1n+f) == True{} : Bool}) ->
  {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_le, n, r1 <> r2 <> rest)), 1n+f) == True{} : Bool}:
  S.nat_le_trans(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_le, n, rest)), List.length(&2, List<&2, T.DomainEvent>, rest), f, pass_count(rest, n), enough)

def sort_go_ordered(fuel: Nat, +n: Nat, +runs: List<&2, List<&2, T.DomainEvent>>,
  +sorted: {runs_ordered(runs) == True{} : Bool}, +size_bound: {Nat.is_le(S.runs_size(runs), n) == True{} : Bool},
  enough: {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, runs), 1n+fuel) == True{} : Bool}) ->
  {S.ordered(~Core.event_le, List.sort.go(~T.DomainEvent, ~Core.event_le, fuel, n, runs)) == True{} : Bool}:
  match fuel:
    case 0n:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          Equal.trans(Bool,
            S.ordered(~Core.event_le, List.append(&2, T.DomainEvent, r, Nil{})), S.ordered(~Core.event_le, r), True{},
            Equal.cong(List<&2, T.DomainEvent>, Bool, xs => S.ordered(~Core.event_le, xs), List.append(&2, T.DomainEvent, r, Nil{}), r, S.append_nil(r)),
            run_head(r, Nil{}, sorted))
        case r1 <> r2 <> rest:
          Empty.absurd({S.ordered(~Core.event_le, List.sort.go(~T.DomainEvent, ~Core.event_le, 0n, n, r1 <> r2 <> rest)) == True{} : Bool}, S.false_clash(enough))
    case Succ{+f}:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          run_head(r, Nil{}, sorted)
        case +r1 <> +r2 <> +rest:
          sort_go_ordered(f, n, List.sort.pass(~T.DomainEvent, ~Core.event_le, n, r1 <> r2 <> rest),
            pass_ordered(r1 <> r2 <> rest, n, sorted, size_bound),
            Equal.trans(Bool,
              Nat.is_le(S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, r1 <> r2 <> rest)), n), Nat.is_le(S.runs_size(r1 <> r2 <> rest), n), True{},
              Equal.cong(Nat, Bool, size => Nat.is_le(size, n), S.runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_le, n, r1 <> r2 <> rest)), S.runs_size(r1 <> r2 <> rest), pass_size(r1 <> r2 <> rest, n)), size_bound),
            pass_fuel(f, n, r1, r2, rest, enough))

def sort_ordered(xs: List<&2, T.DomainEvent>) -> {S.ordered(~Core.event_le, List.sort(~T.DomainEvent, ~Core.event_le, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      +ys = {h <> t : List<&2, T.DomainEvent>}
      +n = List.length(&2, T.DomainEvent, ys)
      sort_go_ordered(n, n, List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys), pairs_ordered(ys),
        Equal.trans(Bool,
          Nat.is_le(S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys)), n), Nat.is_le(n, n), True{},
          Equal.cong(Nat, Bool, size => Nat.is_le(size, n), S.runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys)), n, pairs_size(ys)), S.nat_le_refl(n)),
        S.nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys)), n, pairs_count(ys)))

law actual_chronological_sort_is_ordered:
  for xs: List<&2, T.DomainEvent>
  {S.ordered(~Core.event_le, List.sort(~T.DomainEvent, ~Core.event_le, xs)) == True{} : Bool}

def actual_chronological_sort_is_ordered(xs):
  sort_ordered(xs)

law actual_pair_sort_is_ordered:
  for x: T.DomainEvent
  for y: T.DomainEvent
  {S.ordered(~Core.event_le, List.sort.pair(T.DomainEvent, x, y, Core.event_le(x, y))) == True{} : Bool}

def actual_pair_sort_is_ordered(x, y):
  pair_ordered(x, y)

# This witness verifies that the predicates accept inhabited sorted data.
law empty_is_ordered:
  for ~le: T.DomainEvent -> T.DomainEvent -> Bool
  {S.ordered(~le, Nil{}) == True{} : Bool}

def empty_is_ordered(le):
  {==}

law concrete_reversed_pair_is_sorted:
  {List.sort(~T.DomainEvent, ~Core.event_le, [S.sample_event("z"), S.sample_event("a")]) == [S.sample_event("a"), S.sample_event("z")] : List<&2, T.DomainEvent>}

def concrete_reversed_pair_is_sorted():
  {==}

def timed_sample(id: String, instant: String, day: String) -> T.DomainEvent:
  T.Ev{id, instant, day, T.Deleted{"T-sample"}, "synthetic chronological witness"}

law timestamp_precedes_id_witness:
  {List.sort(~T.DomainEvent, ~Core.event_le,
    [timed_sample("a", "2026-11-02T09:00:00.000Z", "2026-11-02"), timed_sample("z", "2026-11-01T09:00:00.000Z", "2026-11-01")]) ==
    [timed_sample("z", "2026-11-01T09:00:00.000Z", "2026-11-01"), timed_sample("a", "2026-11-02T09:00:00.000Z", "2026-11-02")] : List<&2, T.DomainEvent>}

def timestamp_precedes_id_witness():
  {==}
