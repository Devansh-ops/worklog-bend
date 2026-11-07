import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Order.bend as Order

def false_disc(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

def false_clash(equality: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, equality) : false_disc(_)
  Unit{}

def and_left(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, false_clash(equality))
    case True{}:
      {==}

def and_right(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_clash(equality))
    case True{}:
      equality

def and_intro(+a: Bool, +b: Bool, left: {a == True{} : Bool}, right: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  Equal.trans(Bool, Bool.and(a, b), b, True{},
    Equal.cong(Bool, Bool, x => Bool.and(x, b), a, True{}, left), right)

# Forward lower bounds, reverse-accumulator upper bounds, and full pair order.
# The relation is a template argument, so runtime sorting remains Base.List.sort.
def all_le(~le: T.DomainEvent -> T.DomainEvent -> Bool, +head: T.DomainEvent, xs: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(le(head, h), all_le(~le, head, t))

def before(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +last: T.DomainEvent) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(le(h, last), before(~le, t, last))

def ordered(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +h <> +t:
      Bool.and(all_le(~le, h, t), ordered(~le, t))

def descending(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +h <> +t:
      Bool.and(before(~le, t, h), descending(~le, t))

def all_pairs(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(all_le(~le, h, ys), all_pairs(~le, t, ys))

def all_le_empty(~le: T.DomainEvent -> T.DomainEvent -> Bool, head: T.DomainEvent) -> {all_le(~le, head, Nil{}) == True{} : Bool}:
  {==}

def pairs_empty_right(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>) -> {all_pairs(~le, xs, Nil{}) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      pairs_empty_right(~le, t)

def ordered_tail(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, sorted: {ordered(~le, h <> t) == True{} : Bool}) -> {ordered(~le, t) == True{} : Bool}:
  and_right(all_le(~le, h, t), ordered(~le, t), sorted)

def ordered_head(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, sorted: {ordered(~le, h <> t) == True{} : Bool}) -> {all_le(~le, h, t) == True{} : Bool}:
  and_left(all_le(~le, h, t), ordered(~le, t), sorted)

def all_le_tail(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +x: T.DomainEvent, +t: List<&2, T.DomainEvent>, bound: {all_le(~le, h, x <> t) == True{} : Bool}) -> {all_le(~le, h, t) == True{} : Bool}:
  and_right(le(h, x), all_le(~le, h, t), bound)

def all_le_head(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +x: T.DomainEvent, +t: List<&2, T.DomainEvent>, bound: {all_le(~le, h, x <> t) == True{} : Bool}) -> {le(h, x) == True{} : Bool}:
  and_left(le(h, x), all_le(~le, h, t), bound)

def pairs_tail(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +bound: {all_pairs(~le, h <> t, ys) == True{} : Bool}) -> {all_pairs(~le, t, ys) == True{} : Bool}:
  and_right(all_le(~le, h, ys), all_pairs(~le, t, ys), bound)

def pairs_head(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +bound: {all_pairs(~le, h <> t, ys) == True{} : Bool}) -> {all_le(~le, h, ys) == True{} : Bool}:
  and_left(all_le(~le, h, ys), all_pairs(~le, t, ys), bound)

def before_cons(~le: T.DomainEvent -> T.DomainEvent -> Bool, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +last: T.DomainEvent, head: {le(h, last) == True{} : Bool}, tail: {before(~le, t, last) == True{} : Bool}) -> {before(~le, h <> t, last) == True{} : Bool}:
  and_intro(le(h, last), before(~le, t, last), head, tail)

def pairs_to_head(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +bound: {all_pairs(~le, xs, h <> t) == True{} : Bool}) -> {before(~le, xs, h) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +xt:
      and_intro(le(x, h), before(~le, xt, h),
        all_le_head(~le, x, h, t, pairs_head(~le, x, xt, h <> t, bound)),
        pairs_to_head(~le, xt, h, t, pairs_tail(~le, x, xt, h <> t, bound)))

def pairs_to_tail(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +bound: {all_pairs(~le, xs, h <> t) == True{} : Bool}) -> {all_pairs(~le, xs, t) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +xt:
      and_intro(all_le(~le, x, t), all_pairs(~le, xt, t),
        all_le_tail(~le, x, h, t, pairs_head(~le, x, xt, h <> t, bound)),
        pairs_to_tail(~le, xt, h, t, pairs_tail(~le, x, xt, h <> t, bound)))

def pairs_cons_right(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +h: T.DomainEvent, +ys: List<&2, T.DomainEvent>, +head: {before(~le, xs, h) == True{} : Bool}, +tail: {all_pairs(~le, xs, ys) == True{} : Bool}) -> {all_pairs(~le, xs, h <> ys) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +xt:
      and_intro(all_le(~le, x, h <> ys), all_pairs(~le, xt, h <> ys),
        and_intro(le(x, h), all_le(~le, x, ys),
          and_left(le(x, h), before(~le, xt, h), head), pairs_head(~le, x, xt, ys, tail)),
        pairs_cons_right(~le, xt, h, ys,
          and_right(le(x, h), before(~le, xt, h), head), pairs_tail(~le, x, xt, ys, tail)))

def reverse_ordered(~le: T.DomainEvent -> T.DomainEvent -> Bool, acc: List<&2, T.DomainEvent>, +suffix: List<&2, T.DomainEvent>, +descending_acc: {descending(~le, acc) == True{} : Bool}, sorted_suffix: {ordered(~le, suffix) == True{} : Bool}, +bounds: {all_pairs(~le, acc, suffix) == True{} : Bool}) -> {ordered(~le, List.reverse.go(&2, T.DomainEvent, acc, suffix)) == True{} : Bool}:
  match acc:
    case Nil{}:
      sorted_suffix
    case +h <> +t:
      reverse_ordered(~le, t, h <> suffix,
        and_right(before(~le, t, h), descending(~le, t), descending_acc),
        and_intro(all_le(~le, h, suffix), ordered(~le, suffix), pairs_head(~le, h, t, suffix, bounds), sorted_suffix),
        pairs_cons_right(~le, t, h, suffix,
          and_left(before(~le, t, h), descending(~le, t), descending_acc), pairs_tail(~le, h, t, suffix, bounds)))

def total_from_false(a: Bool, b: Bool, total: {Bool.or(a, b) == True{} : Bool}, absent: {a == False{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      total
    case True{}:
      Empty.absurd({b == True{} : Bool}, false_clash(Equal.sym(Bool, True{}, False{}, absent)))

def id_trans(a: T.DomainEvent, b: T.DomainEvent, c: T.DomainEvent, ab: {Core.event_id_le(a, b) == True{} : Bool}, bc: {Core.event_id_le(b, c) == True{} : Bool}) -> {Core.event_id_le(a, c) == True{} : Bool}:
  Order.string_le_trans(Core.event_id(a), Core.event_id(b), Core.event_id(c), ab, bc)

def id_total(a: T.DomainEvent, b: T.DomainEvent) -> {Bool.or(Core.event_id_le(a, b), Core.event_id_le(b, a)) == True{} : Bool}:
  Order.string_le_total(Core.event_id(a), Core.event_id(b))

def lower_trans(  +a: T.DomainEvent, +b: T.DomainEvent, xs: List<&2, T.DomainEvent>, +ab: {Core.event_id_le(a, b) == True{} : Bool}, +bound: {all_le(~Core.event_id_le, b, xs) == True{} : Bool}) -> {all_le(~Core.event_id_le, a, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +xt:
      and_intro(Core.event_id_le(a, x), all_le(~Core.event_id_le, a, xt),
        id_trans(a, b, x, ab, all_le_head(~Core.event_id_le, b, x, xt, bound)),
        lower_trans(a, b, xt, ab, all_le_tail(~Core.event_id_le, b, x, xt, bound)))

def lower_sorted(  +a: T.DomainEvent, +b: T.DomainEvent, +xs: List<&2, T.DomainEvent>, +ab: {Core.event_id_le(a, b) == True{} : Bool}, sorted: {ordered(~Core.event_id_le, b <> xs) == True{} : Bool}) -> {all_le(~Core.event_id_le, a, b <> xs) == True{} : Bool}:
  and_intro(Core.event_id_le(a, b), all_le(~Core.event_id_le, a, xs), ab,
    lower_trans(a, b, xs, ab, ordered_head(~Core.event_id_le, b, xs, sorted)))

def add_successor_right(a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ap:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(ap, 1n+b), 1n+Nat.add(ap, b), add_successor_right(ap, b))

def fuel_right(+f: Nat, +xt: List<&2, T.DomainEvent>, +yt: List<&2, T.DomainEvent>, enough: {Nat.is_le(Nat.add(List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt)), f) == True{} : Bool}) ->
  {Nat.is_le(Nat.add(1n+List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt)), f) == True{} : Bool}:
  Equal.trans(Bool,
    Nat.is_le(1n+Nat.add(List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt)), f),
    Nat.is_le(Nat.add(List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt)), f), True{},
    Equal.sym(Bool,
      Nat.is_le(Nat.add(List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt)), f),
      Nat.is_le(1n+Nat.add(List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt)), f),
      Equal.cong(Nat, Bool, n => Nat.is_le(n, f),
        Nat.add(List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt)),
        1n+Nat.add(List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt)),
        add_successor_right(List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt)))), enough)

def merge_choice(fuel: Nat,
  acc: List<&2, T.DomainEvent>, x: T.DomainEvent, xt: List<&2, T.DomainEvent>, y: T.DomainEvent, yt: List<&2, T.DomainEvent>, order: Bool,
  left: {order == True{} : Bool} -> {ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (x <> acc, xt, y <> yt))) == True{} : Bool},
  right: {order == False{} : Bool} -> {ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (y <> acc, x <> xt, yt))) == True{} : Bool}) ->
  {ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order))) == True{} : Bool}:
  match order:
    case False{}:
      right({==})
    case True{}:
      left({==})

def merge_ordered(  fuel: Nat, +acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  +descending_acc: {descending(~Core.event_id_le, acc) == True{} : Bool},
  +sorted_xs: {ordered(~Core.event_id_le, xs) == True{} : Bool}, +sorted_ys: {ordered(~Core.event_id_le, ys) == True{} : Bool},
  +bound_xs: {all_pairs(~Core.event_id_le, acc, xs) == True{} : Bool}, +bound_ys: {all_pairs(~Core.event_id_le, acc, ys) == True{} : Bool},
  +enough: {Nat.is_le(Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)), fuel) == True{} : Bool}) ->
  {ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (acc, xs, ys))) == True{} : Bool}:
  match fuel:
    case 0n:
      match xs ys:
        case Nil{} Nil{}:
          reverse_ordered(~Core.event_id_le, acc, Nil{}, descending_acc, {==}, pairs_empty_right(~Core.event_id_le, acc))
        case Nil{} y <> yt:
          Empty.absurd({ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, 0n, (acc, Nil{}, y <> yt))) == True{} : Bool}, false_clash(enough))
        case x <> xt Nil{}:
          Empty.absurd({ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, 0n, (acc, x <> xt, Nil{}))) == True{} : Bool}, false_clash(enough))
        case x <> xt y <> yt:
          Empty.absurd({ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, 0n, (acc, x <> xt, y <> yt))) == True{} : Bool}, false_clash(enough))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          reverse_ordered(~Core.event_id_le, acc, Nil{}, descending_acc, {==}, pairs_empty_right(~Core.event_id_le, acc))
        case Nil{} y <> yt:
          reverse_ordered(~Core.event_id_le, acc, y <> yt, descending_acc, sorted_ys, bound_ys)
        case x <> xt Nil{}:
          reverse_ordered(~Core.event_id_le, acc, x <> xt, descending_acc, sorted_xs, bound_xs)
        case +x <> +xt +y <> +yt:
          merge_choice(f, acc, x, xt, y, yt, Core.event_id_le(x, y),
            order_proof => merge_ordered(f, x <> acc, xt, y <> yt,
              and_intro(before(~Core.event_id_le, acc, x), descending(~Core.event_id_le, acc), pairs_to_head(~Core.event_id_le, acc, x, xt, bound_xs), descending_acc),
              ordered_tail(~Core.event_id_le, x, xt, sorted_xs), sorted_ys,
              and_intro(all_le(~Core.event_id_le, x, xt), all_pairs(~Core.event_id_le, acc, xt), ordered_head(~Core.event_id_le, x, xt, sorted_xs), pairs_to_tail(~Core.event_id_le, acc, x, xt, bound_xs)),
              and_intro(all_le(~Core.event_id_le, x, y <> yt), all_pairs(~Core.event_id_le, acc, y <> yt), lower_sorted(x, y, yt, order_proof, sorted_ys), bound_ys), enough),
            order_proof => merge_ordered(f, y <> acc, x <> xt, yt,
              and_intro(before(~Core.event_id_le, acc, y), descending(~Core.event_id_le, acc), pairs_to_head(~Core.event_id_le, acc, y, yt, bound_ys), descending_acc),
              sorted_xs, ordered_tail(~Core.event_id_le, y, yt, sorted_ys),
              and_intro(all_le(~Core.event_id_le, y, x <> xt), all_pairs(~Core.event_id_le, acc, x <> xt),
                lower_sorted(y, x, xt, total_from_false(Core.event_id_le(x, y), Core.event_id_le(y, x), id_total(x, y), order_proof), sorted_xs), bound_xs),
              and_intro(all_le(~Core.event_id_le, y, yt), all_pairs(~Core.event_id_le, acc, yt), ordered_head(~Core.event_id_le, y, yt, sorted_ys), pairs_to_tail(~Core.event_id_le, acc, y, yt, bound_ys)),
              fuel_right(f, xt, yt, enough)))

def add_zero_right(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ap:
      Equal.cong(Nat, Nat, n => 1n+n, Nat.add(ap, 0n), ap, add_zero_right(ap))

def add_associative(a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ap:
      Equal.cong(Nat, Nat, n => 1n+n, Nat.add(Nat.add(ap, b), c), Nat.add(ap, Nat.add(b, c)), add_associative(ap, b, c))

def nat_le_refl(n: Nat) -> {Nat.is_le(n, n) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      nat_le_refl(p)

def nat_le_trans(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a b c:
    case 0n _ _:
      match c:
        case 0n:
          {==}
        case 1n+cp:
          {==}
    case 1n+ap 0n _:
      Empty.absurd({Nat.is_le(1n+ap, c) == True{} : Bool}, false_clash(ab))
    case 1n+ap 1n+bp 0n:
      Empty.absurd({Nat.is_le(1n+ap, 0n) == True{} : Bool}, false_clash(bc))
    case 1n+ap 1n+bp 1n+cp:
      nat_le_trans(ap, bp, cp, ab, bc)

def nat_le_step(+a: Nat, +b: Nat, bound: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_le(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      Empty.absurd({Nat.is_le(1n+ap, 1n+0n) == True{} : Bool}, false_clash(bound))
    case 1n+ap 1n+bp:
      nat_le_step(ap, bp, bound)

def nat_le_add_left(a: Nat, +b: Nat, +c: Nat, bound: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(Nat.add(a, b), Nat.add(a, c)) == True{} : Bool}:
  match a:
    case 0n:
      bound
    case 1n+ap:
      nat_le_add_left(ap, b, c, bound)

def nat_le_add_right(a: Nat, +b: Nat) -> {Nat.is_le(a, Nat.add(a, b)) == True{} : Bool}:
  match a:
    case 0n:
      match b:
        case 0n:
          {==}
        case 1n+bp:
          {==}
    case 1n+ap:
      nat_le_add_right(ap, b)

def nat_right_le_sum(+a: Nat, +b: Nat) -> {Nat.is_le(b, Nat.add(a, b)) == True{} : Bool}:
  match a:
    case 0n:
      nat_le_refl(b)
    case 1n+ap:
      nat_le_step(b, Nat.add(ap, b), nat_right_le_sum(ap, b))

def append_length(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) ->
  {List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys)) == Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> +t:
      Equal.cong(Nat, Nat, n => 1n+n,
        List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, t, ys)), Nat.add(List.length(&2, T.DomainEvent, t), List.length(&2, T.DomainEvent, ys)), append_length(t, ys))

def reverse_length(xs: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>) ->
  {List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, xs, acc)) == Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, acc)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Nat,
        List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, t, h <> acc)), Nat.add(List.length(&2, T.DomainEvent, t), 1n+List.length(&2, T.DomainEvent, acc)),
        1n+Nat.add(List.length(&2, T.DomainEvent, t), List.length(&2, T.DomainEvent, acc)),
        reverse_length(t, h <> acc), add_successor_right(List.length(&2, T.DomainEvent, t), List.length(&2, T.DomainEvent, acc)))

def merge_size(+acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) -> Nat:
  Nat.add(List.length(&2, T.DomainEvent, acc), Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)))

def size_left(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(1n+a, Nat.add(b, c)) == Nat.add(a, Nat.add(1n+b, c)) : Nat}:
  Equal.sym(Nat, Nat.add(a, 1n+Nat.add(b, c)), 1n+Nat.add(a, Nat.add(b, c)), add_successor_right(a, Nat.add(b, c)))

def size_right(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(1n+a, Nat.add(b, c)) == Nat.add(a, Nat.add(b, 1n+c)) : Nat}:
  Equal.trans(Nat, 1n+Nat.add(a, Nat.add(b, c)), Nat.add(a, 1n+Nat.add(b, c)), Nat.add(a, Nat.add(b, 1n+c)),
    Equal.sym(Nat, Nat.add(a, 1n+Nat.add(b, c)), 1n+Nat.add(a, Nat.add(b, c)), add_successor_right(a, Nat.add(b, c))),
    Equal.cong(Nat, Nat, n => Nat.add(a, n), 1n+Nat.add(b, c), Nat.add(b, 1n+c), Equal.sym(Nat, Nat.add(b, 1n+c), 1n+Nat.add(b, c), add_successor_right(b, c))))

def merge_length_choice(fuel: Nat, acc: List<&2, T.DomainEvent>, x: T.DomainEvent, xt: List<&2, T.DomainEvent>, y: T.DomainEvent, yt: List<&2, T.DomainEvent>, order: Bool,
  left: {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (x <> acc, xt, y <> yt))) == merge_size(acc, x <> xt, y <> yt) : Nat},
  right: {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (y <> acc, x <> xt, yt))) == merge_size(acc, x <> xt, y <> yt) : Nat}) ->
  {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order))) == merge_size(acc, x <> xt, y <> yt) : Nat}:
  match order:
    case True{}:
      left
    case False{}:
      right

def merge_length(fuel: Nat, +acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) ->
  {List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, fuel, (acc, xs, ys))) == merge_size(acc, xs, ys) : Nat}:
  match fuel:
    case 0n:
      Equal.trans(Nat,
        List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, acc, List.append(&2, T.DomainEvent, xs, ys))),
        Nat.add(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys))), merge_size(acc, xs, ys),
        reverse_length(acc, List.append(&2, T.DomainEvent, xs, ys)),
        Equal.cong(Nat, Nat, n => Nat.add(List.length(&2, T.DomainEvent, acc), n),
          List.length(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys)), Nat.add(List.length(&2, T.DomainEvent, xs), List.length(&2, T.DomainEvent, ys)), append_length(xs, ys)))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          reverse_length(acc, Nil{})
        case Nil{} y <> yt:
          reverse_length(acc, y <> yt)
        case +x <> +xt Nil{}:
          Equal.trans(Nat,
            List.length(&2, T.DomainEvent, List.reverse.go(&2, T.DomainEvent, acc, x <> xt)), Nat.add(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, x <> xt)), merge_size(acc, x <> xt, Nil{}),
            reverse_length(acc, x <> xt),
            Equal.cong(Nat, Nat, n => Nat.add(List.length(&2, T.DomainEvent, acc), n),
              List.length(&2, T.DomainEvent, x <> xt), Nat.add(List.length(&2, T.DomainEvent, x <> xt), 0n),
              Equal.sym(Nat, Nat.add(List.length(&2, T.DomainEvent, x <> xt), 0n), List.length(&2, T.DomainEvent, x <> xt), add_zero_right(List.length(&2, T.DomainEvent, x <> xt)))))
        case +x <> +xt +y <> +yt:
          merge_length_choice(f, acc, x, xt, y, yt, Core.event_id_le(x, y),
            Equal.trans(Nat,
              List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, f, (x <> acc, xt, y <> yt))), merge_size(x <> acc, xt, y <> yt), merge_size(acc, x <> xt, y <> yt),
              merge_length(f, x <> acc, xt, y <> yt), size_left(List.length(&2, T.DomainEvent, acc), List.length(&2, T.DomainEvent, xt), 1n+List.length(&2, T.DomainEvent, yt))),
            Equal.trans(Nat,
              List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, f, (y <> acc, x <> xt, yt))), merge_size(y <> acc, x <> xt, yt), merge_size(acc, x <> xt, y <> yt),
              merge_length(f, y <> acc, x <> xt, yt), size_right(List.length(&2, T.DomainEvent, acc), 1n+List.length(&2, T.DomainEvent, xt), List.length(&2, T.DomainEvent, yt))))

def runs_size(runs: List<&2, List<&2, T.DomainEvent>>) -> Nat:
  match runs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(List.length(&2, T.DomainEvent, h), runs_size(t))

def runs_ordered(runs: List<&2, List<&2, T.DomainEvent>>) -> Bool:
  match runs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(ordered(~Core.event_id_le, h), runs_ordered(t))

def run_head(+h: List<&2, T.DomainEvent>, +t: List<&2, List<&2, T.DomainEvent>>, all: {runs_ordered(h <> t) == True{} : Bool}) -> {ordered(~Core.event_id_le, h) == True{} : Bool}:
  and_left(ordered(~Core.event_id_le, h), runs_ordered(t), all)

def run_tail(+h: List<&2, T.DomainEvent>, +t: List<&2, List<&2, T.DomainEvent>>, all: {runs_ordered(h <> t) == True{} : Bool}) -> {runs_ordered(t) == True{} : Bool}:
  and_right(ordered(~Core.event_id_le, h), runs_ordered(t), all)

def pair_length(x: T.DomainEvent, y: T.DomainEvent, order: Bool) -> {List.length(&2, T.DomainEvent, List.sort.pair(T.DomainEvent, x, y, order)) == 2n : Nat}:
  match order:
    case False{}:
      {==}
    case True{}:
      {==}

def pair_order_choice(+x: T.DomainEvent, +y: T.DomainEvent, order: Bool,
  forward: {order == True{} : Bool} -> {Core.event_id_le(x, y) == True{} : Bool},
  reverse: {order == False{} : Bool} -> {Core.event_id_le(y, x) == True{} : Bool}) ->
  {ordered(~Core.event_id_le, List.sort.pair(T.DomainEvent, x, y, order)) == True{} : Bool}:
  match order:
    case True{}:
      and_intro(all_le(~Core.event_id_le, x, [y]), ordered(~Core.event_id_le, [y]),
        and_intro(Core.event_id_le(x, y), True{}, forward({==}), {==}), {==})
    case False{}:
      and_intro(all_le(~Core.event_id_le, y, [x]), ordered(~Core.event_id_le, [x]),
        and_intro(Core.event_id_le(y, x), True{}, reverse({==}), {==}), {==})

def pair_ordered(+x: T.DomainEvent, +y: T.DomainEvent) -> {ordered(~Core.event_id_le, List.sort.pair(T.DomainEvent, x, y, Core.event_id_le(x, y))) == True{} : Bool}:
  pair_order_choice(x, y, Core.event_id_le(x, y), proof => proof,
    proof => total_from_false(Core.event_id_le(x, y), Core.event_id_le(y, x), id_total(x, y), proof))

def pairs_ordered(xs: List<&2, T.DomainEvent>) -> {runs_ordered(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case +x <> +y <> +t:
      and_intro(ordered(~Core.event_id_le, List.sort.pair(T.DomainEvent, x, y, Core.event_id_le(x, y))), runs_ordered(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, t)), pair_ordered(x, y), pairs_ordered(t))

def pairs_size(xs: List<&2, T.DomainEvent>) -> {runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, xs)) == List.length(&2, T.DomainEvent, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case +x <> +y <> +t:
      Equal.trans(Nat,
        runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, x <> y <> t)), Nat.add(2n, runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, t))), 2n+List.length(&2, T.DomainEvent, t),
        Equal.cong(Nat, Nat, n => Nat.add(n, runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, t))),
          List.length(&2, T.DomainEvent, List.sort.pair(T.DomainEvent, x, y, Core.event_id_le(x, y))), 2n, pair_length(x, y, Core.event_id_le(x, y))),
        Equal.cong(Nat, Nat, n => 2n+n, runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, t)), List.length(&2, T.DomainEvent, t), pairs_size(t)))

def pairs_count(xs: List<&2, T.DomainEvent>) -> {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, xs)), List.length(&2, T.DomainEvent, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      {==}
    case x <> y <> +t:
      nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, t)), List.length(&2, T.DomainEvent, t), pairs_count(t))

def pass_size(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat) ->
  {runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, runs)) == runs_size(runs) : Nat}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case +r1 <> +r2 <> +rest:
      Equal.trans(Nat,
        runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, r1 <> r2 <> rest)),
        Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest))), runs_size(r1 <> r2 <> rest),
        Equal.cong(Nat, Nat, size => Nat.add(size, runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest))),
          List.length(&2, T.DomainEvent, List.merge.go(~T.DomainEvent, ~Core.event_id_le, n, (Nil{}, r1, r2))), Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), merge_length(n, Nil{}, r1, r2)),
        Equal.trans(Nat,
          Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest))),
          Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), runs_size(rest)), runs_size(r1 <> r2 <> rest),
          Equal.cong(Nat, Nat, size => Nat.add(Nat.add(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2)), size),
            runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest)), runs_size(rest), pass_size(rest, n)),
          add_associative(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), runs_size(rest))))

def pass_count(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat) ->
  {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, runs)), List.length(&2, List<&2, T.DomainEvent>, runs)) == True{} : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case r1 <> r2 <> +rest:
      nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest)), List.length(&2, List<&2, T.DomainEvent>, rest), pass_count(rest, n))

def pair_fuel_bound(+a: Nat, +b: Nat, +c: Nat, +n: Nat, bound: {Nat.is_le(Nat.add(a, Nat.add(b, c)), n) == True{} : Bool}) -> {Nat.is_le(Nat.add(a, b), n) == True{} : Bool}:
  nat_le_trans(Nat.add(a, b), Nat.add(a, Nat.add(b, c)), n, nat_le_add_left(a, b, Nat.add(b, c), nat_le_add_right(b, c)), bound)

def tail_size_bound(+a: Nat, +b: Nat, +c: Nat, +n: Nat, bound: {Nat.is_le(Nat.add(a, Nat.add(b, c)), n) == True{} : Bool}) -> {Nat.is_le(c, n) == True{} : Bool}:
  nat_le_trans(c, Nat.add(a, Nat.add(b, c)), n,
    nat_le_trans(c, Nat.add(b, c), Nat.add(a, Nat.add(b, c)), nat_right_le_sum(b, c), nat_right_le_sum(a, Nat.add(b, c))), bound)

def pass_ordered(runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat,
  +sorted: {runs_ordered(runs) == True{} : Bool}, +size_bound: {Nat.is_le(runs_size(runs), n) == True{} : Bool}) ->
  {runs_ordered(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, runs)) == True{} : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      sorted
    case +r1 <> +r2 <> +rest:
      and_intro(
        ordered(~Core.event_id_le, List.merge.go(~T.DomainEvent, ~Core.event_id_le, n, (Nil{}, r1, r2))),
        runs_ordered(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest)),
        merge_ordered(n, Nil{}, r1, r2, {==}, run_head(r1, r2 <> rest, sorted), run_head(r2, rest, run_tail(r1, r2 <> rest, sorted)), {==}, {==},
          pair_fuel_bound(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), runs_size(rest), n, size_bound)),
        pass_ordered(rest, n, run_tail(r2, rest, run_tail(r1, r2 <> rest, sorted)),
          tail_size_bound(List.length(&2, T.DomainEvent, r1), List.length(&2, T.DomainEvent, r2), runs_size(rest), n, size_bound)))

def pass_fuel(+f: Nat, +n: Nat, r1: List<&2, T.DomainEvent>, r2: List<&2, T.DomainEvent>, +rest: List<&2, List<&2, T.DomainEvent>>,
  enough: {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, r1 <> r2 <> rest), 1n+1n+f) == True{} : Bool}) ->
  {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, r1 <> r2 <> rest)), 1n+f) == True{} : Bool}:
  nat_le_trans(List.length(&2, List<&2, T.DomainEvent>, List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, rest)), List.length(&2, List<&2, T.DomainEvent>, rest), f, pass_count(rest, n), enough)

def append_nil(xs: List<&2, T.DomainEvent>) -> {List.append(&2, T.DomainEvent, xs, Nil{}) == xs : List<&2, T.DomainEvent>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.cong(List<&2, T.DomainEvent>, List<&2, T.DomainEvent>, rest => h <> rest,
        List.append(&2, T.DomainEvent, t, Nil{}), t, append_nil(t))

def sort_go_ordered(fuel: Nat, +n: Nat, +runs: List<&2, List<&2, T.DomainEvent>>,
  +sorted: {runs_ordered(runs) == True{} : Bool}, +size_bound: {Nat.is_le(runs_size(runs), n) == True{} : Bool},
  enough: {Nat.is_le(List.length(&2, List<&2, T.DomainEvent>, runs), 1n+fuel) == True{} : Bool}) ->
  {ordered(~Core.event_id_le, List.sort.go(~T.DomainEvent, ~Core.event_id_le, fuel, n, runs)) == True{} : Bool}:
  match fuel:
    case 0n:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          Equal.trans(Bool,
            ordered(~Core.event_id_le, List.append(&2, T.DomainEvent, r, Nil{})), ordered(~Core.event_id_le, r), True{},
            Equal.cong(List<&2, T.DomainEvent>, Bool, xs => ordered(~Core.event_id_le, xs), List.append(&2, T.DomainEvent, r, Nil{}), r, append_nil(r)),
            run_head(r, Nil{}, sorted))
        case r1 <> r2 <> rest:
          Empty.absurd({ordered(~Core.event_id_le, List.sort.go(~T.DomainEvent, ~Core.event_id_le, 0n, n, r1 <> r2 <> rest)) == True{} : Bool}, false_clash(enough))
    case Succ{+f}:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          run_head(r, Nil{}, sorted)
        case +r1 <> +r2 <> +rest:
          sort_go_ordered(f, n, List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, r1 <> r2 <> rest),
            pass_ordered(r1 <> r2 <> rest, n, sorted, size_bound),
            Equal.trans(Bool,
              Nat.is_le(runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, r1 <> r2 <> rest)), n), Nat.is_le(runs_size(r1 <> r2 <> rest), n), True{},
              Equal.cong(Nat, Bool, size => Nat.is_le(size, n), runs_size(List.sort.pass(~T.DomainEvent, ~Core.event_id_le, n, r1 <> r2 <> rest)), runs_size(r1 <> r2 <> rest), pass_size(r1 <> r2 <> rest, n)), size_bound),
            pass_fuel(f, n, r1, r2, rest, enough))

def sort_ordered(xs: List<&2, T.DomainEvent>) -> {ordered(~Core.event_id_le, List.sort(~T.DomainEvent, ~Core.event_id_le, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      +ys = {h <> t : List<&2, T.DomainEvent>}
      +n = List.length(&2, T.DomainEvent, ys)
      sort_go_ordered(n, n, List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys), pairs_ordered(ys),
        Equal.trans(Bool,
          Nat.is_le(runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys)), n), Nat.is_le(n, n), True{},
          Equal.cong(Nat, Bool, size => Nat.is_le(size, n), runs_size(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys)), n, pairs_size(ys)), nat_le_refl(n)),
        nat_le_step(List.length(&2, List<&2, T.DomainEvent>, List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys)), n, pairs_count(ys)))

law actual_id_sort_is_ordered:
  for xs: List<&2, T.DomainEvent>
  {ordered(~Core.event_id_le, List.sort(~T.DomainEvent, ~Core.event_id_le, xs)) == True{} : Bool}

def actual_id_sort_is_ordered(xs):
  sort_ordered(xs)

law actual_pair_sort_is_ordered:
  for x: T.DomainEvent
  for y: T.DomainEvent
  {ordered(~Core.event_id_le, List.sort.pair(T.DomainEvent, x, y, Core.event_id_le(x, y))) == True{} : Bool}

def actual_pair_sort_is_ordered(x, y):
  pair_ordered(x, y)

# This witness verifies that the predicates accept inhabited sorted data.
law empty_is_ordered:
  for ~le: T.DomainEvent -> T.DomainEvent -> Bool
  {ordered(~le, Nil{}) == True{} : Bool}

def empty_is_ordered(le):
  {==}

def sample_event(id: String) -> T.DomainEvent:
  T.Ev{id, "2026-11-01T09:00:00.000Z", "2026-11-01", T.Deleted{"T-sample"}, "synthetic sort witness"}

law concrete_reversed_pair_is_sorted:
  {List.sort(~T.DomainEvent, ~Core.event_id_le, [sample_event("z"), sample_event("a")]) == [sample_event("a"), sample_event("z")] : List<&2, T.DomainEvent>}

def concrete_reversed_pair_is_sorted():
  {==}
