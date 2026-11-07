import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as Core
import ./Equality.bend as Equality
import ./Membership.bend as Membership

# Complete modeled event-set preservation through the actual merge implementation.
# A successful result is observed, never assumed to have the desired members.

def event_matches(target: T.DomainEvent, event: T.DomainEvent) -> Bool:
  Core.event_eq(event, target)

def ExactPreviousCovered(previous: Maybe<&2, T.DomainEvent>, acc: List<&2, T.DomainEvent>) -> Data:
  match previous:
    case None{}:
      Unit
    case Some{event}:
      {Core.exact_contains(acc, event) == True{} : Bool}

def SuccessfulContents(result: T.MergeResult, target: T.DomainEvent, expected: Bool) -> Type:
  match result:
    case T.EventConflict{conflictId}:
      Unit
    case T.Merged{events}:
      {Core.exact_contains(events, target) == expected : Bool}

def boolean_absorption(condition: Bool, member: Bool, implication: {condition == True{} : Bool} -> {member == True{} : Bool}) -> {Bool.or(condition, member) == member : Bool}:
  match condition:
    case False{}:
      {==}
    case True{}:
      Equal.sym(Bool, member, True{}, implication({==}))

def exact_membership_bridge(events: List<&2, T.DomainEvent>, +target: T.DomainEvent) -> {Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, events) == Core.exact_contains(events, target) : Bool}:
  match events:
    case Nil{}:
      {==}
    case +h <> t:
      Equal.cong(Bool, Bool, member => Bool.or(Core.event_eq(h, target), member),
        Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, t), Core.exact_contains(t, target), exact_membership_bridge(t, target))

def id_sort_preserves_exact_events(+events: List<&2, T.DomainEvent>, +target: T.DomainEvent) -> {Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target) == Core.exact_contains(events, target) : Bool}:
  Equal.trans(Bool,
    Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Core.exact_contains(events, target),
    Equal.sym(Bool, Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target), exact_membership_bridge(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target)),
    Equal.trans(Bool,
      Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, events), Core.exact_contains(events, target),
      Membership.sort(~T.DomainEvent, ~T.DomainEvent, ~event_matches, ~Core.event_id_le, target, events), exact_membership_bridge(events, target)))

def chronological_sort_preserves_exact_events(+events: List<&2, T.DomainEvent>, +target: T.DomainEvent) -> {Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_le, events), target) == Core.exact_contains(events, target) : Bool}:
  Equal.trans(Bool,
    Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_le, events), target), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Core.exact_contains(events, target),
    Equal.sym(Bool, Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_le, events), target), exact_membership_bridge(List.sort(~T.DomainEvent, ~Core.event_le, events), target)),
    Equal.trans(Bool,
      Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~event_matches, target, events), Core.exact_contains(events, target),
      Membership.sort(~T.DomainEvent, ~T.DomainEvent, ~event_matches, ~Core.event_le, target, events), exact_membership_bridge(events, target)))

def exact_append(xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +target: T.DomainEvent) -> {Core.exact_contains(List.append(&2, T.DomainEvent, xs, ys), target) == Bool.or(Core.exact_contains(xs, target), Core.exact_contains(ys, target)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        Core.exact_contains(List.append(&2, T.DomainEvent, h <> t, ys), target), Bool.or(Core.event_eq(h, target), Bool.or(Core.exact_contains(t, target), Core.exact_contains(ys, target))),
        Bool.or(Core.exact_contains(h <> t, target), Core.exact_contains(ys, target)),
        Equal.cong(Bool, Bool, member => Bool.or(Core.event_eq(h, target), member), Core.exact_contains(List.append(&2, T.DomainEvent, t, ys), target),
          Bool.or(Core.exact_contains(t, target), Core.exact_contains(ys, target)), exact_append(t, ys, target)),
        Membership.or_associative(Core.event_eq(h, target), Core.exact_contains(t, target), Core.exact_contains(ys, target)))

def exact_member_absorption(+events: List<&2, T.DomainEvent>, +present: T.DomainEvent, +target: T.DomainEvent, covered: {Core.exact_contains(events, present) == True{} : Bool}) -> {Bool.or(Core.event_eq(present, target), Core.exact_contains(events, target)) == Core.exact_contains(events, target) : Bool}:
  boolean_absorption(Core.event_eq(present, target), Core.exact_contains(events, target),
    same => Equal.trans(Bool, Core.exact_contains(events, target), Core.exact_contains(events, present), True{},
      Equal.cong(T.DomainEvent, Bool, event => Core.exact_contains(events, event), target, present,
        Equal.sym(T.DomainEvent, present, target, Equality.event_equality_sound(present, target, same))), covered))

def exact_member_self_head(+event: T.DomainEvent, +rest: List<&2, T.DomainEvent>) -> {Core.exact_contains(event <> rest, event) == True{} : Bool}:
  Equal.cong(Bool, Bool, same => Bool.or(same, Core.exact_contains(rest, event)), Core.event_eq(event, event), True{}, Equality.event_equality_reflexive(event))

def ScanProof.shuffle(+head: Bool, +tail: Bool, +acc: Bool) ->
  {Bool.or(tail, Bool.or(head, acc)) == Bool.or(Bool.or(head, tail), acc) : Bool}:
  Equal.trans(Bool, Bool.or(tail, Bool.or(head, acc)), Bool.or(head, Bool.or(tail, acc)), Bool.or(Bool.or(head, tail), acc),
    Membership.or_move_left(tail, head, acc), Membership.or_associative(head, tail, acc))

def ScanProof.rewrite_contents(result: T.MergeResult, +target: T.DomainEvent, a: Bool, b: Bool,
  equality: {a == b : Bool}, proof: SuccessfulContents(result, target, a)) -> SuccessfulContents(result, target, b):
  match result:
    case T.EventConflict{conflictId}:
      Unit{}
    case T.Merged{events}:
      Equal.trans(Bool, Core.exact_contains(events, target), a, b, proof, equality)

def ExactScan.step(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +target: T.DomainEvent, same: Bool, equal: Bool,
  actual_equal: {equal == Core.event_eq(h, previous) : Bool}, covered: {Core.exact_contains(acc, previous) == True{} : Bool},
  continuation: {Core.exact_contains(Core.unique_put(h, acc, same), h) == True{} : Bool} -> SuccessfulContents(Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h}), target, Bool.or(Core.exact_contains(tail, target), Core.exact_contains(Core.unique_put(h, acc, same), target)))) ->
  SuccessfulContents(Bool.pick(T.MergeResult, Bool.and(same, Bool.not(equal)), T.EventConflict{Core.event_id(h)}, Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h})), target, Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target))):
  match same equal:
    case False{} False{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        continuation(exact_member_self_head(h, acc)))
    case False{} True{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        continuation(exact_member_self_head(h, acc)))
    case True{} False{}:
      Unit{}
    case True{} True{}:
      same_event = Equality.event_equality_sound(h, previous, Equal.sym(Bool, True{}, Core.event_eq(h, previous), actual_equal))
      +covered_head = Equal.trans(Bool, Core.exact_contains(acc, h), Core.exact_contains(acc, previous), True{},
        Equal.cong(T.DomainEvent, Bool, event => Core.exact_contains(acc, event), h, previous, same_event), covered)
      ScanProof.rewrite_contents(Core.scan_ids(tail, acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        Equal.trans(Bool,
          Bool.or(Core.exact_contains(tail, target), Core.exact_contains(acc, target)), Bool.or(Core.exact_contains(tail, target), Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target))),
          Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
          Equal.cong(Bool, Bool, member => Bool.or(Core.exact_contains(tail, target), member), Core.exact_contains(acc, target), Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target)),
            Equal.sym(Bool, Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target)), Core.exact_contains(acc, target), exact_member_absorption(acc, h, target, covered_head))),
          ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target))), continuation(covered_head))

def scan_preserves_exact_events(fuel: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, previous: Maybe<&2, T.DomainEvent>, +target: T.DomainEvent, covered: ExactPreviousCovered(previous, acc)) -> SuccessfulContents(Core.scan_ids(fuel, acc, previous), target, Bool.or(Core.exact_contains(fuel, target), Core.exact_contains(acc, target))):
  match fuel previous:
    case Nil{} _:
      chronological_sort_preserves_exact_events(acc, target)
    case +h <> +tail None{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        scan_preserves_exact_events(tail, h <> acc, Some{h}, target, exact_member_self_head(h, acc)))
    case +h <> +tail Some{+p}:
      ExactScan.step(h, tail, acc, p, target, String.eq(Core.event_id(h), Core.event_id(p)), Core.event_eq(h, p), {==}, covered,
        next_covered => scan_preserves_exact_events(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}, target, next_covered))

def merge_preserves_exact_events(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +target: T.DomainEvent) -> SuccessfulContents(Core.merge(left, right), target, Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target))):
  ScanProof.rewrite_contents(Core.merge(left, right), target,
    Bool.or(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), False{}),
    Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)),
    Equal.trans(Bool,
      Bool.or(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), False{}), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target),
      Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)),
      Membership.or_false_right(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target)),
      Equal.trans(Bool, Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), Core.exact_contains(List.append(&2, T.DomainEvent, left, right), target),
        Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)), id_sort_preserves_exact_events(List.append(&2, T.DomainEvent, left, right), target), exact_append(left, right, target))),
    scan_preserves_exact_events(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{}, target, Unit{}))

def successful_merge_has_exact_input_events(left: List<&2, T.DomainEvent>, right: List<&2, T.DomainEvent>, output: List<&2, T.DomainEvent>, target: T.DomainEvent, success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}) -> {Core.exact_contains(output, target) == Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)) : Bool}:
  %success : SuccessfulContents(_, target, Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)))
  merge_preserves_exact_events(left, right, target)
