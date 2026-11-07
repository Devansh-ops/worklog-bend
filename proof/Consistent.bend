import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Order.bend as Order
import ./Equality.bend as Equality
import ./Membership.bend as Membership

# These finite predicates describe inputs, not a successful algorithm result.
def agrees(+a: T.DomainEvent, +b: T.DomainEvent) -> Bool:
  Bool.or(Bool.not(String.eq(Core.event_id(a), Core.event_id(b))), Core.event_eq(a, b))

def compatible(+event: T.DomainEvent, events: List<&2, T.DomainEvent>) -> Bool:
  match events:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(agrees(event, h), compatible(event, t))

def consistent(events: List<&2, T.DomainEvent>) -> Bool:
  match events:
    case Nil{}:
      True{}
    case +h <> +t:
      Bool.and(compatible(h, t), consistent(t))

def included(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(Core.exact_contains(ys, h), included(t, ys))

def and_left(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, Order.false_not_true(equality))
    case True{}:
      {==}

def and_right(a: Bool, b: Bool, equality: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      Empty.absurd({b == True{} : Bool}, Order.false_not_true(equality))
    case True{}:
      equality

def and_intro(+a: Bool, +b: Bool, left: {a == True{} : Bool}, right: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  Equal.trans(Bool, Bool.and(a, b), b, True{}, Equal.cong(Bool, Bool, flag => Bool.and(flag, b), a, True{}, left), right)

def or_true_right(value: Bool) -> {Bool.or(value, True{}) == True{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def event_equality_detected(+a: T.DomainEvent, +b: T.DomainEvent, same: {a == b : T.DomainEvent}) -> {Core.event_eq(a, b) == True{} : Bool}:
  Equal.trans(Bool, Core.event_eq(a, b), Core.event_eq(b, b), True{},
    Equal.cong(T.DomainEvent, Bool, event => Core.event_eq(event, b), a, b, same), Equality.event_equality_reflexive(b))

def event_equality_reverse(+a: T.DomainEvent, +b: T.DomainEvent, same: {Core.event_eq(a, b) == True{} : Bool}) -> {Core.event_eq(b, a) == True{} : Bool}:
  event_equality_detected(b, a, Equal.sym(T.DomainEvent, a, b, Equality.event_equality_sound(a, b, same)))

def agrees_from_equal(+a: T.DomainEvent, +b: T.DomainEvent, equality: {Core.event_eq(a, b) == True{} : Bool}) -> {agrees(a, b) == True{} : Bool}:
  Equal.trans(Bool, agrees(a, b), Bool.or(Bool.not(String.eq(Core.event_id(a), Core.event_id(b))), True{}), True{},
    Equal.cong(Bool, Bool, flag => Bool.or(Bool.not(String.eq(Core.event_id(a), Core.event_id(b))), flag), Core.event_eq(a, b), True{}, equality),
    or_true_right(Bool.not(String.eq(Core.event_id(a), Core.event_id(b)))))

def agrees_same(+a: T.DomainEvent, +b: T.DomainEvent, agreement: {agrees(a, b) == True{} : Bool},
  same_id: {String.eq(Core.event_id(a), Core.event_id(b)) == True{} : Bool}) -> {Core.event_eq(a, b) == True{} : Bool}:
  Equal.trans(Bool, Core.event_eq(a, b), agrees(a, b), True{},
    Equal.sym(Bool, agrees(a, b), Core.event_eq(a, b),
      Equal.cong(Bool, Bool, flag => Bool.or(Bool.not(flag), Core.event_eq(a, b)), String.eq(Core.event_id(a), Core.event_id(b)), True{}, same_id)), agreement)

def agrees_reverse_chosen(+a: T.DomainEvent, +b: T.DomainEvent, same: Bool,
  link: {String.eq(Core.event_id(b), Core.event_id(a)) == same : Bool}, agreement: {agrees(a, b) == True{} : Bool}) -> {agrees(b, a) == True{} : Bool}:
  match same:
    case False{}:
      Equal.trans(Bool, agrees(b, a), Bool.or(True{}, Core.event_eq(b, a)), True{},
        Equal.cong(Bool, Bool, flag => Bool.or(Bool.not(flag), Core.event_eq(b, a)), String.eq(Core.event_id(b), Core.event_id(a)), False{}, link), {==})
    case True{}:
      agrees_from_equal(b, a, event_equality_reverse(a, b,
        agrees_same(a, b, agreement, Order.string_eq_true_reverse(Core.event_id(b), Core.event_id(a), link))))

def agrees_reverse(+a: T.DomainEvent, +b: T.DomainEvent, agreement: {agrees(a, b) == True{} : Bool}) -> {agrees(b, a) == True{} : Bool}:
  agrees_reverse_chosen(a, b, String.eq(Core.event_id(b), Core.event_id(a)), {==}, agreement)

def member_tail(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  different: {Core.event_eq(h, event) == False{} : Bool}, present: {Core.exact_contains(h <> t, event) == True{} : Bool}) -> {Core.exact_contains(t, event) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(t, event), Core.exact_contains(h <> t, event), True{},
    Equal.sym(Bool, Core.exact_contains(h <> t, event), Core.exact_contains(t, event),
      Equal.cong(Bool, Bool, flag => Bool.or(flag, Core.exact_contains(t, event)), Core.event_eq(h, event), False{}, different)), present)

def compatible_member_chosen(+event: T.DomainEvent, +h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +target: T.DomainEvent,
  found: Bool, link: {Core.event_eq(h, target) == found : Bool}, compatibility: {compatible(event, h <> t) == True{} : Bool},
  present: {Core.exact_contains(h <> t, target) == True{} : Bool},
  continuation: {Core.exact_contains(t, target) == True{} : Bool} -> {agrees(event, target) == True{} : Bool}) -> {agrees(event, target) == True{} : Bool}:
  match found:
    case True{}:
      Equal.trans(Bool, agrees(event, target), agrees(event, h), True{},
        Equal.sym(Bool, agrees(event, h), agrees(event, target),
          Equal.cong(T.DomainEvent, Bool, value => agrees(event, value), h, target, Equality.event_equality_sound(h, target, link))),
        and_left(agrees(event, h), compatible(event, t), compatibility))
    case False{}:
      continuation(member_tail(h, t, target, link, present))

def compatible_member(+event: T.DomainEvent, events: List<&2, T.DomainEvent>, +target: T.DomainEvent,
  +compatibility: {compatible(event, events) == True{} : Bool}, present: {Core.exact_contains(events, target) == True{} : Bool}) -> {agrees(event, target) == True{} : Bool}:
  match events:
    case Nil{}:
      Empty.absurd({agrees(event, target) == True{} : Bool}, Order.false_not_true(present))
    case +h <> +t:
      compatible_member_chosen(event, h, t, target, Core.event_eq(h, target), {==}, compatibility, present,
        tail_present => compatible_member(event, t, target, and_right(agrees(event, h), compatible(event, t), compatibility), tail_present))

def global_member_chosen(+h: T.DomainEvent, +t: List<&2, T.DomainEvent>, +event: T.DomainEvent, found: Bool,
  link: {Core.event_eq(h, event) == found : Bool}, +valid: {consistent(h <> t) == True{} : Bool},
  present: {Core.exact_contains(h <> t, event) == True{} : Bool},
  continuation: {Core.exact_contains(t, event) == True{} : Bool} -> {compatible(event, t) == True{} : Bool}) -> {compatible(event, h <> t) == True{} : Bool}:
  match found:
    case True{}:
      Equal.trans(Bool, compatible(event, h <> t), compatible(h, h <> t), True{},
        Equal.sym(Bool, compatible(h, h <> t), compatible(event, h <> t),
          Equal.cong(T.DomainEvent, Bool, value => compatible(value, h <> t), h, event, Equality.event_equality_sound(h, event, link))),
        and_intro(agrees(h, h), compatible(h, t), agrees_from_equal(h, h, Equality.event_equality_reflexive(h)),
          and_left(compatible(h, t), consistent(t), valid)))
    case False{}:
      +tail_present = member_tail(h, t, event, link, present)
      and_intro(agrees(event, h), compatible(event, t),
        agrees_reverse(h, event, compatible_member(h, t, event, and_left(compatible(h, t), consistent(t), valid), tail_present)),
        continuation(tail_present))

def global_member_compatible(global: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  +valid: {consistent(global) == True{} : Bool}, present: {Core.exact_contains(global, event) == True{} : Bool}) -> {compatible(event, global) == True{} : Bool}:
  match global:
    case Nil{}:
      Empty.absurd({compatible(event, Nil{}) == True{} : Bool}, Order.false_not_true(present))
    case +h <> +t:
      global_member_chosen(h, t, event, Core.event_eq(h, event), {==}, valid, present,
        tail_present => global_member_compatible(t, event, and_right(compatible(h, t), consistent(t), valid), tail_present))

def global_members_agree(+global: List<&2, T.DomainEvent>, +a: T.DomainEvent, +b: T.DomainEvent,
  valid: {consistent(global) == True{} : Bool}, a_present: {Core.exact_contains(global, a) == True{} : Bool},
  b_present: {Core.exact_contains(global, b) == True{} : Bool}) -> {agrees(a, b) == True{} : Bool}:
  compatible_member(a, global, b, global_member_compatible(global, a, valid, a_present), b_present)

def not_member(global: List<&2, T.DomainEvent>, event: T.DomainEvent) -> Bool:
  Bool.not(Core.exact_contains(global, event))

def de_morgan(a: Bool, b: Bool) -> {Bool.and(a, Bool.not(b)) == Bool.not(Bool.or(Bool.not(a), b)) : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def included_complement(xs: List<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>) ->
  {included(xs, global) == Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, xs)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool, included(h <> t, global),
        Bool.and(Core.exact_contains(global, h), Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, t))),
        Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, h <> t)),
        Equal.cong(Bool, Bool, tail => Bool.and(Core.exact_contains(global, h), tail), included(t, global),
          Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, t)), included_complement(t, global)),
        de_morgan(Core.exact_contains(global, h), Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, t)))

def sort_included(+xs: List<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>, inclusion: {included(xs, global) == True{} : Bool}) ->
  {included(List.sort(~T.DomainEvent, ~Core.event_id_le, xs), global) == True{} : Bool}:
  Equal.trans(Bool, included(List.sort(~T.DomainEvent, ~Core.event_id_le, xs), global),
    Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, List.sort(~T.DomainEvent, ~Core.event_id_le, xs))), True{},
    included_complement(List.sort(~T.DomainEvent, ~Core.event_id_le, xs), global),
    Equal.trans(Bool, Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, List.sort(~T.DomainEvent, ~Core.event_id_le, xs))),
      Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, xs)), True{},
      Equal.cong(Bool, Bool, flag => Bool.not(flag),
        Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, List.sort(~T.DomainEvent, ~Core.event_id_le, xs)),
        Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, xs),
        Membership.sort(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, ~Core.event_id_le, global, xs)),
      Equal.trans(Bool, Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, xs)), included(xs, global), True{},
        Equal.sym(Bool, included(xs, global), Bool.not(Membership.any(~T.DomainEvent, ~List<&2, T.DomainEvent>, ~not_member, global, xs)), included_complement(xs, global)), inclusion)))

def member_self(+event: T.DomainEvent, +tail: List<&2, T.DomainEvent>) -> {Core.exact_contains(event <> tail, event) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(event <> tail, event), Bool.or(True{}, Core.exact_contains(tail, event)), True{},
    Equal.cong(Bool, Bool, flag => Bool.or(flag, Core.exact_contains(tail, event)), Core.event_eq(event, event), True{}, Equality.event_equality_reflexive(event)), {==})

def member_weaken(+head: T.DomainEvent, +events: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  present: {Core.exact_contains(events, event) == True{} : Bool}) -> {Core.exact_contains(head <> events, event) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(head <> events, event), Bool.or(Core.event_eq(head, event), True{}), True{},
    Equal.cong(Bool, Bool, flag => Bool.or(Core.event_eq(head, event), flag), Core.exact_contains(events, event), True{}, present),
    or_true_right(Core.event_eq(head, event)))

def included_weaken(+head: T.DomainEvent, xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  +inclusion: {included(xs, ys) == True{} : Bool}) -> {included(xs, head <> ys) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      and_intro(Core.exact_contains(head <> ys, h), included(t, head <> ys),
        member_weaken(head, ys, h, and_left(Core.exact_contains(ys, h), included(t, ys), inclusion)),
        included_weaken(head, t, ys, and_right(Core.exact_contains(ys, h), included(t, ys), inclusion)))

def included_reflexive(xs: List<&2, T.DomainEvent>) -> {included(xs, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      and_intro(Core.exact_contains(h <> t, h), included(t, h <> t), member_self(h, t), included_weaken(h, t, t, included_reflexive(t)))

def previous_in(previous: Maybe<&2, T.DomainEvent>, global: List<&2, T.DomainEvent>) -> Bool:
  match previous:
    case None{}:
      True{}
    case Some{event}:
      Core.exact_contains(global, event)

def no_conflict(+same: Bool, +equal: Bool, valid: {Bool.or(Bool.not(same), equal) == True{} : Bool}) -> {Bool.and(same, Bool.not(equal)) == False{} : Bool}:
  match same equal:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      Empty.absurd({Bool.and(True{}, Bool.not(False{})) == False{} : Bool}, Order.false_not_true(valid))
    case True{} True{}:
      {==}

def HasOutput(result: T.MergeResult) -> Type:
  match result:
    case T.Merged{events}:
      Unit
    case T.EventConflict{id}:
      Empty

def scan_success(fuel: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +previous: Maybe<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>,
  +valid: {consistent(global) == True{} : Bool}, +inclusion: {included(fuel, global) == True{} : Bool},
  prior: {previous_in(previous, global) == True{} : Bool}) -> HasOutput(Core.scan_ids(fuel, acc, previous)):
  match fuel previous:
    case Nil{} _:
      Unit{}
    case +h <> +t None{}:
      scan_success(t, h <> acc, Some{h}, global, valid,
        and_right(Core.exact_contains(global, h), included(t, global), inclusion),
        and_left(Core.exact_contains(global, h), included(t, global), inclusion))
    case +h <> +t Some{+p}:
      %Equal.sym(Bool, Bool.and(String.eq(Core.event_id(h), Core.event_id(p)), Bool.not(Core.event_eq(h, p))), False{},
        no_conflict(String.eq(Core.event_id(h), Core.event_id(p)), Core.event_eq(h, p),
          global_members_agree(global, h, p, valid, and_left(Core.exact_contains(global, h), included(t, global), inclusion), prior))) :
        HasOutput(Bool.pick(T.MergeResult, _, T.EventConflict{Core.event_id(h)}, Core.scan_ids(t, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h})))
      scan_success(t, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}, global, valid,
        and_right(Core.exact_contains(global, h), included(t, global), inclusion),
        and_left(Core.exact_contains(global, h), included(t, global), inclusion))

def Outputs(+result: T.MergeResult) -> Type:
  &events: List<&2, T.DomainEvent> -> {result == T.Merged{events} : T.MergeResult}

def output_exists(+result: T.MergeResult, success: HasOutput(result)) -> Outputs(result):
  match result:
    case T.Merged{+events}:
      (events, {==})
    case T.EventConflict{id}:
      Empty.absurd(Outputs(T.EventConflict{id}), success)

def merge_success_from_global(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>,
  valid: {consistent(global) == True{} : Bool}, inclusion: {included(List.append(&2, T.DomainEvent, left, right), global) == True{} : Bool}) -> Outputs(Core.merge(left, right)):
  output_exists(Core.merge(left, right),
    scan_success(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{}, global, valid,
      sort_included(List.append(&2, T.DomainEvent, left, right), global, inclusion), {==}))

def merge_success(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>,
  valid: {consistent(List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}) -> Outputs(Core.merge(left, right)):
  merge_success_from_global(left, right, List.append(&2, T.DomainEvent, left, right), valid,
    included_reflexive(List.append(&2, T.DomainEvent, left, right)))

def witness_a() -> T.DomainEvent:
  T.Ev{"e-a", "2026-11-01T09:00:00.000Z", "2026-11-01",
    T.Created{"T-aaa111", "Synthetic A", T.STodo{}, T.PNormal{}, Nil{}, False{}},
    "{\"id\":\"e-a\",\"private\":false,\"priority\":\"normal\",\"status\":\"todo\",\"tags\":[],\"taskId\":\"T-aaa111\",\"title\":\"Synthetic A\",\"ts\":\"2026-11-01T09:00:00.000Z\",\"type\":\"task.create\"}"}

def witness_b() -> T.DomainEvent:
  T.Ev{"e-b", "2026-11-01T10:00:00.000Z", "2026-11-01",
    T.Created{"T-bbb222", "Synthetic B", T.STodo{}, T.PNormal{}, Nil{}, False{}},
    "{\"id\":\"e-b\",\"private\":false,\"priority\":\"normal\",\"status\":\"todo\",\"tags\":[],\"taskId\":\"T-bbb222\",\"title\":\"Synthetic B\",\"ts\":\"2026-11-01T10:00:00.000Z\",\"type\":\"task.create\"}"}

def forge(event: T.DomainEvent) -> T.DomainEvent:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      T.Ev{id, ts, day, T.Created{"T-aaa111", "Different typed content", T.STodo{}, T.PNormal{}, Nil{}, False{}}, canonical}

def witness_forged() -> T.DomainEvent:
  forge(witness_a())

law nonempty_consistent_global_exists:
  {Bool.and(consistent([witness_a(), witness_b(), witness_a()]),
    included([witness_b(), witness_a(), witness_a()], [witness_a(), witness_b(), witness_a()])) == True{} : Bool}

def nonempty_consistent_global_exists():
  {==}

law nonempty_merge_success_is_constructed:
  exs events: List<&2, T.DomainEvent>
  {Core.merge([witness_b(), witness_a()], [witness_a()]) == T.Merged{events} : T.MergeResult}

def nonempty_merge_success_is_constructed():
  merge_success_from_global([witness_b(), witness_a()], [witness_a()], [witness_a(), witness_b(), witness_a()], {==}, {==})

law conflicting_typed_content_is_not_consistent:
  {consistent([witness_a(), witness_forged()]) == False{} : Bool}

def conflicting_typed_content_is_not_consistent():
  {==}

law conflicting_typed_content_really_rejects:
  {Core.merge([witness_a()], [witness_forged()]) == T.EventConflict{"e-a"} : T.MergeResult}

def conflicting_typed_content_really_rejects():
  {==}
