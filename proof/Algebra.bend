import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Consistent.bend as Consistent
import ./Canonical.bend as Canonical
import ./MergeSets.bend as MergeSets
import ./Unique.bend as Unique
import ./Sort.bend as Sort
import ./ChronologicalSort.bend as Chron
import ./Equality.bend as Equality

# The public algebra derives success from finite input consistency. Helpers below
# may inspect an actual success equality; no public law assumes an output.
def included_bridge(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>) ->
  {Canonical.included(xs, ys) == Consistent.included(xs, ys) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.cong(Bool, Bool, tail => Bool.and(Core.exact_contains(ys, h), tail),
        Canonical.included(t, ys), Consistent.included(t, ys), included_bridge(t, ys))

def to_consistent_inclusion(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  inclusion: {Canonical.included(xs, ys) == True{} : Bool}) -> {Consistent.included(xs, ys) == True{} : Bool}:
  Equal.trans(Bool, Consistent.included(xs, ys), Canonical.included(xs, ys), True{},
    Equal.sym(Bool, Canonical.included(xs, ys), Consistent.included(xs, ys), included_bridge(xs, ys)), inclusion)

def from_consistent_inclusion(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>,
  inclusion: {Consistent.included(xs, ys) == True{} : Bool}) -> {Canonical.included(xs, ys) == True{} : Bool}:
  Equal.trans(Bool, Canonical.included(xs, ys), Consistent.included(xs, ys), True{}, included_bridge(xs, ys), inclusion)

def included_reflexive(+xs: List<&2, T.DomainEvent>) -> {Canonical.included(xs, xs) == True{} : Bool}:
  from_consistent_inclusion(xs, xs, Consistent.included_reflexive(xs))

def success_membership(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +output: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}) ->
  {Core.exact_contains(output, event) == Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event) : Bool}:
  Equal.trans(Bool, Core.exact_contains(output, event), Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)),
    Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event),
    MergeSets.successful_merge_has_exact_input_events(left, right, output, event, success),
    Equal.sym(Bool, Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event),
      Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)), MergeSets.exact_append(left, right, event)))

def inclusion_to_output(selected: List<&2, T.DomainEvent>, +left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +output: List<&2, T.DomainEvent>,
  +success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult},
  +inclusion: {Canonical.included(selected, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}) -> {Canonical.included(selected, output) == True{} : Bool}:
  match selected:
    case Nil{}:
      {==}
    case +h <> +t:
      Sort.and_intro(Core.exact_contains(output, h), Canonical.included(t, output),
        Equal.trans(Bool, Core.exact_contains(output, h), Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), True{},
          success_membership(left, right, output, h, success), Canonical.included_head(h, t, List.append(&2, T.DomainEvent, left, right), inclusion)),
        inclusion_to_output(t, left, right, output, success, Canonical.included_tail(h, t, List.append(&2, T.DomainEvent, left, right), inclusion)))

def inclusion_from_output(selected: List<&2, T.DomainEvent>, +left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +output: List<&2, T.DomainEvent>,
  +success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult},
  +inclusion: {Canonical.included(selected, output) == True{} : Bool}) -> {Canonical.included(selected, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  match selected:
    case Nil{}:
      {==}
    case +h <> +t:
      Sort.and_intro(Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), Canonical.included(t, List.append(&2, T.DomainEvent, left, right)),
        Equal.trans(Bool, Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), Core.exact_contains(output, h), True{},
          Equal.sym(Bool, Core.exact_contains(output, h), Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), success_membership(left, right, output, h, success)),
          Canonical.included_head(h, t, output, inclusion)),
        inclusion_from_output(t, left, right, output, success, Canonical.included_tail(h, t, output, inclusion)))

def successful_same_set(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +output: List<&2, T.DomainEvent>,
  +success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}) ->
  {Canonical.same_set(output, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  Sort.and_intro(Canonical.included(output, List.append(&2, T.DomainEvent, left, right)), Canonical.included(List.append(&2, T.DomainEvent, left, right), output),
    inclusion_from_output(output, left, right, output, success, included_reflexive(output)),
    inclusion_to_output(List.append(&2, T.DomainEvent, left, right), left, right, output, success, included_reflexive(List.append(&2, T.DomainEvent, left, right))))

def SortedOutput(result: T.MergeResult) -> Type:
  match result:
    case T.EventConflict{id}:
      Unit
    case T.Merged{events}:
      {Sort.ordered(~Core.event_le, events) == True{} : Bool}

def ordered_pick(condition: Bool, conflict: String, result: T.MergeResult, proof: SortedOutput(result)) -> SortedOutput(Bool.pick(T.MergeResult, condition, T.EventConflict{conflict}, result)):
  match condition:
    case False{}:
      proof
    case True{}:
      Unit{}

def ordered_scan(fuel: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, previous: Maybe<&2, T.DomainEvent>) -> SortedOutput(Core.scan_ids(fuel, acc, previous)):
  match fuel previous:
    case Nil{} _:
      Chron.sort_ordered(acc)
    case h <> tail None{}:
      ordered_scan(tail, h <> acc, Some{h})
    case +h <> +tail Some{+p}:
      ordered_pick(Bool.and(String.eq(Core.event_id(h), Core.event_id(p)), Bool.not(Core.event_eq(h, p))), Core.event_id(h),
        Core.scan_ids(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}),
        ordered_scan(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}))

def successful_ordered(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, output: List<&2, T.DomainEvent>,
  success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}) -> {Sort.ordered(~Core.event_le, output) == True{} : Bool}:
  %success : SortedOutput(_)
  ordered_scan(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{})

def member_transfer_chosen(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +target: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  found: Bool, link: {Core.event_eq(h, event) == found : Bool}, inclusion: {Canonical.included(h <> tail, target) == True{} : Bool},
  present: {Core.exact_contains(h <> tail, event) == True{} : Bool},
  continuation: {Core.exact_contains(tail, event) == True{} : Bool} -> {Core.exact_contains(target, event) == True{} : Bool}) -> {Core.exact_contains(target, event) == True{} : Bool}:
  match found:
    case True{}:
      Equal.trans(Bool, Core.exact_contains(target, event), Core.exact_contains(target, h), True{},
        Equal.sym(Bool, Core.exact_contains(target, h), Core.exact_contains(target, event),
          Equal.cong(T.DomainEvent, Bool, value => Core.exact_contains(target, value), h, event, Equality.event_equality_sound(h, event, link))),
        Canonical.included_head(h, tail, target, inclusion))
    case False{}:
      continuation(Canonical.member_tail(h, tail, event, link, present))

def member_transfer(source: List<&2, T.DomainEvent>, +target: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  +inclusion: {Canonical.included(source, target) == True{} : Bool}, present: {Core.exact_contains(source, event) == True{} : Bool}) -> {Core.exact_contains(target, event) == True{} : Bool}:
  match source:
    case Nil{}:
      Empty.absurd({Core.exact_contains(target, event) == True{} : Bool}, Sort.false_clash(present))
    case +h <> +tail:
      member_transfer_chosen(h, tail, target, event, Core.event_eq(h, event), {==}, inclusion, present,
        tail_present => member_transfer(tail, target, event, Canonical.included_tail(h, tail, target, inclusion), tail_present))

def included_transitive(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>,
  +xy: {Canonical.included(xs, ys) == True{} : Bool}, +yz: {Canonical.included(ys, zs) == True{} : Bool}) -> {Canonical.included(xs, zs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +tail:
      Sort.and_intro(Core.exact_contains(zs, h), Canonical.included(tail, zs),
        member_transfer(ys, zs, h, yz, Canonical.included_head(h, tail, ys, xy)),
        included_transitive(tail, ys, zs, Canonical.included_tail(h, tail, ys, xy), yz))

def member_append_left(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  present: {Core.exact_contains(left, event) == True{} : Bool}) -> {Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event), Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)), True{},
    MergeSets.exact_append(left, right, event),
    Equal.trans(Bool, Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)), Bool.or(True{}, Core.exact_contains(right, event)), True{},
      Equal.cong(Bool, Bool, flag => Bool.or(flag, Core.exact_contains(right, event)), Core.exact_contains(left, event), True{}, present), {==}))

def member_append_right(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +event: T.DomainEvent,
  present: {Core.exact_contains(right, event) == True{} : Bool}) -> {Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event) == True{} : Bool}:
  Equal.trans(Bool, Core.exact_contains(List.append(&2, T.DomainEvent, left, right), event), Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)), True{},
    MergeSets.exact_append(left, right, event),
    Equal.trans(Bool, Bool.or(Core.exact_contains(left, event), Core.exact_contains(right, event)), Bool.or(Core.exact_contains(left, event), True{}), True{},
      Equal.cong(Bool, Bool, flag => Bool.or(Core.exact_contains(left, event), flag), Core.exact_contains(right, event), True{}, present), Canonical.or_true_right(Core.exact_contains(left, event))))

def included_into_left(xs: List<&2, T.DomainEvent>, +left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>,
  +inclusion: {Canonical.included(xs, left) == True{} : Bool}) -> {Canonical.included(xs, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +tail:
      Sort.and_intro(Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), Canonical.included(tail, List.append(&2, T.DomainEvent, left, right)),
        member_append_left(left, right, h, Canonical.included_head(h, tail, left, inclusion)),
        included_into_left(tail, left, right, Canonical.included_tail(h, tail, left, inclusion)))

def included_into_right(xs: List<&2, T.DomainEvent>, +left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>,
  +inclusion: {Canonical.included(xs, right) == True{} : Bool}) -> {Canonical.included(xs, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +tail:
      Sort.and_intro(Core.exact_contains(List.append(&2, T.DomainEvent, left, right), h), Canonical.included(tail, List.append(&2, T.DomainEvent, left, right)),
        member_append_right(left, right, h, Canonical.included_head(h, tail, right, inclusion)),
        included_into_right(tail, left, right, Canonical.included_tail(h, tail, right, inclusion)))

def included_append_left(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>) -> {Canonical.included(left, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  included_into_left(left, left, right, included_reflexive(left))

def included_append_right(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>) -> {Canonical.included(right, List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}:
  included_into_right(right, left, right, included_reflexive(right))

def included_append_all(left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +target: List<&2, T.DomainEvent>,
  +left_in: {Canonical.included(left, target) == True{} : Bool}, +right_in: {Canonical.included(right, target) == True{} : Bool}) -> {Canonical.included(List.append(&2, T.DomainEvent, left, right), target) == True{} : Bool}:
  match left:
    case Nil{}:
      right_in
    case +h <> +tail:
      Sort.and_intro(Core.exact_contains(target, h), Canonical.included(List.append(&2, T.DomainEvent, tail, right), target),
        Canonical.included_head(h, tail, target, left_in),
        included_append_all(tail, right, target, Canonical.included_tail(h, tail, target, left_in), right_in))

def included_append_pair(+a: List<&2, T.DomainEvent>, +b: List<&2, T.DomainEvent>, +c: List<&2, T.DomainEvent>, +d: List<&2, T.DomainEvent>,
  ac: {Canonical.included(a, c) == True{} : Bool}, bd: {Canonical.included(b, d) == True{} : Bool}) -> {Canonical.included(List.append(&2, T.DomainEvent, a, b), List.append(&2, T.DomainEvent, c, d)) == True{} : Bool}:
  included_append_all(a, b, List.append(&2, T.DomainEvent, c, d), included_into_left(a, c, d, ac), included_into_right(b, c, d, bd))

def append_associative(a: List<&2, T.DomainEvent>, +b: List<&2, T.DomainEvent>, +c: List<&2, T.DomainEvent>) ->
  {List.append(&2, T.DomainEvent, List.append(&2, T.DomainEvent, a, b), c) == List.append(&2, T.DomainEvent, a, List.append(&2, T.DomainEvent, b, c)) : List<&2, T.DomainEvent>}:
  match a:
    case Nil{}:
      {==}
    case +h <> +tail:
      Equal.cong(List<&2, T.DomainEvent>, List<&2, T.DomainEvent>, rest => h <> rest,
        List.append(&2, T.DomainEvent, List.append(&2, T.DomainEvent, tail, b), c), List.append(&2, T.DomainEvent, tail, List.append(&2, T.DomainEvent, b, c)), append_associative(tail, b, c))

def included_replace_target(+xs: List<&2, T.DomainEvent>, +old: List<&2, T.DomainEvent>, +current: List<&2, T.DomainEvent>,
  equality: {old == current : List<&2, T.DomainEvent>}, inclusion: {Canonical.included(xs, old) == True{} : Bool}) -> {Canonical.included(xs, current) == True{} : Bool}:
  Equal.trans(Bool, Canonical.included(xs, current), Canonical.included(xs, old), True{},
    Equal.sym(Bool, Canonical.included(xs, old), Canonical.included(xs, current), Equal.cong(List<&2, T.DomainEvent>, Bool, target => Canonical.included(xs, target), old, current, equality)), inclusion)

def included_replace_source(+old: List<&2, T.DomainEvent>, +current: List<&2, T.DomainEvent>, +target: List<&2, T.DomainEvent>,
  equality: {old == current : List<&2, T.DomainEvent>}, inclusion: {Canonical.included(old, target) == True{} : Bool}) -> {Canonical.included(current, target) == True{} : Bool}:
  Equal.trans(Bool, Canonical.included(current, target), Canonical.included(old, target), True{},
    Equal.sym(Bool, Canonical.included(old, target), Canonical.included(current, target), Equal.cong(List<&2, T.DomainEvent>, Bool, source => Canonical.included(source, target), old, current, equality)), inclusion)

def outputs_equal(+left_a: List<&2, T.DomainEvent>, +right_a: List<&2, T.DomainEvent>, +out_a: List<&2, T.DomainEvent>,
  +left_b: List<&2, T.DomainEvent>, +right_b: List<&2, T.DomainEvent>, +out_b: List<&2, T.DomainEvent>,
  +success_a: {Core.merge(left_a, right_a) == T.Merged{out_a} : T.MergeResult}, +success_b: {Core.merge(left_b, right_b) == T.Merged{out_b} : T.MergeResult},
  in_ab: {Canonical.included(List.append(&2, T.DomainEvent, left_a, right_a), List.append(&2, T.DomainEvent, left_b, right_b)) == True{} : Bool},
  in_ba: {Canonical.included(List.append(&2, T.DomainEvent, left_b, right_b), List.append(&2, T.DomainEvent, left_a, right_a)) == True{} : Bool}) -> {out_a == out_b : List<&2, T.DomainEvent>}:
  Canonical.normal_form_unique(out_a, out_b,
    successful_ordered(left_a, right_a, out_a, success_a), successful_ordered(left_b, right_b, out_b, success_b),
    Unique.successful_merge_unique_bool(left_a, right_a, out_a, success_a), Unique.successful_merge_unique_bool(left_b, right_b, out_b, success_b),
    inclusion_to_output(out_a, left_b, right_b, out_b, success_b,
      included_transitive(out_a, List.append(&2, T.DomainEvent, left_a, right_a), List.append(&2, T.DomainEvent, left_b, right_b),
        inclusion_from_output(out_a, left_a, right_a, out_a, success_a, included_reflexive(out_a)), in_ab)),
    inclusion_to_output(out_b, left_a, right_a, out_a, success_a,
      included_transitive(out_b, List.append(&2, T.DomainEvent, left_b, right_b), List.append(&2, T.DomainEvent, left_a, right_a),
        inclusion_from_output(out_b, left_b, right_b, out_b, success_b, included_reflexive(out_b)), in_ba)))

def merge_succeeds(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>,
  valid: {Consistent.consistent(global) == True{} : Bool}, input: {Canonical.included(List.append(&2, T.DomainEvent, left, right), global) == True{} : Bool}) -> Consistent.HasOutput(Core.merge(left, right)):
  Consistent.scan_success(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{}, global, valid,
    Consistent.sort_included(List.append(&2, T.DomainEvent, left, right), global,
      to_consistent_inclusion(List.append(&2, T.DomainEvent, left, right), global, input)), {==})

def compare_results(+left_a: List<&2, T.DomainEvent>, +right_a: List<&2, T.DomainEvent>, +left_b: List<&2, T.DomainEvent>, +right_b: List<&2, T.DomainEvent>,
  in_ab: {Canonical.included(List.append(&2, T.DomainEvent, left_a, right_a), List.append(&2, T.DomainEvent, left_b, right_b)) == True{} : Bool},
  in_ba: {Canonical.included(List.append(&2, T.DomainEvent, left_b, right_b), List.append(&2, T.DomainEvent, left_a, right_a)) == True{} : Bool},
  first: T.MergeResult, second: T.MergeResult,
  +success_a: {Core.merge(left_a, right_a) == first : T.MergeResult}, +success_b: {Core.merge(left_b, right_b) == second : T.MergeResult},
  has_first: Consistent.HasOutput(first), has_second: Consistent.HasOutput(second)) -> {Core.merge(left_a, right_a) == Core.merge(left_b, right_b) : T.MergeResult}:
  match first second:
    case T.EventConflict{id} _:
      Empty.absurd({Core.merge(left_a, right_a) == Core.merge(left_b, right_b) : T.MergeResult}, has_first)
    case T.Merged{out_a} T.EventConflict{id}:
      Empty.absurd({Core.merge(left_a, right_a) == Core.merge(left_b, right_b) : T.MergeResult}, has_second)
    case T.Merged{+out_a} T.Merged{+out_b}:
      Equal.trans(T.MergeResult, Core.merge(left_a, right_a), T.Merged{out_a}, Core.merge(left_b, right_b), success_a,
        Equal.trans(T.MergeResult, T.Merged{out_a}, T.Merged{out_b}, Core.merge(left_b, right_b),
          Equal.cong(List<&2, T.DomainEvent>, T.MergeResult, events => T.Merged{events}, out_a, out_b, outputs_equal(left_a, right_a, out_a, left_b, right_b, out_b, success_a, success_b, in_ab, in_ba)),
          Equal.sym(T.MergeResult, Core.merge(left_b, right_b), T.Merged{out_b}, success_b)))

def same_inputs_same_merge(+left_a: List<&2, T.DomainEvent>, +right_a: List<&2, T.DomainEvent>,
  +left_b: List<&2, T.DomainEvent>, +right_b: List<&2, T.DomainEvent>, +global: List<&2, T.DomainEvent>,
  +valid: {Consistent.consistent(global) == True{} : Bool},
  input_a: {Canonical.included(List.append(&2, T.DomainEvent, left_a, right_a), global) == True{} : Bool},
  input_b: {Canonical.included(List.append(&2, T.DomainEvent, left_b, right_b), global) == True{} : Bool},
  in_ab: {Canonical.included(List.append(&2, T.DomainEvent, left_a, right_a), List.append(&2, T.DomainEvent, left_b, right_b)) == True{} : Bool},
  in_ba: {Canonical.included(List.append(&2, T.DomainEvent, left_b, right_b), List.append(&2, T.DomainEvent, left_a, right_a)) == True{} : Bool}) -> {Core.merge(left_a, right_a) == Core.merge(left_b, right_b) : T.MergeResult}:
  compare_results(left_a, right_a, left_b, right_b, in_ab, in_ba, Core.merge(left_a, right_a), Core.merge(left_b, right_b), {==}, {==},
    merge_succeeds(left_a, right_a, global, valid, input_a), merge_succeeds(left_b, right_b, global, valid, input_b))

def append_swap_included(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>) ->
  {Canonical.included(List.append(&2, T.DomainEvent, left, right), List.append(&2, T.DomainEvent, right, left)) == True{} : Bool}:
  included_append_all(left, right, List.append(&2, T.DomainEvent, right, left), included_append_right(right, left), included_append_left(right, left))

law merge_commutative:
  for +left: List<&2, T.DomainEvent>
  for +right: List<&2, T.DomainEvent>
  for valid: {Consistent.consistent(List.append(&2, T.DomainEvent, left, right)) == True{} : Bool}
  {Core.merge(left, right) == Core.merge(right, left) : T.MergeResult}

def merge_commutative(left, right, valid):
  same_inputs_same_merge(left, right, right, left, List.append(&2, T.DomainEvent, left, right), valid,
    included_reflexive(List.append(&2, T.DomainEvent, left, right)), append_swap_included(right, left), append_swap_included(left, right), append_swap_included(right, left))

law merge_idempotent:
  for +events: List<&2, T.DomainEvent>
  for valid: {Consistent.consistent(events) == True{} : Bool}
  {Core.merge(events, events) == Core.merge(events, Nil{}) : T.MergeResult}

def merge_idempotent(events, valid):
  same_inputs_same_merge(events, events, events, Nil{}, events, valid,
    included_append_all(events, events, events, included_reflexive(events), included_reflexive(events)),
    included_append_all(events, Nil{}, events, included_reflexive(events), {==}),
    included_into_left(List.append(&2, T.DomainEvent, events, events), events, Nil{},
      included_append_all(events, events, events, included_reflexive(events), included_reflexive(events))),
    included_append_all(events, Nil{}, List.append(&2, T.DomainEvent, events, events), included_append_left(events, events), {==}))

def merge_after_left(result: T.MergeResult, right: List<&2, T.DomainEvent>) -> T.MergeResult:
  match result:
    case T.EventConflict{id}:
      T.EventConflict{id}
    case T.Merged{events}:
      Core.merge(events, right)

def merge_after_right(left: List<&2, T.DomainEvent>, result: T.MergeResult) -> T.MergeResult:
  match result:
    case T.EventConflict{id}:
      T.EventConflict{id}
    case T.Merged{events}:
      Core.merge(left, events)

def left_pair_in_global(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>) ->
  {Canonical.included(List.append(&2, T.DomainEvent, xs, ys), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs))) == True{} : Bool}:
  included_append_all(xs, ys, List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)),
    included_append_left(xs, List.append(&2, T.DomainEvent, ys, zs)), included_into_right(ys, xs, List.append(&2, T.DomainEvent, ys, zs), included_append_left(ys, zs)))

def left_outer_in_global(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>, +xy: List<&2, T.DomainEvent>,
  success: {Core.merge(xs, ys) == T.Merged{xy} : T.MergeResult}) ->
  {Canonical.included(List.append(&2, T.DomainEvent, xy, zs), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs))) == True{} : Bool}:
  included_append_all(xy, zs, List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)),
    included_transitive(xy, List.append(&2, T.DomainEvent, xs, ys), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)),
      inclusion_from_output(xy, xs, ys, xy, success, included_reflexive(xy)), left_pair_in_global(xs, ys, zs)),
    included_into_right(zs, xs, List.append(&2, T.DomainEvent, ys, zs), included_append_right(ys, zs)))

def global_in_left_outer(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>, +xy: List<&2, T.DomainEvent>,
  success: {Core.merge(xs, ys) == T.Merged{xy} : T.MergeResult}) ->
  {Canonical.included(List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), List.append(&2, T.DomainEvent, xy, zs)) == True{} : Bool}:
  included_replace_source(List.append(&2, T.DomainEvent, List.append(&2, T.DomainEvent, xs, ys), zs), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), List.append(&2, T.DomainEvent, xy, zs),
    append_associative(xs, ys, zs),
    included_append_pair(List.append(&2, T.DomainEvent, xs, ys), zs, xy, zs,
      inclusion_to_output(List.append(&2, T.DomainEvent, xs, ys), xs, ys, xy, success, included_reflexive(List.append(&2, T.DomainEvent, xs, ys))), included_reflexive(zs)))

def right_outer_in_global(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>, +yz: List<&2, T.DomainEvent>,
  success: {Core.merge(ys, zs) == T.Merged{yz} : T.MergeResult}) ->
  {Canonical.included(List.append(&2, T.DomainEvent, xs, yz), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs))) == True{} : Bool}:
  included_append_pair(xs, yz, xs, List.append(&2, T.DomainEvent, ys, zs), included_reflexive(xs),
    inclusion_from_output(yz, ys, zs, yz, success, included_reflexive(yz)))

def global_in_right_outer(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>, +yz: List<&2, T.DomainEvent>,
  success: {Core.merge(ys, zs) == T.Merged{yz} : T.MergeResult}) ->
  {Canonical.included(List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), List.append(&2, T.DomainEvent, xs, yz)) == True{} : Bool}:
  included_append_pair(xs, List.append(&2, T.DomainEvent, ys, zs), xs, yz, included_reflexive(xs),
    inclusion_to_output(List.append(&2, T.DomainEvent, ys, zs), ys, zs, yz, success, included_reflexive(List.append(&2, T.DomainEvent, ys, zs))))

def associative_results(+xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +zs: List<&2, T.DomainEvent>,
  +valid: {Consistent.consistent(List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs))) == True{} : Bool},
  first: T.MergeResult, second: T.MergeResult,
  +success_xy: {Core.merge(xs, ys) == first : T.MergeResult}, +success_yz: {Core.merge(ys, zs) == second : T.MergeResult},
  has_first: Consistent.HasOutput(first), has_second: Consistent.HasOutput(second)) ->
  {merge_after_left(Core.merge(xs, ys), zs) == merge_after_right(xs, Core.merge(ys, zs)) : T.MergeResult}:
  match first second:
    case T.EventConflict{id} _:
      Empty.absurd({merge_after_left(Core.merge(xs, ys), zs) == merge_after_right(xs, Core.merge(ys, zs)) : T.MergeResult}, has_first)
    case T.Merged{xy} T.EventConflict{id}:
      Empty.absurd({merge_after_left(Core.merge(xs, ys), zs) == merge_after_right(xs, Core.merge(ys, zs)) : T.MergeResult}, has_second)
    case T.Merged{+xy} T.Merged{+yz}:
      Equal.trans(T.MergeResult, merge_after_left(Core.merge(xs, ys), zs), Core.merge(xy, zs), merge_after_right(xs, Core.merge(ys, zs)),
        Equal.cong(T.MergeResult, T.MergeResult, result => merge_after_left(result, zs), Core.merge(xs, ys), T.Merged{xy}, success_xy),
        Equal.trans(T.MergeResult, Core.merge(xy, zs), Core.merge(xs, yz), merge_after_right(xs, Core.merge(ys, zs)),
          same_inputs_same_merge(xy, zs, xs, yz, List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), valid,
            left_outer_in_global(xs, ys, zs, xy, success_xy), right_outer_in_global(xs, ys, zs, yz, success_yz),
            included_transitive(List.append(&2, T.DomainEvent, xy, zs), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), List.append(&2, T.DomainEvent, xs, yz),
              left_outer_in_global(xs, ys, zs, xy, success_xy), global_in_right_outer(xs, ys, zs, yz, success_yz)),
            included_transitive(List.append(&2, T.DomainEvent, xs, yz), List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), List.append(&2, T.DomainEvent, xy, zs),
              right_outer_in_global(xs, ys, zs, yz, success_yz), global_in_left_outer(xs, ys, zs, xy, success_xy))),
          Equal.sym(T.MergeResult, merge_after_right(xs, Core.merge(ys, zs)), Core.merge(xs, yz),
            Equal.cong(T.MergeResult, T.MergeResult, result => merge_after_right(xs, result), Core.merge(ys, zs), T.Merged{yz}, success_yz))))

law merge_associative:
  for +xs: List<&2, T.DomainEvent>
  for +ys: List<&2, T.DomainEvent>
  for +zs: List<&2, T.DomainEvent>
  for +valid: {Consistent.consistent(List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs))) == True{} : Bool}
  {merge_after_left(Core.merge(xs, ys), zs) == merge_after_right(xs, Core.merge(ys, zs)) : T.MergeResult}

def merge_associative(xs, ys, zs, valid):
  associative_results(xs, ys, zs, valid, Core.merge(xs, ys), Core.merge(ys, zs), {==}, {==},
    merge_succeeds(xs, ys, List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), valid, left_pair_in_global(xs, ys, zs)),
    merge_succeeds(ys, zs, List.append(&2, T.DomainEvent, xs, List.append(&2, T.DomainEvent, ys, zs)), valid, included_append_right(xs, List.append(&2, T.DomainEvent, ys, zs))))

# These applications exercise the universal laws on faithful nonempty inputs,
# including reordered and repeated deliveries, rather than empty-only examples.
law nonempty_commutativity_application:
  {Core.merge([Consistent.witness_b(), Consistent.witness_a()], [Consistent.witness_a()]) ==
    Core.merge([Consistent.witness_a()], [Consistent.witness_b(), Consistent.witness_a()]) : T.MergeResult}

def nonempty_commutativity_application():
  merge_commutative([Consistent.witness_b(), Consistent.witness_a()], [Consistent.witness_a()], {==})

law nonempty_associativity_application:
  {merge_after_left(Core.merge([Consistent.witness_b()], [Consistent.witness_a()]), [Consistent.witness_b(), Consistent.witness_a()]) ==
    merge_after_right([Consistent.witness_b()], Core.merge([Consistent.witness_a()], [Consistent.witness_b(), Consistent.witness_a()])) : T.MergeResult}

def nonempty_associativity_application():
  merge_associative([Consistent.witness_b()], [Consistent.witness_a()], [Consistent.witness_b(), Consistent.witness_a()], {==})

law nonempty_idempotence_application:
  {Core.merge([Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()], [Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()]) ==
    Core.merge([Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()], Nil{}) : T.MergeResult}

def nonempty_idempotence_application():
  merge_idempotent([Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()], {==})

# Raw delivery sequences need not themselves be canonical. Idempotence means
# equal canonical event sets, not preserving duplicate or out-of-order arrays.
law duplicate_sequence_normalizes_to_canonical_set:
  {Core.merge([Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()], [Consistent.witness_b(), Consistent.witness_a(), Consistent.witness_a()]) ==
    T.Merged{[Consistent.witness_a(), Consistent.witness_b()]} : T.MergeResult}

def duplicate_sequence_normalizes_to_canonical_set():
  {==}
