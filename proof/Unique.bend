import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Count.bend as Count
import ./Order.bend as Order
import ./Sort.bend as Sort

# An ID appears at most once exactly when its natural occurrence count is <= 1.
# Count preservation carries this property through the final chronological sort.
def id_matches(id: String, event: T.DomainEvent) -> Bool:
  String.eq(Core.event_id(event), id)

def id_count(events: List<&2, T.DomainEvent>, id: String) -> Nat:
  Count.count(~T.DomainEvent, ~String, ~id_matches, id, events)

def unique_ids(events: List<&2, T.DomainEvent>) -> Bool:
  match events:
    case Nil{}:
      True{}
    case +h <> +t:
      Bool.and(Bool.not(Core.ids_contains(t, Core.event_id(h))), unique_ids(t))

def true_false_clash(equality: {True{} == False{} : Bool}) -> Empty:
  Sort.false_clash(Equal.sym(Bool, True{}, False{}, equality))

def or_false_left(a: Bool, b: Bool, equality: {Bool.or(a, b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      equality

def or_false_right(a: Bool, b: Bool, equality: {Bool.or(a, b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}:
      equality
    case True{}:
      Empty.absurd({b == False{} : Bool}, true_false_clash(equality))

def not_true_is_false(value: Bool, equality: {Bool.not(value) == True{} : Bool}) -> {value == False{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, Sort.false_clash(equality))

def absent_count_zero(events: List<&2, T.DomainEvent>, +id: String, +absent: {Core.ids_contains(events, id) == False{} : Bool}) -> {id_count(events, id) == 0n : Nat}:
  match events:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Nat, id_count(h <> t, id), id_count(t, id), 0n,
        Equal.cong(Bool, Nat, present => Nat.add(Count.weight(present), id_count(t, id)),
          String.eq(Core.event_id(h), id), False{}, or_false_left(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), absent)),
        absent_count_zero(t, id, or_false_right(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), absent)))

def unique_head_absent(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, unique: {unique_ids(h <> t) == True{} : Bool}) -> {Core.ids_contains(t, Core.event_id(h)) == False{} : Bool}:
  not_true_is_false(Core.ids_contains(t, Core.event_id(h)), Sort.and_left(Bool.not(Core.ids_contains(t, Core.event_id(h))), unique_ids(t), unique))

def unique_tail(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, unique: {unique_ids(h <> t) == True{} : Bool}) -> {unique_ids(t) == True{} : Bool}:
  Sort.and_right(Bool.not(Core.ids_contains(t, Core.event_id(h))), unique_ids(t), unique)

def count_cons_bound(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +id: String, same: Bool,
  link: {same == String.eq(Core.event_id(h), id) : Bool}, absent_head: {Core.ids_contains(tail, Core.event_id(h)) == False{} : Bool}, tail_bound: {Nat.is_le(id_count(tail, id), 1n) == True{} : Bool}) ->
  {Nat.is_le(Nat.add(Count.weight(same), id_count(tail, id)), 1n) == True{} : Bool}:
  match same:
    case False{}:
      tail_bound
    case True{}:
      equal_ids = Order.string_equality_sound(Core.event_id(h), id, Equal.sym(Bool, True{}, String.eq(Core.event_id(h), id), link))
      absent_query = Equal.trans(Bool, Core.ids_contains(tail, id), Core.ids_contains(tail, Core.event_id(h)), False{},
        Equal.cong(String, Bool, key => Core.ids_contains(tail, key), id, Core.event_id(h), Equal.sym(String, Core.event_id(h), id, equal_ids)), absent_head)
      Equal.cong(Nat, Bool, n => Nat.is_le(1n+n, 1n), id_count(tail, id), 0n, absent_count_zero(tail, id, absent_query))

def unique_count_bound(events: List<&2, T.DomainEvent>, +id: String, +unique: {unique_ids(events) == True{} : Bool}) -> {Nat.is_le(id_count(events, id), 1n) == True{} : Bool}:
  match events:
    case Nil{}:
      {==}
    case +h <> +tail:
      count_cons_bound(h, tail, id, String.eq(Core.event_id(h), id), {==}, unique_head_absent(h, tail, unique), unique_count_bound(tail, id, unique_tail(h, tail, unique)))

def chronological_unique_count(+events: List<&2, T.DomainEvent>, +id: String, unique: {unique_ids(events) == True{} : Bool}) ->
  {Nat.is_le(id_count(List.sort(~T.DomainEvent, ~Core.event_le, events), id), 1n) == True{} : Bool}:
  Equal.trans(Bool, Nat.is_le(id_count(List.sort(~T.DomainEvent, ~Core.event_le, events), id), 1n), Nat.is_le(id_count(events, id), 1n), True{},
    Equal.cong(Nat, Bool, n => Nat.is_le(n, 1n), id_count(List.sort(~T.DomainEvent, ~Core.event_le, events), id), id_count(events, id),
      Count.sort(~T.DomainEvent, ~String, ~id_matches, ~Core.event_le, id, events)), unique_count_bound(events, id, unique))

def bool_not_true_is_false(value: Bool, reject: {value == True{} : Bool} -> Empty) -> {value == False{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, reject({==}))

def before_trans(events: List<&2, T.DomainEvent>, +a: T.DomainEvent, +b: T.DomainEvent,
  +ab: {Core.event_id_le(a, b) == True{} : Bool}, +bound: {Sort.before(~Core.event_id_le, events, a) == True{} : Bool}) -> {Sort.before(~Core.event_id_le, events, b) == True{} : Bool}:
  match events:
    case Nil{}:
      {==}
    case +h <> +t:
      Sort.before_cons(~Core.event_id_le, h, t, b,
        Sort.id_trans(h, a, b, Sort.and_left(Core.event_id_le(h, a), Sort.before(~Core.event_id_le, t, a), bound), ab),
        before_trans(t, a, b, ab, Sort.and_right(Core.event_id_le(h, a), Sort.before(~Core.event_id_le, t, a), bound)))

def head_equal_contradiction(+head: T.DomainEvent, +previous: T.DomainEvent, +current: T.DomainEvent,
  head_before: {Core.event_id_le(head, previous) == True{} : Bool}, previous_before: {Core.event_id_le(previous, current) == True{} : Bool},
  different: {String.eq(Core.event_id(current), Core.event_id(previous)) == False{} : Bool}, same_head: {String.eq(Core.event_id(head), Core.event_id(current)) == True{} : Bool}) -> Empty:
  head_is_current = Order.string_equality_sound(Core.event_id(head), Core.event_id(current), same_head)
  current_before_previous = Equal.trans(Bool, Core.event_id_le(current, previous), Core.event_id_le(head, previous), True{},
    Equal.cong(String, Bool, key => String.is_le(key, Core.event_id(previous)), Core.event_id(current), Core.event_id(head),
      Equal.sym(String, Core.event_id(head), Core.event_id(current), head_is_current)), head_before)
  previous_is_current = Order.string_le_antisym(Core.event_id(previous), Core.event_id(current), previous_before, current_before_previous)
  same_ids = Order.string_equality_from_equal(Core.event_id(current), Core.event_id(previous),
    Equal.sym(String, Core.event_id(previous), Core.event_id(current), previous_is_current))
  Sort.false_clash(Equal.trans(Bool, False{}, String.eq(Core.event_id(current), Core.event_id(previous)), True{},
    Equal.sym(Bool, String.eq(Core.event_id(current), Core.event_id(previous)), False{}, different), same_ids))

def absent_above_before(events: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +current: T.DomainEvent,
  +upper: {Sort.before(~Core.event_id_le, events, previous) == True{} : Bool}, +lower: {Core.event_id_le(previous, current) == True{} : Bool},
  +different: {String.eq(Core.event_id(current), Core.event_id(previous)) == False{} : Bool}) -> {Core.ids_contains(events, Core.event_id(current)) == False{} : Bool}:
  match events:
    case Nil{}:
      {==}
    case +h <> +t:
      head_absent = bool_not_true_is_false(String.eq(Core.event_id(h), Core.event_id(current)),
        same => head_equal_contradiction(h, previous, current,
          Sort.and_left(Core.event_id_le(h, previous), Sort.before(~Core.event_id_le, t, previous), upper), lower, different, same))
      Equal.trans(Bool, Core.ids_contains(h <> t, Core.event_id(current)), Bool.or(False{}, Core.ids_contains(t, Core.event_id(current))), False{},
        Equal.cong(Bool, Bool, member => Bool.or(member, Core.ids_contains(t, Core.event_id(current))), String.eq(Core.event_id(h), Core.event_id(current)), False{}, head_absent),
        absent_above_before(t, previous, current, Sort.and_right(Core.event_id_le(h, previous), Sort.before(~Core.event_id_le, t, previous), upper), lower, different))

def unique_cons(+head: T.DomainEvent, +tail: List<&2, T.DomainEvent>, absent: {Core.ids_contains(tail, Core.event_id(head)) == False{} : Bool}, unique: {unique_ids(tail) == True{} : Bool}) -> {unique_ids(head <> tail) == True{} : Bool}:
  Sort.and_intro(Bool.not(Core.ids_contains(tail, Core.event_id(head))), unique_ids(tail),
    Equal.cong(Bool, Bool, present => Bool.not(present), Core.ids_contains(tail, Core.event_id(head)), False{}, absent), unique)

def previous_bound(previous: Maybe<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +fuel: List<&2, T.DomainEvent>) -> Bool:
  match previous:
    case None{}:
      List.is_empty(&2, T.DomainEvent, acc)
    case Some{+p}:
      Bool.and(Sort.before(~Core.event_id_le, acc, p), Sort.all_le(~Core.event_id_le, p, fuel))

def SuccessfulUnique(result: T.MergeResult, id: String) -> Type:
  match result:
    case T.EventConflict{conflictId}:
      Unit
    case T.Merged{events}:
      {Nat.is_le(id_count(events, id), 1n) == True{} : Bool}

def add_branch(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +id: String,
  +sorted: {Sort.ordered(~Core.event_id_le, h <> tail) == True{} : Bool}, unique: {unique_ids(acc) == True{} : Bool},
  +upper: {Sort.before(~Core.event_id_le, acc, previous) == True{} : Bool}, +lower: {Sort.all_le(~Core.event_id_le, previous, h <> tail) == True{} : Bool},
  different: {String.eq(Core.event_id(h), Core.event_id(previous)) == False{} : Bool},
  continuation: {unique_ids(h <> acc) == True{} : Bool} -> {previous_bound(Some{h}, h <> acc, tail) == True{} : Bool} -> SuccessfulUnique(Core.scan_ids(tail, h <> acc, Some{h}), id)) ->
  SuccessfulUnique(Core.scan_ids(tail, h <> acc, Some{h}), id):
  +previous_before = Sort.all_le_head(~Core.event_id_le, previous, h, tail, lower)
  upper_next = before_trans(acc, previous, h, previous_before, upper)
  new_unique = unique_cons(h, acc, absent_above_before(acc, previous, h, upper, previous_before, different), unique)
  continuation(new_unique,
    Sort.and_intro(Sort.before(~Core.event_id_le, h <> acc, h), Sort.all_le(~Core.event_id_le, h, tail),
      Sort.before_cons(~Core.event_id_le, h, acc, h, Order.string_le_refl(Core.event_id(h)), upper_next),
      Sort.ordered_head(~Core.event_id_le, h, tail, sorted)))

def step(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +id: String, same: Bool, equal: Bool,
  +sorted: {Sort.ordered(~Core.event_id_le, h <> tail) == True{} : Bool}, unique: {unique_ids(acc) == True{} : Bool},
  +upper: {Sort.before(~Core.event_id_le, acc, previous) == True{} : Bool}, +lower: {Sort.all_le(~Core.event_id_le, previous, h <> tail) == True{} : Bool},
  link: {same == String.eq(Core.event_id(h), Core.event_id(previous)) : Bool},
  continuation: {unique_ids(Core.unique_put(h, acc, same)) == True{} : Bool} -> {previous_bound(Some{h}, Core.unique_put(h, acc, same), tail) == True{} : Bool} -> SuccessfulUnique(Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h}), id)) ->
  SuccessfulUnique(Bool.pick(T.MergeResult, Bool.and(same, Bool.not(equal)), T.EventConflict{Core.event_id(h)}, Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h})), id):
  match same equal:
    case False{} False{}:
      add_branch(h, tail, acc, previous, id, sorted, unique, upper, lower,
        Equal.sym(Bool, False{}, String.eq(Core.event_id(h), Core.event_id(previous)), link), continuation)
    case False{} True{}:
      add_branch(h, tail, acc, previous, id, sorted, unique, upper, lower,
        Equal.sym(Bool, False{}, String.eq(Core.event_id(h), Core.event_id(previous)), link), continuation)
    case True{} False{}:
      Unit{}
    case True{} True{}:
      continuation(unique,
        Sort.and_intro(Sort.before(~Core.event_id_le, acc, h), Sort.all_le(~Core.event_id_le, h, tail),
          before_trans(acc, previous, h, Sort.all_le_head(~Core.event_id_le, previous, h, tail, lower), upper),
          Sort.ordered_head(~Core.event_id_le, h, tail, sorted)))

def scan_unique(fuel: List<&2, T.DomainEvent>, previous: Maybe<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +id: String,
  +sorted: {Sort.ordered(~Core.event_id_le, fuel) == True{} : Bool}, +unique: {unique_ids(acc) == True{} : Bool}, +boundary: {previous_bound(previous, acc, fuel) == True{} : Bool}) ->
  SuccessfulUnique(Core.scan_ids(fuel, acc, previous), id):
  match fuel previous:
    case Nil{} _:
      chronological_unique_count(acc, id, unique)
    case +h <> +tail None{}:
      match acc:
        case Nil{}:
          scan_unique(tail, Some{h}, [h], id, Sort.ordered_tail(~Core.event_id_le, h, tail, sorted), unique_cons(h, Nil{}, {==}, {==}),
            Sort.and_intro(Sort.before(~Core.event_id_le, [h], h), Sort.all_le(~Core.event_id_le, h, tail),
              Sort.before_cons(~Core.event_id_le, h, Nil{}, h, Order.string_le_refl(Core.event_id(h)), {==}), Sort.ordered_head(~Core.event_id_le, h, tail, sorted)))
        case x <> xt:
          Empty.absurd(SuccessfulUnique(Core.scan_ids(h <> tail, x <> xt, None{}), id), Sort.false_clash(boundary))
    case +h <> +tail Some{+p}:
      step(h, tail, acc, p, id, String.eq(Core.event_id(h), Core.event_id(p)), Core.event_eq(h, p), sorted, unique,
        Sort.and_left(Sort.before(~Core.event_id_le, acc, p), Sort.all_le(~Core.event_id_le, p, h <> tail), boundary),
        Sort.and_right(Sort.before(~Core.event_id_le, acc, p), Sort.all_le(~Core.event_id_le, p, h <> tail), boundary), {==},
        next_unique => next_boundary => scan_unique(tail, Some{h}, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), id,
          Sort.ordered_tail(~Core.event_id_le, h, tail, sorted), next_unique, next_boundary))

def merge_unique(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, id: String) -> SuccessfulUnique(Core.merge(left, right), id):
  scan_unique(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), None{}, Nil{}, id,
    Sort.sort_ordered(List.append(&2, T.DomainEvent, left, right)), {==}, {==})

law successful_merge_has_at_most_one_occurrence_per_id:
  for left: List<&2, T.DomainEvent>
  for right: List<&2, T.DomainEvent>
  for output: List<&2, T.DomainEvent>
  for id: String
  for success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}
  {Nat.is_le(id_count(output, id), 1n) == True{} : Bool}

def successful_merge_has_at_most_one_occurrence_per_id(left, right, output, id, success):
  %success : SuccessfulUnique(_, id)
  merge_unique(left, right, id)
