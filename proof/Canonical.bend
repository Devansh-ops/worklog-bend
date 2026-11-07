import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Sort.bend as Sort
import ./ChronologicalSort.bend as Chron
import ./Order.bend as Order
import ./Unique.bend as Unique
import ./Equality.bend as Equality

# Finite inclusion is reusable Data evidence, avoiding higher-order proof
# callbacks or a premise that already asserts the desired list equality.
def included(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(Core.exact_contains(ys, h), included(t, ys))

def same_set(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) -> Bool:
  Bool.and(included(xs, ys), included(ys, xs))

def included_head(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, inclusion: {included(h <> t, ys) == True{} : Bool}) -> {Core.exact_contains(ys, h) == True{} : Bool}:
  Sort.and_left(Core.exact_contains(ys, h), included(t, ys), inclusion)

def included_tail(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, inclusion: {included(h <> t, ys) == True{} : Bool}) -> {included(t, ys) == True{} : Bool}:
  Sort.and_right(Core.exact_contains(ys, h), included(t, ys), inclusion)

def or_true_left(value: Bool) -> {Bool.or(True{}, value) == True{} : Bool}:
  {==}

def or_true_right(value: Bool) -> {Bool.or(value, True{}) == True{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def member_tail(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +target: T.DomainEvent,
  different: {Core.event_eq(h, target) == False{} : Bool}, present: {Core.exact_contains(h <> t, target) == True{} : Bool}) -> {Core.exact_contains(t, target) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(t, target), Core.exact_contains(h <> t, target), True{},
    Equal.sym(Bool, Core.exact_contains(h <> t, target), Core.exact_contains(t, target),
      Equal.cong(Bool, Bool, same => Bool.or(same, Core.exact_contains(t, target)), Core.event_eq(h, target), False{}, different)), present)

def id_true_from_equal(+a: T.DomainEvent, +b: T.DomainEvent, same: {a == b : T.DomainEvent}) -> {String.eq(Core.event_id(a), Core.event_id(b)) == True{} : Bool}:
  Order.string_equality_from_equal(Core.event_id(a), Core.event_id(b), Equal.cong(T.DomainEvent, String, event => Core.event_id(event), a, b, same))

def has_id_chosen(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +target: T.DomainEvent, same: Bool,
  link: {Core.event_eq(h, target) == same : Bool}, present: {Core.exact_contains(h <> t, target) == True{} : Bool},
  continuation: {Core.exact_contains(t, target) == True{} : Bool} -> {Core.ids_contains(t, Core.event_id(target)) == True{} : Bool}) ->
  {Core.ids_contains(h <> t, Core.event_id(target)) == True{} : Bool}:
  match same:
    case True{}:
      Equal.trans(Bool, Core.ids_contains(h <> t, Core.event_id(target)), Bool.or(True{}, Core.ids_contains(t, Core.event_id(target))), True{},
        Equal.cong(Bool, Bool, flag => Bool.or(flag, Core.ids_contains(t, Core.event_id(target))), String.eq(Core.event_id(h), Core.event_id(target)), True{},
          id_true_from_equal(h, target, Equality.event_equality_sound(h, target, link))), {==})
    case False{}:
      Equal.trans(Bool, Core.ids_contains(h <> t, Core.event_id(target)), Bool.or(String.eq(Core.event_id(h), Core.event_id(target)), True{}), True{},
        Equal.cong(Bool, Bool, flag => Bool.or(String.eq(Core.event_id(h), Core.event_id(target)), flag), Core.ids_contains(t, Core.event_id(target)), True{}, continuation(member_tail(h, t, target, link, present))),
        or_true_right(String.eq(Core.event_id(h), Core.event_id(target))))

def exact_has_id(events: List<&2, T.DomainEvent>, +target: T.DomainEvent, present: {Core.exact_contains(events, target) == True{} : Bool}) -> {Core.ids_contains(events, Core.event_id(target)) == True{} : Bool}:
  match events:
    case Nil{}:
      Empty.absurd({Core.ids_contains(Nil{}, Core.event_id(target)) == True{} : Bool}, Sort.false_clash(present))
    case +h <> +t:
      has_id_chosen(h, t, target, Core.event_eq(h, target), {==}, present, tail_present => exact_has_id(t, target, tail_present))

def lower_chosen(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +first: T.DomainEvent, +target: T.DomainEvent, same: Bool,
  link: {Core.event_eq(h, target) == same : Bool}, bound: {Core.event_le(first, h) == True{} : Bool}, present: {Core.exact_contains(h <> t, target) == True{} : Bool},
  continuation: {Core.exact_contains(t, target) == True{} : Bool} -> {Core.event_le(first, target) == True{} : Bool}) -> {Core.event_le(first, target) == True{} : Bool}:
  match same:
    case True{}:
      Equal.trans(Bool, Core.event_le(first, target), Core.event_le(first, h), True{},
        Equal.sym(Bool, Core.event_le(first, h), Core.event_le(first, target),
          Equal.cong(T.DomainEvent, Bool, event => Core.event_le(first, event), h, target, Equality.event_equality_sound(h, target, link))), bound)
    case False{}:
      continuation(member_tail(h, t, target, link, present))

def lower_member(events: List<&2, T.DomainEvent>, +first: T.DomainEvent, +target: T.DomainEvent,
  +bound: {Sort.all_le(~Core.event_le, first, events) == True{} : Bool}, present: {Core.exact_contains(events, target) == True{} : Bool}) -> {Core.event_le(first, target) == True{} : Bool}:
  match events:
    case Nil{}:
      Empty.absurd({Core.event_le(first, target) == True{} : Bool}, Sort.false_clash(present))
    case +h <> +t:
      lower_chosen(h, t, first, target, Core.event_eq(h, target), {==}, Sort.all_le_head(~Core.event_le, first, h, t, bound), present,
        tail_present => lower_member(t, first, target, Sort.all_le_tail(~Core.event_le, first, h, t, bound), tail_present))

def head_minimum(+head: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +target: T.DomainEvent,
  sorted: {Sort.ordered(~Core.event_le, head <> tail) == True{} : Bool}, present: {Core.exact_contains(head <> tail, target) == True{} : Bool}) -> {Core.event_le(head, target) == True{} : Bool}:
  lower_member(head <> tail, head, target,
    Sort.and_intro(Core.event_le(head, head), Sort.all_le(~Core.event_le, head, tail), Chron.time_reflexive(head), Sort.ordered_head(~Core.event_le, head, tail, sorted)), present)

def true_from_false_absurd(value: Bool, reject: {value == False{} : Bool} -> Empty) -> {value == True{} : Bool}:
  match value:
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, reject({==}))
    case True{}:
      {==}

def absent_matching_tail(+y: T.DomainEvent, +yt: List<&2, T.DomainEvent>, +x: T.DomainEvent,
  ids_equal: {Core.event_id(x) == Core.event_id(y) : String}, absent: {Core.ids_contains(yt, Core.event_id(y)) == False{} : Bool},
  present: {Core.exact_contains(y <> yt, x) == True{} : Bool}, different: {Core.event_eq(y, x) == False{} : Bool}) -> Empty:
  present_x = exact_has_id(yt, x, member_tail(y, yt, x, different, present))
  +present_y = Equal.trans(Bool, Core.ids_contains(yt, Core.event_id(y)), Core.ids_contains(yt, Core.event_id(x)), True{},
    Equal.sym(Bool, Core.ids_contains(yt, Core.event_id(x)), Core.ids_contains(yt, Core.event_id(y)),
      Equal.cong(String, Bool, id => Core.ids_contains(yt, id), Core.event_id(x), Core.event_id(y), ids_equal)), present_x)
  Unique.true_false_clash(Equal.trans(Bool, True{}, Core.ids_contains(yt, Core.event_id(y)), False{}, Equal.sym(Bool, Core.ids_contains(yt, Core.event_id(y)), True{}, present_y), absent))

def same_head(+x: T.DomainEvent, +xt: List<&2, T.DomainEvent>, +y: T.DomainEvent, +yt: List<&2, T.DomainEvent>,
  +sorted_x: {Sort.ordered(~Core.event_le, x <> xt) == True{} : Bool}, +sorted_y: {Sort.ordered(~Core.event_le, y <> yt) == True{} : Bool},
  unique_y: {Unique.unique_ids(y <> yt) == True{} : Bool}, +in_x: {included(x <> xt, y <> yt) == True{} : Bool}, in_y: {included(y <> yt, x <> xt) == True{} : Bool}) -> {x == y : T.DomainEvent}:
  +ids_equal = Chron.time_id_equal(x, y,
    head_minimum(x, xt, y, sorted_x, included_head(y, yt, x <> xt, in_y)),
    head_minimum(y, yt, x, sorted_y, included_head(x, xt, y <> yt, in_x)))
  absent = Unique.unique_head_absent(y, yt, unique_y)
  same = true_from_false_absurd(Core.event_eq(y, x), different =>
    absent_matching_tail(y, yt, x, ids_equal, absent, included_head(x, xt, y <> yt, in_x), different))
  Equal.sym(T.DomainEvent, y, x, Equality.event_equality_sound(y, x, same))

def mismatched_id_refutes_event(+a: T.DomainEvent, +b: T.DomainEvent,
  mismatch: {String.eq(Core.event_id(b), Core.event_id(a)) == False{} : Bool}, same: {Core.event_eq(a, b) == True{} : Bool}) -> Empty:
  equal_events = Equality.event_equality_sound(a, b, same)
  +equal_ids = id_true_from_equal(b, a, Equal.sym(T.DomainEvent, a, b, equal_events))
  Unique.true_false_clash(Equal.trans(Bool, True{}, String.eq(Core.event_id(b), Core.event_id(a)), False{},
    Equal.sym(Bool, String.eq(Core.event_id(b), Core.event_id(a)), True{}, equal_ids), mismatch))

def mismatched_id_false(+a: T.DomainEvent, +b: T.DomainEvent, mismatch: {String.eq(Core.event_id(b), Core.event_id(a)) == False{} : Bool}) -> {Core.event_eq(a, b) == False{} : Bool}:
  Unique.bool_not_true_is_false(Core.event_eq(a, b), same => mismatched_id_refutes_event(a, b, mismatch, same))

def remove_head_inclusion(+head: T.DomainEvent, xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  +absent: {Core.ids_contains(xs, Core.event_id(head)) == False{} : Bool}, +inclusion: {included(xs, head <> ys) == True{} : Bool}) -> {included(xs, ys) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Sort.and_intro(Core.exact_contains(ys, h), included(t, ys),
        member_tail(head, ys, h,
          mismatched_id_false(head, h, Unique.or_false_left(String.eq(Core.event_id(h), Core.event_id(head)), Core.ids_contains(t, Core.event_id(head)), absent)),
          included_head(h, t, head <> ys, inclusion)),
        remove_head_inclusion(head, t, ys,
          Unique.or_false_right(String.eq(Core.event_id(h), Core.event_id(head)), Core.ids_contains(t, Core.event_id(head)), absent),
          included_tail(h, t, head <> ys, inclusion)))

def change_absent_id(+events: List<&2, T.DomainEvent>, +old: T.DomainEvent, +current: T.DomainEvent,
  same: {old == current : T.DomainEvent}, absent: {Core.ids_contains(events, Core.event_id(old)) == False{} : Bool}) -> {Core.ids_contains(events, Core.event_id(current)) == False{} : Bool}:
  Equal.trans(Bool, Core.ids_contains(events, Core.event_id(current)), Core.ids_contains(events, Core.event_id(old)), False{},
    Equal.sym(Bool, Core.ids_contains(events, Core.event_id(old)), Core.ids_contains(events, Core.event_id(current)),
      Equal.cong(T.DomainEvent, Bool, event => Core.ids_contains(events, Core.event_id(event)), old, current, same)), absent)

def normal_form_unique(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  +sorted_x: {Sort.ordered(~Core.event_le, xs) == True{} : Bool}, +sorted_y: {Sort.ordered(~Core.event_le, ys) == True{} : Bool},
  +unique_x: {Unique.unique_ids(xs) == True{} : Bool}, +unique_y: {Unique.unique_ids(ys) == True{} : Bool},
  +in_x: {included(xs, ys) == True{} : Bool}, +in_y: {included(ys, xs) == True{} : Bool}) -> {xs == ys : List<&2, T.DomainEvent>}:
  match xs ys:
    case Nil{} Nil{}:
      {==}
    case Nil{} y <> yt:
      Empty.absurd({Nil{} == y <> yt : List<&2, T.DomainEvent>}, Sort.false_clash(included_head(y, yt, Nil{}, in_y)))
    case x <> xt Nil{}:
      Empty.absurd({x <> xt == Nil{} : List<&2, T.DomainEvent>}, Sort.false_clash(included_head(x, xt, Nil{}, in_x)))
    case +x <> +xt +y <> +yt:
      +same = same_head(x, xt, y, yt, sorted_x, sorted_y, unique_y, in_x, in_y)
      tails = normal_form_unique(xt, yt,
        Sort.ordered_tail(~Core.event_le, x, xt, sorted_x), Sort.ordered_tail(~Core.event_le, y, yt, sorted_y),
        Unique.unique_tail(x, xt, unique_x), Unique.unique_tail(y, yt, unique_y),
        remove_head_inclusion(y, xt, yt, change_absent_id(xt, x, y, same, Unique.unique_head_absent(x, xt, unique_x)), included_tail(x, xt, y <> yt, in_x)),
        remove_head_inclusion(x, yt, xt, change_absent_id(yt, y, x, Equal.sym(T.DomainEvent, x, y, same), Unique.unique_head_absent(y, yt, unique_y)), included_tail(y, yt, x <> xt, in_y)))
      Equal.trans(List<&2, T.DomainEvent>, x <> xt, y <> xt, y <> yt,
        Equal.cong(T.DomainEvent, List<&2, T.DomainEvent>, head => head <> xt, x, y, same),
        Equal.cong(List<&2, T.DomainEvent>, List<&2, T.DomainEvent>, tail => y <> tail, xt, yt, tails))

law ordered_unique_equal_sets_are_equal:
  for xs: List<&2, T.DomainEvent>
  for ys: List<&2, T.DomainEvent>
  for sorted_x: {Sort.ordered(~Core.event_le, xs) == True{} : Bool}
  for sorted_y: {Sort.ordered(~Core.event_le, ys) == True{} : Bool}
  for unique_x: {Unique.unique_ids(xs) == True{} : Bool}
  for unique_y: {Unique.unique_ids(ys) == True{} : Bool}
  for in_x: {included(xs, ys) == True{} : Bool}
  for in_y: {included(ys, xs) == True{} : Bool}
  {xs == ys : List<&2, T.DomainEvent>}

def ordered_unique_equal_sets_are_equal(xs, ys, sorted_x, sorted_y, unique_x, unique_y, in_x, in_y):
  normal_form_unique(xs, ys, sorted_x, sorted_y, unique_x, unique_y, in_x, in_y)

def witness_a() -> T.DomainEvent:
  T.Ev{"e-a", "2026-11-01T09:00:00.000Z", "2026-11-01", T.Noted{"T-aaa111", "Synthetic A"}, "{\"id\":\"e-a\",\"taskId\":\"T-aaa111\",\"text\":\"Synthetic A\",\"ts\":\"2026-11-01T09:00:00.000Z\",\"type\":\"task.note\"}"}

def witness_b() -> T.DomainEvent:
  T.Ev{"e-b", "2026-11-01T10:00:00.000Z", "2026-11-01", T.Noted{"T-bbb222", "Synthetic B"}, "{\"id\":\"e-b\",\"taskId\":\"T-bbb222\",\"text\":\"Synthetic B\",\"ts\":\"2026-11-01T10:00:00.000Z\",\"type\":\"task.note\"}"}

law nonempty_canonical_premises_exist:
  {Bool.and(Sort.ordered(~Core.event_le, [witness_a(), witness_b()]),
    Bool.and(Unique.unique_ids([witness_a(), witness_b()]), same_set([witness_a(), witness_b()], [witness_a(), witness_b()]))) == True{} : Bool}

def nonempty_canonical_premises_exist():
  {==}

law nonempty_normal_form_application:
  {[witness_a(), witness_b()] == [witness_a(), witness_b()] : List<&2, T.DomainEvent>}

def nonempty_normal_form_application():
  normal_form_unique([witness_a(), witness_b()], [witness_a(), witness_b()], {==}, {==}, {==}, {==}, {==}, {==})

# Set equality alone intentionally does not erase multiplicity. This is a real
# counterexample to dropping the unique-ID premises from the public theorem.
law duplicate_set_is_not_unique:
  {Bool.and(same_set([witness_a()], [witness_a(), witness_a()]), Bool.not(Unique.unique_ids([witness_a(), witness_a()]))) == True{} : Bool}

def duplicate_set_is_not_unique():
  {==}
