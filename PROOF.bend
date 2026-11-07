import Base
import ./LAWS.bend as Laws
import ./bend/Types.bend as T
import ./bend/Core.bend as Core
import ./bend/Publication.bend as Publication
import ./bend/Reports.bend as Reports
import ./proof/Membership.bend as Membership
import ./proof/Count.bend as Count
import ./proof/Unique.bend as Unique
import ./proof/Sort.bend as Sort
import ./proof/ChronologicalSort.bend as ChronologicalSort
import ./proof/Canonical.bend as Canonical

def Laws.future_schema_refused_witness():
  {==}

def Laws.changed_plan_refused_witness():
  {==}

def Laws.reminder_disabled_witness():
  {==}

def Laws.reminder_complete_day_witness():
  {==}

def Laws.collision_refusal_witness():
  {==}

def Laws.complete_content_merge_witness():
  {==}

def Laws.clock_rollback_command_is_rejected():
  {==}

def Laws.accepted_complete_command_exists():
  {==}

def Laws.word_order_reflexive(n, w):
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          match b:
            case False{}:
              Equal.cong(Cmp, Cmp, c => Word.cmp.fin(False{}, False{}, c),
                Word.cmp(p, t, t), EQ{}, Laws.word_order_reflexive(p, t))
            case True{}:
              Equal.cong(Cmp, Cmp, c => Word.cmp.fin(True{}, True{}, c),
                Word.cmp(p, t, t), EQ{}, Laws.word_order_reflexive(p, t))

def Laws.u32_order_reflexive(x):
  match x:
    case U32{w}:
      Laws.word_order_reflexive(32n, w)

def Laws.string_order_reflexive(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{x}, t}:
      Equal.trans(Cmp, String.order.go(t, t, U32.cmp(x, x)), String.order(t, t), EQ{},
        Equal.cong(Cmp, Cmp, c => String.order.go(t, t, c),
          U32.cmp(x, x), EQ{}, Laws.u32_order_reflexive(x)),
        Laws.string_order_reflexive(t))

def Laws.string_equality_reflexive(s):
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c),
    String.order(s, s), EQ{}, Laws.string_order_reflexive(s))

def Laws.completion_metadata(status, instant):
  match status:
    case T.SBacklog{}:
      {==}
    case T.STodo{}:
      {==}
    case T.SProgress{}:
      {==}
    case T.SBlocked{}:
      {==}
    case T.SReview{}:
      {==}
    case T.SDone{}:
      {==}

def Laws.private_is_ineligible(task):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.deleted_is_ineligible(task, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      match private:
        case False{}:
          {==}
        case True{}:
          {==}

def Laws.deletion_preserves_tombstone(task, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.edit_cannot_resurrect(task, patch, instant):
  match task patch:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes} T.Patch{pt, ps, pp, pg, pv}:
      {==}

def Laws.note_cannot_resurrect(task, note, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.notes_off_omits_all_direct_notes(task):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.edit_without_status_keeps_completion(task, title, priority, tags, private, instant):
  match task:
    case T.Task{id, previousTitle, status, previousPriority, previousTags, previousPrivate, deleted, created, updated, completed, notes}:
      {==}

def Laws.edit_to_done_records_completion(task, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.edit_to_todo_clears_completion(task, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.private_context_head_is_omitted(task, rest, sendNotes):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.deleted_context_head_is_omitted(task, instant, rest, sendNotes):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      match private:
        case False{}:
          {==}
        case True{}:
          {==}

def Laws.notes_off_context_has_no_notes(tasks):
  match tasks:
    case Nil{}:
      {==}
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes} <> rest:
      match private deleted:
        case False{} False{}:
          Laws.notes_off_context_has_no_notes(rest)
        case False{} True{}:
          Laws.notes_off_context_has_no_notes(rest)
        case True{} False{}:
          Laws.notes_off_context_has_no_notes(rest)
        case True{} True{}:
          Laws.notes_off_context_has_no_notes(rest)

def Laws.incomplete_state_withholds_context(tasks, summaries, reports, diagnostics, sendNotes):
  {==}

def Laws.failed_publication_preserves_pending(pending, committed):
  {==}

def Laws.empty_approval_preserves_pending(pending):
  match pending:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, T.DomainEvent>, List<&2, T.DomainEvent>, xs => h <> xs,
        Core.acknowledge(t, Nil{}, True{}), t, Laws.empty_approval_preserves_pending(t))

def Laws.unapproved_event_remains_pending(event, rest, committed, absent):
  %Equal.sym(Bool, Core.exact_contains(committed, event), False{}, absent) :
    {Core.acknowledge_put(event, Core.acknowledge_success(rest, committed), _) == event <> Core.acknowledge_success(rest, committed) : List<&2, T.DomainEvent>}
  {==}

def Laws.unrecognized_schema_is_refused(version, not_one, not_two):
  %Equal.sym(Bool, U32.is_eq(version, 1), False{}, not_one) :
    {Bool.or(_, U32.is_eq(version, 2)) == False{} : Bool}
  not_two

def Laws.eligible_task_exists():
  (T.Task{"T-aaa111", "Synthetic public task", T.STodo{}, T.PNormal{}, Nil{}, False{}, False{}, "2026-11-08T00:00:00.000Z", "2026-11-08T00:00:00.000Z", None{}, Nil{}}, {==})

def Laws.unsupported_schema_exists():
  (999, ({==}, {==}))

def Laws.true_and(a, b, pa, pb):
  %Equal.sym(Bool, a, True{}, pa) : {Bool.and(_, b) == True{} : Bool}
  pb

def Laws.bool_equality_reflexive(b):
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.status_equality_reflexive(status):
  match status:
    case T.SBacklog{}:
      {==}
    case T.STodo{}:
      {==}
    case T.SProgress{}:
      {==}
    case T.SBlocked{}:
      {==}
    case T.SReview{}:
      {==}
    case T.SDone{}:
      {==}

def Laws.priority_equality_reflexive(priority):
  match priority:
    case T.PLow{}:
      {==}
    case T.PNormal{}:
      {==}
    case T.PHigh{}:
      {==}
    case T.PUrgent{}:
      {==}

def Laws.strings_equality_reflexive(strings):
  match strings:
    case Nil{}:
      {==}
    case h <> t:
      Laws.true_and(String.eq(h, h), Core.strings_eq(t, t),
        Laws.string_equality_reflexive(h), Laws.strings_equality_reflexive(t))

def Laws.optional_string_equality_reflexive(value):
  match value:
    case None{}:
      {==}
    case Some{x}:
      Laws.string_equality_reflexive(x)

def Laws.optional_status_equality_reflexive(value):
  match value:
    case None{}:
      {==}
    case Some{x}:
      Laws.status_equality_reflexive(x)

def Laws.optional_priority_equality_reflexive(value):
  match value:
    case None{}:
      {==}
    case Some{x}:
      Laws.priority_equality_reflexive(x)

def Laws.optional_strings_equality_reflexive(value):
  match value:
    case None{}:
      {==}
    case Some{x}:
      Laws.strings_equality_reflexive(x)

def Laws.optional_bool_equality_reflexive(value):
  match value:
    case None{}:
      {==}
    case Some{x}:
      Laws.bool_equality_reflexive(x)

def Laws.patch_equality_reflexive(patch):
  match patch:
    case T.Patch{title, status, priority, tags, private}:
      Laws.true_and(Core.optional_string_eq(title, title), Bool.and(Core.optional_status_eq(status, status), Bool.and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private)))),
        Laws.optional_string_equality_reflexive(title),
        Laws.true_and(Core.optional_status_eq(status, status), Bool.and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private))),
          Laws.optional_status_equality_reflexive(status),
          Laws.true_and(Core.optional_priority_eq(priority, priority), Bool.and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private)),
            Laws.optional_priority_equality_reflexive(priority),
            Laws.true_and(Core.optional_strings_eq(tags, tags), Core.optional_bool_eq(private, private), Laws.optional_strings_equality_reflexive(tags), Laws.optional_bool_equality_reflexive(private)))))

def Laws.payload_equality_reflexive(payload):
  match payload:
    case T.Created{id, title, status, priority, tags, private}:
      Laws.true_and(String.eq(id, id), Bool.and(String.eq(title, title), Bool.and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private))))),
        Laws.string_equality_reflexive(id),
        Laws.true_and(String.eq(title, title), Bool.and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private)))),
          Laws.string_equality_reflexive(title),
          Laws.true_and(Core.status_eq(status, status), Bool.and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private))),
            Laws.status_equality_reflexive(status),
            Laws.true_and(Core.priority_eq(priority, priority), Bool.and(Core.strings_eq(tags, tags), Core.bool_eq(private, private)),
              Laws.priority_equality_reflexive(priority),
              Laws.true_and(Core.strings_eq(tags, tags), Core.bool_eq(private, private), Laws.strings_equality_reflexive(tags), Laws.bool_equality_reflexive(private))))))
    case T.StatusChanged{id, status}:
      Laws.true_and(String.eq(id, id), Core.status_eq(status, status), Laws.string_equality_reflexive(id), Laws.status_equality_reflexive(status))
    case T.Noted{id, text}:
      Laws.true_and(String.eq(id, id), String.eq(text, text), Laws.string_equality_reflexive(id), Laws.string_equality_reflexive(text))
    case T.Edited{id, patch}:
      Laws.true_and(String.eq(id, id), Core.patch_eq(patch, patch), Laws.string_equality_reflexive(id), Laws.patch_equality_reflexive(patch))
    case T.Deleted{id}:
      Laws.string_equality_reflexive(id)
    case T.SummarySet{date, kind, body}:
      Laws.true_and(String.eq(date, date), Bool.and(String.eq(kind, kind), String.eq(body, body)), Laws.string_equality_reflexive(date),
        Laws.true_and(String.eq(kind, kind), String.eq(body, body), Laws.string_equality_reflexive(kind), Laws.string_equality_reflexive(body)))
    case T.StandupSet{date, kind, text}:
      Laws.true_and(String.eq(date, date), Bool.and(String.eq(kind, kind), String.eq(text, text)), Laws.string_equality_reflexive(date),
        Laws.true_and(String.eq(kind, kind), String.eq(text, text), Laws.string_equality_reflexive(kind), Laws.string_equality_reflexive(text)))
    case T.Opaque{kind}:
      Laws.string_equality_reflexive(kind)

def Laws.event_equality_reflexive(event):
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      Laws.true_and(String.eq(id, id), Bool.and(String.eq(ts, ts), Bool.and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical)))),
        Laws.string_equality_reflexive(id),
        Laws.true_and(String.eq(ts, ts), Bool.and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical))),
          Laws.string_equality_reflexive(ts),
          Laws.true_and(String.eq(day, day), Bool.and(Core.payload_eq(payload, payload), String.eq(canonical, canonical)),
            Laws.string_equality_reflexive(day),
            Laws.true_and(Core.payload_eq(payload, payload), String.eq(canonical, canonical), Laws.payload_equality_reflexive(payload), Laws.string_equality_reflexive(canonical)))))

def Laws.identical_pair_sort(event, order):
  match order:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.scan_identical_pair(event):
  Equal.trans(T.MergeResult,
    Core.scan_ids([event, event], Nil{}, None{}),
    Bool.pick(T.MergeResult, Bool.not(Core.event_eq(event, event)), T.EventConflict{Core.event_id(event)}, T.Merged{[event]}),
    T.Merged{[event]},
    Equal.cong(Bool, T.MergeResult,
      same => Bool.pick(T.MergeResult, Bool.and(same, Bool.not(Core.event_eq(event, event))), T.EventConflict{Core.event_id(event)},
        Core.scan_ids(Nil{}, Core.unique_put(event, [event], same), Some{event})),
      String.eq(Core.event_id(event), Core.event_id(event)), True{}, Laws.string_equality_reflexive(Core.event_id(event))),
    Equal.cong(Bool, T.MergeResult,
      equal => Bool.pick(T.MergeResult, Bool.not(equal), T.EventConflict{Core.event_id(event)}, T.Merged{[event]}),
      Core.event_eq(event, event), True{}, Laws.event_equality_reflexive(event)))

def Laws.duplicate_delivery_single_event(event):
  Equal.trans(T.MergeResult,
    Core.merge([event], [event]), Core.scan_ids([event, event], Nil{}, None{}), T.Merged{[event]},
    Equal.cong(List<&2, T.DomainEvent>, T.MergeResult, xs => Core.scan_ids(xs, Nil{}, None{}),
      List.sort.pair(T.DomainEvent, event, event, Core.event_id_le(event, event)), [event, event],
      Laws.identical_pair_sort(event, Core.event_id_le(event, event))),
    Laws.scan_identical_pair(event))

def Laws.create_done_has_completion(taskId, title, priority, tags, private, eventId, instant, day, canonical):
  {==}

def Laws.status_done_has_completion(task, taskId, eventId, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.status_todo_clears_completion(task, taskId, eventId, instant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.updates_after_deletion_are_diagnostic(state, task, payload, eventId, instant, deletionInstant):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def Laws.unknown_event_withholds_context(state, eventId, instant, day, kind, canonical, sendNotes):
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      {==}

def Laws.false_is_not_true(contradiction):
  %Equal.sym(Bool, False{}, True{}, contradiction) : Laws.false_true_discriminator(_)
  Unit{}

def Laws.bool_order_equality_sound(a, b, equality):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), LT{}, EQ{}, equality)
    case True{} False{}:
      Equal.sym(Bool, False{}, True{}, Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), GT{}, EQ{}, equality))
    case True{} True{}:
      {==}

def Laws.word_cmp_fin_tail(a, b, tail, equality):
  match tail:
    case LT{}:
      equality
    case EQ{}:
      {==}
    case GT{}:
      equality

def Laws.word_cmp_fin_head(a, b, tail, tail_equal, equality):
  Equal.trans(Cmp, Bool.cmp(a, b), Word.cmp.fin(a, b, tail), EQ{},
    Equal.sym(Cmp, Word.cmp.fin(a, b, tail), Bool.cmp(a, b),
      Equal.cong(Cmp, Cmp, c => Word.cmp.fin(a, b, c), tail, EQ{}, tail_equal)),
    equality)

def Laws.word_order_equality_sound(n, a, b, equality):
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case Succ{+p}:
      match a b:
        case WCon{+ah, +at} WCon{+bh, +bt}:
          +tail_order = Laws.word_cmp_fin_tail(ah, bh, Word.cmp(p, at, bt), equality)
          head_order = Laws.word_cmp_fin_head(ah, bh, Word.cmp(p, at, bt), tail_order, equality)
          head_equal = Laws.bool_order_equality_sound(ah, bh, head_order)
          tail_equal = Laws.word_order_equality_sound(p, at, bt, tail_order)
          Equal.trans(Word(1n+p), WCon{ah, at}, WCon{bh, at}, WCon{bh, bt},
            Equal.cong(Bool, Word(1n+p), bit => WCon{bit, at}, ah, bh, head_equal),
            Equal.cong(Word(p), Word(1n+p), bits => WCon{bh, bits}, at, bt, tail_equal))

def Laws.u32_order_equality_sound(a, b, equality):
  match a b:
    case U32{x} U32{y}:
      Equal.cong(Word(32n), U32, bits => U32{bits}, x, y,
        Laws.word_order_equality_sound(32n, x, y, equality))

def Laws.string_order_go_lt(a, b):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def Laws.string_order_go_gt(a, b):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      {==}
    case SCon{h, t} SNil{}:
      {==}
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      {==}

def Laws.string_order_go_eq_premise(a, b, order, equality):
  match order:
    case LT{}:
      Equal.trans(Cmp, LT{}, String.order.go(a, b, LT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, LT{}), LT{}, Laws.string_order_go_lt(a, b)), equality)
    case EQ{}:
      {==}
    case GT{}:
      Equal.trans(Cmp, GT{}, String.order.go(a, b, GT{}), EQ{},
        Equal.sym(Cmp, String.order.go(a, b, GT{}), GT{}, Laws.string_order_go_gt(a, b)), equality)

def Laws.string_order_equality_sound(a, b, equality):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      Empty.absurd({SNil{} == SCon{h, t} : String},
        Laws.false_is_not_true(Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), LT{}, EQ{}, equality)))
    case SCon{h, t} SNil{}:
      Empty.absurd({SCon{h, t} == SNil{} : String},
        Laws.false_is_not_true(Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), GT{}, EQ{}, equality)))
    case SCon{Chr{+x}, +at} SCon{Chr{+y}, +bt}:
      +head_order = Laws.string_order_go_eq_premise(at, bt, U32.cmp(x, y), equality)
      head_equal = Laws.u32_order_equality_sound(x, y, head_order)
      tail_order = Equal.trans(Cmp, String.order(at, bt), String.order.go(at, bt, U32.cmp(x, y)), EQ{},
        Equal.sym(Cmp, String.order.go(at, bt, U32.cmp(x, y)), String.order(at, bt),
          Equal.cong(Cmp, Cmp, c => String.order.go(at, bt, c), U32.cmp(x, y), EQ{}, head_order)), equality)
      tail_equal = Laws.string_order_equality_sound(at, bt, tail_order)
      Equal.trans(String, SCon{Chr{x}, at}, SCon{Chr{y}, at}, SCon{Chr{y}, bt},
        Equal.cong(U32, String, code => SCon{Chr{code}, at}, x, y, head_equal),
        Equal.cong(String, String, tail => SCon{Chr{y}, tail}, at, bt, tail_equal))

def Laws.cmp_is_eq_sound(order, equality):
  match order:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, Laws.false_is_not_true(equality))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, Laws.false_is_not_true(equality))

def Laws.string_equality_sound(a, b, equality):
  Laws.string_order_equality_sound(a, b,
    Laws.cmp_is_eq_sound(String.order(a, b), equality))

def Laws.and_false_right(value):
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.and_true_right(a, b, equality):
  match a:
    case False{}:
      Empty.absurd({b == True{} : Bool}, Laws.false_is_not_true(equality))
    case True{}:
      equality

def Laws.publication_requires_exact_plan(schemas, approvedPlan, executionPlan, accepted):
  Laws.string_equality_sound(approvedPlan, executionPlan,
    Laws.and_true_right(Publication.schemas_compatible(schemas), String.eq(approvedPlan, executionPlan), accepted))

def Laws.bool_not_true_is_false(value, reject):
  match value:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, reject({==}))

def Laws.publication_rejects_changed_plan(schemas, approvedPlan, executionPlan, different):
  Laws.bool_not_true_is_false(Publication.approved(schemas, approvedPlan, executionPlan),
    accepted => different(Laws.publication_requires_exact_plan(schemas, approvedPlan, executionPlan, accepted)))

def Laws.unsupported_schema_anywhere(prefix, suffix, version, not_one, not_two):
  match prefix:
    case Nil{}:
      Equal.cong(Bool, Bool, allowed => Bool.and(allowed, Publication.schemas_compatible(suffix)),
        Core.schema_allowed(version), False{}, Laws.unrecognized_schema_is_refused(version, not_one, not_two))
    case schema <> rest:
      Equal.trans(Bool,
        Publication.schemas_compatible(List.append(&2, U32, schema <> rest, version <> suffix)),
        Bool.and(Core.schema_allowed(schema), False{}), False{},
        Equal.cong(Bool, Bool, compatible => Bool.and(Core.schema_allowed(schema), compatible),
          Publication.schemas_compatible(List.append(&2, U32, rest, version <> suffix)), False{},
          Laws.unsupported_schema_anywhere(rest, suffix, version, not_one, not_two)),
        Laws.and_false_right(Core.schema_allowed(schema)))

def Laws.publication_rejects_unsupported_schema_anywhere(prefix, suffix, version, approvedPlan, executionPlan, not_one, not_two):
  Equal.cong(Bool, Bool, compatible => Bool.and(compatible, String.eq(approvedPlan, executionPlan)),
    Publication.schemas_compatible(List.append(&2, U32, prefix, version <> suffix)), False{},
    Laws.unsupported_schema_anywhere(prefix, suffix, version, not_one, not_two))

def Laws.approved_publication_exists():
  ("synthetic exact write plan", {==})

def Laws.or_associative(a, b, c):
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.or_commutative(a, b):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def Laws.or_false_right(a):
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.or_move_left(a, b, c):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def Laws.ids_append(xs, ys, id):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        Core.ids_contains(List.append(&2, T.DomainEvent, h <> t, ys), id),
        Bool.or(String.eq(Core.event_id(h), id), Bool.or(Core.ids_contains(t, id), Core.ids_contains(ys, id))),
        Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(ys, id)),
        Equal.cong(Bool, Bool, member => Bool.or(String.eq(Core.event_id(h), id), member),
          Core.ids_contains(List.append(&2, T.DomainEvent, t, ys), id), Bool.or(Core.ids_contains(t, id), Core.ids_contains(ys, id)),
          Laws.ids_append(t, ys, id)),
        Laws.or_associative(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), Core.ids_contains(ys, id)))

def Laws.ids_reverse_accumulator(xs, acc, id):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        Core.ids_contains(List.reverse.go(&2, T.DomainEvent, h <> t, acc), id),
        Bool.or(Core.ids_contains(t, id), Core.ids_contains(h <> acc, id)),
        Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(acc, id)),
        Laws.ids_reverse_accumulator(t, h <> acc, id),
        Equal.trans(Bool,
          Bool.or(Core.ids_contains(t, id), Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(acc, id))),
          Bool.or(String.eq(Core.event_id(h), id), Bool.or(Core.ids_contains(t, id), Core.ids_contains(acc, id))),
          Bool.or(Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(t, id)), Core.ids_contains(acc, id)),
          Laws.or_move_left(Core.ids_contains(t, id), String.eq(Core.event_id(h), id), Core.ids_contains(acc, id)),
          Laws.or_associative(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), Core.ids_contains(acc, id))))

def Laws.ids_concat(runs, id):
  match runs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool, Core.ids_contains(List.concat(&2, T.DomainEvent, h <> t), id),
        Bool.or(Core.ids_contains(h, id), Core.ids_contains(List.concat(&2, T.DomainEvent, t), id)), Laws.runs_ids(h <> t, id),
        Laws.ids_append(h, List.concat(&2, T.DomainEvent, t), id),
        Equal.cong(Bool, Bool, member => Bool.or(Core.ids_contains(h, id), member),
          Core.ids_contains(List.concat(&2, T.DomainEvent, t), id), Laws.runs_ids(t, id), Laws.ids_concat(t, id)))

def Laws.or_pair_swap(a, b):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def SortProof.select_left(+a: Bool, +x: Bool, +xt: Bool, +y: Bool, +yt: Bool) ->
  {Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))) == Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))) : Bool}:
  Equal.trans(Bool,
    Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))), Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))),
    Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
    Equal.sym(Bool, Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))), Bool.or(Bool.or(x, a), Bool.or(xt, Bool.or(y, yt))),
      Laws.or_associative(x, a, Bool.or(xt, Bool.or(y, yt)))),
    Equal.trans(Bool,
      Bool.or(x, Bool.or(a, Bool.or(xt, Bool.or(y, yt)))), Bool.or(a, Bool.or(x, Bool.or(xt, Bool.or(y, yt)))),
      Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
      Laws.or_move_left(x, a, Bool.or(xt, Bool.or(y, yt))),
      Equal.cong(Bool, Bool, member => Bool.or(a, member), Bool.or(x, Bool.or(xt, Bool.or(y, yt))),
        Bool.or(Bool.or(x, xt), Bool.or(y, yt)), Laws.or_associative(x, xt, Bool.or(y, yt)))))

def SortProof.select_right(+a: Bool, +x: Bool, +xt: Bool, +y: Bool, +yt: Bool) ->
  {Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)) == Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))) : Bool}:
  Equal.trans(Bool,
    Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)), Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))),
    Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
    Equal.sym(Bool, Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))), Bool.or(Bool.or(y, a), Bool.or(Bool.or(x, xt), yt)),
      Laws.or_associative(y, a, Bool.or(Bool.or(x, xt), yt))),
    Equal.trans(Bool,
      Bool.or(y, Bool.or(a, Bool.or(Bool.or(x, xt), yt))), Bool.or(a, Bool.or(y, Bool.or(Bool.or(x, xt), yt))),
      Bool.or(a, Bool.or(Bool.or(x, xt), Bool.or(y, yt))),
      Laws.or_move_left(y, a, Bool.or(Bool.or(x, xt), yt)),
      Equal.cong(Bool, Bool, member => Bool.or(a, member), Bool.or(y, Bool.or(Bool.or(x, xt), yt)),
        Bool.or(Bool.or(x, xt), Bool.or(y, yt)), Laws.or_move_left(y, Bool.or(x, xt), yt))))

def SortProof.merge_step(+acc: List<&2, T.DomainEvent>, +x: T.DomainEvent, +xt: List<&2, T.DomainEvent>, +y: T.DomainEvent, +yt: List<&2, T.DomainEvent>, order: Bool, +id: String) ->
  {Laws.merge_state_ids(List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order), id) == Laws.merge_state_ids((acc, x <> xt, y <> yt), id) : Bool}:
  match order:
    case False{}:
      SortProof.select_right(Core.ids_contains(acc, id), String.eq(Core.event_id(x), id), Core.ids_contains(xt, id), String.eq(Core.event_id(y), id), Core.ids_contains(yt, id))
    case True{}:
      SortProof.select_left(Core.ids_contains(acc, id), String.eq(Core.event_id(x), id), Core.ids_contains(xt, id), String.eq(Core.event_id(y), id), Core.ids_contains(yt, id))

def SortProof.choose_merge(~le: T.DomainEvent -> T.DomainEvent -> Bool, fuel: Nat,
  acc: List<&2, T.DomainEvent>, x: T.DomainEvent, xt: List<&2, T.DomainEvent>, y: T.DomainEvent, yt: List<&2, T.DomainEvent>, order: Bool, id: String,
  left: {Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, fuel, (x <> acc, xt, y <> yt)), id) == Laws.merge_state_ids((acc, x <> xt, y <> yt), id) : Bool},
  right: {Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, fuel, (y <> acc, x <> xt, yt)), id) == Laws.merge_state_ids((acc, x <> xt, y <> yt), id) : Bool}) ->
  {Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, fuel, List.merge.step(T.DomainEvent, acc, x, xt, y, yt, order)), id) == Laws.merge_state_ids((acc, x <> xt, y <> yt), id) : Bool}:
  match order:
    case False{}:
      right
    case True{}:
      left

def SortProof.merge_membership(~le: T.DomainEvent -> T.DomainEvent -> Bool, fuel: Nat,
  +acc: List<&2, T.DomainEvent>, +xs: List<&2, T.DomainEvent>, +ys: List<&2, T.DomainEvent>, +id: String) ->
  {Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, fuel, (acc, xs, ys)), id) == Laws.merge_state_ids((acc, xs, ys), id) : Bool}:
  match fuel:
    case 0n:
      Equal.trans(Bool, Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, 0n, (acc, xs, ys)), id),
        Bool.or(Core.ids_contains(acc, id), Core.ids_contains(List.append(&2, T.DomainEvent, xs, ys), id)),
        Laws.merge_state_ids((acc, xs, ys), id),
        Laws.ids_reverse_accumulator(acc, List.append(&2, T.DomainEvent, xs, ys), id),
        Equal.cong(Bool, Bool, member => Bool.or(Core.ids_contains(acc, id), member),
          Core.ids_contains(List.append(&2, T.DomainEvent, xs, ys), id), Bool.or(Core.ids_contains(xs, id), Core.ids_contains(ys, id)), Laws.ids_append(xs, ys, id)))
    case Succ{+f}:
      match xs ys:
        case Nil{} Nil{}:
          Laws.ids_reverse_accumulator(acc, Nil{}, id)
        case Nil{} y <> yt:
          Laws.ids_reverse_accumulator(acc, y <> yt, id)
        case x <> xt Nil{}:
          Equal.trans(Bool, Core.ids_contains(List.reverse.go(&2, T.DomainEvent, acc, x <> xt), id),
            Bool.or(Core.ids_contains(acc, id), Core.ids_contains(x <> xt, id)), Laws.merge_state_ids((acc, x <> xt, Nil{}), id),
            Laws.ids_reverse_accumulator(acc, x <> xt, id),
            Equal.cong(Bool, Bool, member => Bool.or(Core.ids_contains(acc, id), member), Core.ids_contains(x <> xt, id), Bool.or(Core.ids_contains(x <> xt, id), False{}),
              Equal.sym(Bool, Bool.or(Core.ids_contains(x <> xt, id), False{}), Core.ids_contains(x <> xt, id), Laws.or_false_right(Core.ids_contains(x <> xt, id)))))
        case +x <> +xt +y <> +yt:
          SortProof.choose_merge(~le, f, acc, x, xt, y, yt, le(x, y), id,
            Equal.trans(Bool, Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, f, (x <> acc, xt, y <> yt)), id),
              Laws.merge_state_ids((x <> acc, xt, y <> yt), id), Laws.merge_state_ids((acc, x <> xt, y <> yt), id),
              SortProof.merge_membership(~le, f, x <> acc, xt, y <> yt, id), SortProof.merge_step(acc, x, xt, y, yt, True{}, id)),
            Equal.trans(Bool, Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, f, (y <> acc, x <> xt, yt)), id),
              Laws.merge_state_ids((y <> acc, x <> xt, yt), id), Laws.merge_state_ids((acc, x <> xt, y <> yt), id),
              SortProof.merge_membership(~le, f, y <> acc, x <> xt, yt, id), SortProof.merge_step(acc, x, xt, y, yt, False{}, id)))

def SortProof.pair_membership(+x: T.DomainEvent, +y: T.DomainEvent, order: Bool, +id: String) ->
  {Core.ids_contains(List.sort.pair(T.DomainEvent, x, y, order), id) == Core.ids_contains([x, y], id) : Bool}:
  match order:
    case False{}:
      Laws.or_pair_swap(String.eq(Core.event_id(y), id), String.eq(Core.event_id(x), id))
    case True{}:
      {==}

def SortProof.pairs_membership(~le: T.DomainEvent -> T.DomainEvent -> Bool, xs: List<&2, T.DomainEvent>, +id: String) ->
  {Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, xs), id) == Core.ids_contains(xs, id) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case h <> Nil{}:
      Laws.or_false_right(Core.ids_contains([h], id))
    case +x <> +y <> +t:
      Equal.trans(Bool,
        Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, x <> y <> t), id),
        Bool.or(Core.ids_contains([x, y], id), Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, t), id)), Core.ids_contains(x <> y <> t, id),
        Equal.cong(Bool, Bool, member => Bool.or(member, Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, t), id)),
          Core.ids_contains(List.sort.pair(T.DomainEvent, x, y, le(x, y)), id), Core.ids_contains([x, y], id), SortProof.pair_membership(x, y, le(x, y), id)),
        Equal.trans(Bool,
          Bool.or(Core.ids_contains([x, y], id), Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, t), id)), Bool.or(Core.ids_contains([x, y], id), Core.ids_contains(t, id)), Core.ids_contains(x <> y <> t, id),
          Equal.cong(Bool, Bool, member => Bool.or(Core.ids_contains([x, y], id), member), Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~le, t), id), Core.ids_contains(t, id), SortProof.pairs_membership(~le, t, id)),
          Equal.sym(Bool, Core.ids_contains(x <> y <> t, id), Bool.or(Core.ids_contains([x, y], id), Core.ids_contains(t, id)), Laws.ids_append([x, y], t, id))))

def SortProof.pass_membership(~le: T.DomainEvent -> T.DomainEvent -> Bool, runs: List<&2, List<&2, T.DomainEvent>>, +n: Nat, +id: String) ->
  {Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, runs), id) == Laws.runs_ids(runs, id) : Bool}:
  match runs:
    case Nil{}:
      {==}
    case r <> Nil{}:
      {==}
    case +r1 <> +r2 <> +rest:
      Equal.trans(Bool,
        Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, r1 <> r2 <> rest), id),
        Bool.or(Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, rest), id)), Laws.runs_ids(r1 <> r2 <> rest, id),
        Equal.cong(Bool, Bool, member => Bool.or(member, Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, rest), id)),
          Core.ids_contains(List.merge.go(~T.DomainEvent, ~le, n, (Nil{}, r1, r2)), id), Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), SortProof.merge_membership(~le, n, Nil{}, r1, r2, id)),
        Equal.trans(Bool,
          Bool.or(Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, rest), id)),
          Bool.or(Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), Laws.runs_ids(rest, id)), Laws.runs_ids(r1 <> r2 <> rest, id),
          Equal.cong(Bool, Bool, member => Bool.or(Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), member),
            Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, rest), id), Laws.runs_ids(rest, id), SortProof.pass_membership(~le, rest, n, id)),
          Equal.sym(Bool, Bool.or(Core.ids_contains(r1, id), Bool.or(Core.ids_contains(r2, id), Laws.runs_ids(rest, id))),
            Bool.or(Bool.or(Core.ids_contains(r1, id), Core.ids_contains(r2, id)), Laws.runs_ids(rest, id)), Laws.or_associative(Core.ids_contains(r1, id), Core.ids_contains(r2, id), Laws.runs_ids(rest, id)))))

def SortProof.go_membership(~le: T.DomainEvent -> T.DomainEvent -> Bool, fuel: Nat, +n: Nat, runs: List<&2, List<&2, T.DomainEvent>>, +id: String) ->
  {Core.ids_contains(List.sort.go(~T.DomainEvent, ~le, fuel, n, runs), id) == Laws.runs_ids(runs, id) : Bool}:
  match fuel:
    case 0n:
      Laws.ids_concat(runs, id)
    case 1n+f:
      match runs:
        case Nil{}:
          {==}
        case +r <> Nil{}:
          Equal.sym(Bool, Bool.or(Core.ids_contains(r, id), False{}), Core.ids_contains(r, id), Laws.or_false_right(Core.ids_contains(r, id)))
        case +r1 <> +r2 <> +rest:
          Equal.trans(Bool,
            Core.ids_contains(List.sort.go(~T.DomainEvent, ~le, 1n+f, n, r1 <> r2 <> rest), id), Laws.runs_ids(List.sort.pass(~T.DomainEvent, ~le, n, r1 <> r2 <> rest), id), Laws.runs_ids(r1 <> r2 <> rest, id),
            SortProof.go_membership(~le, f, n, List.sort.pass(~T.DomainEvent, ~le, n, r1 <> r2 <> rest), id),
            SortProof.pass_membership(~le, r1 <> r2 <> rest, n, id))

def Laws.id_sort_preserves_ids(xs, id):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      +ys = {h <> t : List<&2, T.DomainEvent>}
      +n = List.length(&2, T.DomainEvent, ys)
      Equal.trans(Bool, Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, ys), id), Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys), id), Core.ids_contains(ys, id),
        SortProof.go_membership(~Core.event_id_le, n, n, List.sort.pairs(~T.DomainEvent, ~Core.event_id_le, ys), id),
        SortProof.pairs_membership(~Core.event_id_le, ys, id))

def Laws.chronological_sort_preserves_ids(xs, id):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      +ys = {h <> t : List<&2, T.DomainEvent>}
      +n = List.length(&2, T.DomainEvent, ys)
      Equal.trans(Bool, Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_le, ys), id), Laws.runs_ids(List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys), id), Core.ids_contains(ys, id),
        SortProof.go_membership(~Core.event_le, n, n, List.sort.pairs(~T.DomainEvent, ~Core.event_le, ys), id),
        SortProof.pairs_membership(~Core.event_le, ys, id))

def Laws.boolean_absorption(condition, member, implication):
  match condition:
    case False{}:
      {==}
    case True{}:
      Equal.sym(Bool, member, True{}, implication({==}))

def Laws.member_absorption(events, presentId, id, present):
  Laws.boolean_absorption(String.eq(presentId, id), Core.ids_contains(events, id),
    same => Equal.trans(Bool, Core.ids_contains(events, id), Core.ids_contains(events, presentId), True{},
      Equal.cong(String, Bool, key => Core.ids_contains(events, key), id, presentId,
        Equal.sym(String, presentId, id, Laws.string_equality_sound(presentId, id, same))), present))

def Laws.member_self_head(event, rest):
  Equal.cong(Bool, Bool, same => Bool.or(same, Core.ids_contains(rest, Core.event_id(event))),
    String.eq(Core.event_id(event), Core.event_id(event)), True{}, Laws.string_equality_reflexive(Core.event_id(event)))

def ScanProof.unique_put_invariant(+event: T.DomainEvent, +acc: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +id: String, same: Bool,
  link: {same == String.eq(Core.event_id(event), Core.event_id(previous)) : Bool},
  covered: {Core.ids_contains(acc, Core.event_id(previous)) == True{} : Bool}) ->
  {Core.ids_contains(Core.unique_put(event, acc, same), id) == Bool.or(String.eq(Core.event_id(event), id), Core.ids_contains(acc, id)) : Bool} &
  {Core.ids_contains(Core.unique_put(event, acc, same), Core.event_id(event)) == True{} : Bool}:
  match same:
    case False{}:
      ({==}, Laws.member_self_head(event, acc))
    case True{}:
      equal_ids = Laws.string_equality_sound(Core.event_id(event), Core.event_id(previous),
        Equal.sym(Bool, True{}, String.eq(Core.event_id(event), Core.event_id(previous)), link))
      +present = Equal.trans(Bool, Core.ids_contains(acc, Core.event_id(event)), Core.ids_contains(acc, Core.event_id(previous)), True{},
        Equal.cong(String, Bool, key => Core.ids_contains(acc, key), Core.event_id(event), Core.event_id(previous), equal_ids), covered)
      (Equal.sym(Bool, Bool.or(String.eq(Core.event_id(event), id), Core.ids_contains(acc, id)), Core.ids_contains(acc, id),
        Laws.member_absorption(acc, Core.event_id(event), id, present)), present)

def ScanProof.rewrite_result(result: T.MergeResult, +id: String, a: Bool, b: Bool,
  equality: {a == b : Bool}, proof: Laws.SuccessfulIds(result, id, a)) -> Laws.SuccessfulIds(result, id, b):
  match result:
    case T.EventConflict{conflictId}:
      Unit{}
    case T.Merged{events}:
      Equal.trans(Bool, Core.ids_contains(events, id), a, b, proof, equality)

def ScanProof.pick_result(condition: Bool, conflictId: String, result: T.MergeResult, id: String, expected: Bool,
  proof: Laws.SuccessfulIds(result, id, expected)) ->
  Laws.SuccessfulIds(Bool.pick(T.MergeResult, condition, T.EventConflict{conflictId}, result), id, expected):
  match condition:
    case False{}:
      proof
    case True{}:
      Unit{}

def ScanProof.shuffle(+head: Bool, +tail: Bool, +acc: Bool) ->
  {Bool.or(tail, Bool.or(head, acc)) == Bool.or(Bool.or(head, tail), acc) : Bool}:
  Equal.trans(Bool, Bool.or(tail, Bool.or(head, acc)), Bool.or(head, Bool.or(tail, acc)), Bool.or(Bool.or(head, tail), acc),
    Laws.or_move_left(tail, head, acc), Laws.or_associative(head, tail, acc))

def Laws.scan_preserves_ids(fuel, acc, previous, id, covered):
  match fuel previous:
    case Nil{} _:
      Laws.chronological_sort_preserves_ids(acc, id)
    case +h <> +t None{}:
      ScanProof.rewrite_result(Core.scan_ids(t, h <> acc, Some{h}), id,
        Bool.or(Core.ids_contains(t, id), Core.ids_contains(h <> acc, id)), Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(acc, id)),
        ScanProof.shuffle(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), Core.ids_contains(acc, id)),
        Laws.scan_preserves_ids(t, h <> acc, Some{h}, id, Laws.member_self_head(h, acc)))
    case +h <> +t Some{+p}:
      +same = String.eq(Core.event_id(h), Core.event_id(p))
      membership = Pair.fst(
        {Core.ids_contains(Core.unique_put(h, acc, same), id) == Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(acc, id)) : Bool},
        {Core.ids_contains(Core.unique_put(h, acc, same), Core.event_id(h)) == True{} : Bool},
        ScanProof.unique_put_invariant(h, acc, p, id, same, {==}, covered))
      covered_head = Pair.snd(
        {Core.ids_contains(Core.unique_put(h, acc, same), id) == Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(acc, id)) : Bool},
        {Core.ids_contains(Core.unique_put(h, acc, same), Core.event_id(h)) == True{} : Bool},
        ScanProof.unique_put_invariant(h, acc, p, id, same, {==}, covered))
      continuation = Laws.scan_preserves_ids(t, Core.unique_put(h, acc, same), Some{h}, id, covered_head)
      preserved = ScanProof.rewrite_result(Core.scan_ids(t, Core.unique_put(h, acc, same), Some{h}), id,
        Bool.or(Core.ids_contains(t, id), Core.ids_contains(Core.unique_put(h, acc, same), id)), Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(acc, id)),
        Equal.trans(Bool,
          Bool.or(Core.ids_contains(t, id), Core.ids_contains(Core.unique_put(h, acc, same), id)), Bool.or(Core.ids_contains(t, id), Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(acc, id))),
          Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(acc, id)),
          Equal.cong(Bool, Bool, member => Bool.or(Core.ids_contains(t, id), member), Core.ids_contains(Core.unique_put(h, acc, same), id),
            Bool.or(String.eq(Core.event_id(h), id), Core.ids_contains(acc, id)), membership),
          ScanProof.shuffle(String.eq(Core.event_id(h), id), Core.ids_contains(t, id), Core.ids_contains(acc, id))), continuation)
      ScanProof.pick_result(Bool.and(same, Bool.not(Core.event_eq(h, p))), Core.event_id(h), Core.scan_ids(t, Core.unique_put(h, acc, same), Some{h}), id,
        Bool.or(Core.ids_contains(h <> t, id), Core.ids_contains(acc, id)), preserved)

def Laws.merge_preserves_ids(left, right, id):
  ScanProof.rewrite_result(Core.merge(left, right), id,
    Bool.or(Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), id), False{}),
    Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)),
    Equal.trans(Bool,
      Bool.or(Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), id), False{}),
      Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), id), Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)),
      Laws.or_false_right(Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), id)),
      Equal.trans(Bool,
        Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), id), Core.ids_contains(List.append(&2, T.DomainEvent, left, right), id),
        Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)), Laws.id_sort_preserves_ids(List.append(&2, T.DomainEvent, left, right), id), Laws.ids_append(left, right, id))),
    Laws.scan_preserves_ids(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{}, id, Unit{}))

def Laws.successful_merge_has_exact_input_ids(left, right, output, id, success):
  %success : Laws.SuccessfulIds(_, id, Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)))
  Laws.merge_preserves_ids(left, right, id)

def Laws.and_false_from_right(a, b, absent):
  Equal.trans(Bool, Bool.and(a, b), Bool.and(a, False{}), False{},
    Equal.cong(Bool, Bool, value => Bool.and(a, value), b, False{}, absent), Laws.and_false_right(a))

def Laws.less_order_not_ge(order, before):
  match order:
    case LT{}:
      {==}
    case EQ{}:
      Empty.absurd({True{} == False{} : Bool}, Laws.false_is_not_true(before))
    case GT{}:
      Empty.absurd({True{} == False{} : Bool}, Laws.false_is_not_true(before))

def ReminderProof.off(enabled: Bool, alreadyFired: Bool, now: U32, target: U32, pending: Bool, summary: Bool, signOff: Bool,
  guard: {Bool.and(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))))) == False{} : Bool}) ->
  {Reports.reminder_decision(enabled, alreadyFired, now, target, pending, summary, signOff) == Reports.ReminderOff{} : Reports.ReminderDecision}:
  Equal.cong(Bool, Reports.ReminderDecision,
    due => Bool.pick(Reports.ReminderDecision, due, Reports.ReminderDue{pending, Bool.not(summary), Bool.not(signOff)}, Reports.ReminderOff{}),
    Bool.and(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))))), False{}, guard)

def ReminderProof.no_missing(+enabled: Bool, +alreadyFired: Bool, +now: U32, +target: U32, +pending: Bool, +summary: Bool, +signOff: Bool,
  none: {Reports.reminder_needed(pending, summary, signOff) == False{} : Bool}) ->
  {Reports.reminder_decision(enabled, alreadyFired, now, target, pending, summary, signOff) == Reports.ReminderOff{} : Reports.ReminderDecision}:
  ReminderProof.off(enabled, alreadyFired, now, target, pending, summary, signOff,
    Laws.and_false_from_right(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))))),
      Laws.and_false_from_right(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))),
        Laws.and_false_from_right(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))),
          Laws.and_false_from_right(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)),
            Laws.and_false_from_right(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff), none))))))

def Laws.reminder_disabled_is_off(alreadyFired, now, target, pending, summary, signOff):
  {==}

def Laws.reminder_already_fired_is_off(enabled, now, target, pending, summary, signOff):
  match enabled:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.reminder_complete_day_is_off(enabled, alreadyFired, now, target):
  ReminderProof.no_missing(enabled, alreadyFired, now, target, False{}, True{}, True{}, {==})

def Laws.reminder_before_target_is_off(enabled, alreadyFired, now, target, pending, summary, signOff, before):
  ReminderProof.off(enabled, alreadyFired, now, target, pending, summary, signOff,
    Laws.and_false_from_right(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))))),
      Laws.and_false_from_right(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))),
        Laws.and_false_from_right(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))),
          Laws.and_false_from_right(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)),
            Equal.cong(Bool, Bool, reached => Bool.and(reached, Reports.reminder_needed(pending, summary, signOff)), U32.is_ge(now, target), False{},
              Laws.less_order_not_ge(U32.cmp(now, target), before)))))))

def Laws.reminder_invalid_now_is_off(enabled, alreadyFired, now, target, pending, summary, signOff, invalid):
  ReminderProof.off(enabled, alreadyFired, now, target, pending, summary, signOff,
    Laws.and_false_from_right(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))))),
      Laws.and_false_from_right(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))),
        Equal.cong(Bool, Bool, valid => Bool.and(valid, Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))), U32.is_lt(now, 1440), False{}, invalid))))

def Laws.reminder_invalid_target_is_off(enabled, alreadyFired, now, target, pending, summary, signOff, invalid):
  ReminderProof.off(enabled, alreadyFired, now, target, pending, summary, signOff,
    Laws.and_false_from_right(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))))),
      Laws.and_false_from_right(Bool.not(alreadyFired), Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))),
        Laws.and_false_from_right(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))),
          Equal.cong(Bool, Bool, valid => Bool.and(valid, Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))), U32.is_lt(target, 1440), False{}, invalid)))))

def Laws.reminder_due_under_valid_guards(now, target, pending, summary, signOff, nowValid, targetValid, reached, missing):
  Equal.cong(Bool, Reports.ReminderDecision,
    due => Bool.pick(Reports.ReminderDecision, due, Reports.ReminderDue{pending, Bool.not(summary), Bool.not(signOff)}, Reports.ReminderOff{}),
    Bool.and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)))), True{},
    Laws.true_and(U32.is_lt(now, 1440), Bool.and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff))), nowValid,
      Laws.true_and(U32.is_lt(target, 1440), Bool.and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff)), targetValid,
        Laws.true_and(U32.is_ge(now, target), Reports.reminder_needed(pending, summary, signOff), reached, missing))))

def Laws.reminder_due_witness():
  {==}

def ReportsProof.ineligible_item(chosen: Maybe<&2, Reports.ReportItem>, rest: List<&2, Reports.ReportItem>) ->
  {Reports.item_put(chosen, rest, False{}) == rest : List<&2, Reports.ReportItem>}:
  match chosen:
    case None{}:
      {==}
    case Some{item}:
      {==}

def Laws.reports_omit_private_head(task, rest, events, sendNotes, morning, includePlan):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      ReportsProof.ineligible_item(
        Reports.report_item(T.Task{id, title, status, priority, tags, True{}, deleted, created, updated, completed, notes}, events, sendNotes, morning, includePlan),
        Reports.report_tasks(rest, events, sendNotes, morning, includePlan))

def Laws.reports_omit_deleted_head(task, instant, rest, events, sendNotes, morning, includePlan):
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      match private:
        case False{}:
          ReportsProof.ineligible_item(
            Reports.report_item(T.Task{id, title, status, priority, tags, False{}, True{}, created, instant, completed, notes}, events, sendNotes, morning, includePlan),
            Reports.report_tasks(rest, events, sendNotes, morning, includePlan))
        case True{}:
          ReportsProof.ineligible_item(
            Reports.report_item(T.Task{id, title, status, priority, tags, True{}, True{}, created, instant, completed, notes}, events, sendNotes, morning, includePlan),
            Reports.report_tasks(rest, events, sendNotes, morning, includePlan))

def ReportsProof.incomplete(result: T.MergeResult, tasks: List<&2, T.Task>, summaries: List<&2, T.Recorded>, reports: List<&2, T.Recorded>, diagnostics: List<&2, T.Diagnostic>,
  sendNotes: Bool, day: String, morning: Bool, includePlan: Bool) ->
  {Reports.report_merged(result, T.State{tasks, summaries, reports, diagnostics, False{}}, sendNotes, day, morning, includePlan) == Nil{} : List<&2, Reports.ReportItem>}:
  match result:
    case T.EventConflict{id}:
      {==}
    case T.Merged{events}:
      {==}

def Laws.reports_withhold_incomplete_state(tasks, summaries, reports, diagnostics, events, sendNotes, day, morning, includePlan):
  ReportsProof.incomplete(Core.merge(events, Nil{}), tasks, summaries, reports, diagnostics, sendNotes, day, morning, includePlan)

# Exhaustive constructor reflection; no assumed equality oracle.
def Laws.and_true_left(a, b, equality):
  match a:
    case False{}:
      equality
    case True{}:
      {==}

def Laws.status_equality_sound(a, b, equality):
  match a b:
    case T.SBacklog{} T.SBacklog{}:
      {==}
    case T.SBacklog{} T.STodo{}:
      Empty.absurd({T.SBacklog{} == T.STodo{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBacklog{} T.SProgress{}:
      Empty.absurd({T.SBacklog{} == T.SProgress{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBacklog{} T.SBlocked{}:
      Empty.absurd({T.SBacklog{} == T.SBlocked{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBacklog{} T.SReview{}:
      Empty.absurd({T.SBacklog{} == T.SReview{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBacklog{} T.SDone{}:
      Empty.absurd({T.SBacklog{} == T.SDone{} : T.Status}, Laws.false_is_not_true(equality))
    case T.STodo{} T.SBacklog{}:
      Empty.absurd({T.STodo{} == T.SBacklog{} : T.Status}, Laws.false_is_not_true(equality))
    case T.STodo{} T.STodo{}:
      {==}
    case T.STodo{} T.SProgress{}:
      Empty.absurd({T.STodo{} == T.SProgress{} : T.Status}, Laws.false_is_not_true(equality))
    case T.STodo{} T.SBlocked{}:
      Empty.absurd({T.STodo{} == T.SBlocked{} : T.Status}, Laws.false_is_not_true(equality))
    case T.STodo{} T.SReview{}:
      Empty.absurd({T.STodo{} == T.SReview{} : T.Status}, Laws.false_is_not_true(equality))
    case T.STodo{} T.SDone{}:
      Empty.absurd({T.STodo{} == T.SDone{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SProgress{} T.SBacklog{}:
      Empty.absurd({T.SProgress{} == T.SBacklog{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SProgress{} T.STodo{}:
      Empty.absurd({T.SProgress{} == T.STodo{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SProgress{} T.SProgress{}:
      {==}
    case T.SProgress{} T.SBlocked{}:
      Empty.absurd({T.SProgress{} == T.SBlocked{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SProgress{} T.SReview{}:
      Empty.absurd({T.SProgress{} == T.SReview{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SProgress{} T.SDone{}:
      Empty.absurd({T.SProgress{} == T.SDone{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBlocked{} T.SBacklog{}:
      Empty.absurd({T.SBlocked{} == T.SBacklog{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBlocked{} T.STodo{}:
      Empty.absurd({T.SBlocked{} == T.STodo{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBlocked{} T.SProgress{}:
      Empty.absurd({T.SBlocked{} == T.SProgress{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBlocked{} T.SBlocked{}:
      {==}
    case T.SBlocked{} T.SReview{}:
      Empty.absurd({T.SBlocked{} == T.SReview{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SBlocked{} T.SDone{}:
      Empty.absurd({T.SBlocked{} == T.SDone{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SReview{} T.SBacklog{}:
      Empty.absurd({T.SReview{} == T.SBacklog{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SReview{} T.STodo{}:
      Empty.absurd({T.SReview{} == T.STodo{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SReview{} T.SProgress{}:
      Empty.absurd({T.SReview{} == T.SProgress{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SReview{} T.SBlocked{}:
      Empty.absurd({T.SReview{} == T.SBlocked{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SReview{} T.SReview{}:
      {==}
    case T.SReview{} T.SDone{}:
      Empty.absurd({T.SReview{} == T.SDone{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.SBacklog{}:
      Empty.absurd({T.SDone{} == T.SBacklog{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.STodo{}:
      Empty.absurd({T.SDone{} == T.STodo{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.SProgress{}:
      Empty.absurd({T.SDone{} == T.SProgress{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.SBlocked{}:
      Empty.absurd({T.SDone{} == T.SBlocked{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.SReview{}:
      Empty.absurd({T.SDone{} == T.SReview{} : T.Status}, Laws.false_is_not_true(equality))
    case T.SDone{} T.SDone{}:
      {==}

def Laws.priority_equality_sound(a, b, equality):
  match a b:
    case T.PLow{} T.PLow{}:
      {==}
    case T.PLow{} T.PNormal{}:
      Empty.absurd({T.PLow{} == T.PNormal{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PLow{} T.PHigh{}:
      Empty.absurd({T.PLow{} == T.PHigh{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PLow{} T.PUrgent{}:
      Empty.absurd({T.PLow{} == T.PUrgent{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PNormal{} T.PLow{}:
      Empty.absurd({T.PNormal{} == T.PLow{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PNormal{} T.PNormal{}:
      {==}
    case T.PNormal{} T.PHigh{}:
      Empty.absurd({T.PNormal{} == T.PHigh{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PNormal{} T.PUrgent{}:
      Empty.absurd({T.PNormal{} == T.PUrgent{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PHigh{} T.PLow{}:
      Empty.absurd({T.PHigh{} == T.PLow{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PHigh{} T.PNormal{}:
      Empty.absurd({T.PHigh{} == T.PNormal{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PHigh{} T.PHigh{}:
      {==}
    case T.PHigh{} T.PUrgent{}:
      Empty.absurd({T.PHigh{} == T.PUrgent{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PUrgent{} T.PLow{}:
      Empty.absurd({T.PUrgent{} == T.PLow{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PUrgent{} T.PNormal{}:
      Empty.absurd({T.PUrgent{} == T.PNormal{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PUrgent{} T.PHigh{}:
      Empty.absurd({T.PUrgent{} == T.PHigh{} : T.Priority}, Laws.false_is_not_true(equality))
    case T.PUrgent{} T.PUrgent{}:
      {==}

def Laws.bool_equality_sound(a, b, equality):
  Laws.bool_order_equality_sound(a, b, Laws.cmp_is_eq_sound(Bool.cmp(a, b), equality))

def Laws.strings_equality_sound(a, b, equality):
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} h <> t:
      Empty.absurd({Nil{} == h <> t : List<&2, String>}, Laws.false_is_not_true(equality))
    case h <> t Nil{}:
      Empty.absurd({h <> t == Nil{} : List<&2, String>}, Laws.false_is_not_true(equality))
    case +ah <> +at +bh <> +bt:
      head = Laws.string_equality_sound(ah, bh, Laws.and_true_left(String.eq(ah, bh), Core.strings_eq(at, bt), equality))
      tail = Laws.strings_equality_sound(at, bt, Laws.and_true_right(String.eq(ah, bh), Core.strings_eq(at, bt), equality))
      %head : {ah <> at == _ <> bt : List<&2, String>}
      %tail : {ah <> at == ah <> _ : List<&2, String>}
      {==}

def Laws.optional_string_equality_sound(a, b, equality):
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, String>}, Laws.false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, String>}, Laws.false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(String, Maybe<&2, String>, value => Some{value}, x, y, Laws.string_equality_sound(x, y, equality))

def Laws.optional_status_equality_sound(a, b, equality):
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, T.Status>}, Laws.false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, T.Status>}, Laws.false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(T.Status, Maybe<&2, T.Status>, value => Some{value}, x, y, Laws.status_equality_sound(x, y, equality))

def Laws.optional_priority_equality_sound(a, b, equality):
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, T.Priority>}, Laws.false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, T.Priority>}, Laws.false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(T.Priority, Maybe<&2, T.Priority>, value => Some{value}, x, y, Laws.priority_equality_sound(x, y, equality))

def Laws.optional_strings_equality_sound(a, b, equality):
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, List<&2, String>>}, Laws.false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, List<&2, String>>}, Laws.false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(List<&2, String>, Maybe<&2, List<&2, String>>, value => Some{value}, x, y, Laws.strings_equality_sound(x, y, equality))

def Laws.optional_bool_equality_sound(a, b, equality):
  match a b:
    case None{} None{}:
      {==}
    case None{} Some{y}:
      Empty.absurd({None{} == Some{y} : Maybe<&2, Bool>}, Laws.false_is_not_true(equality))
    case Some{x} None{}:
      Empty.absurd({Some{x} == None{} : Maybe<&2, Bool>}, Laws.false_is_not_true(equality))
    case Some{x} Some{y}:
      Equal.cong(Bool, Maybe<&2, Bool>, value => Some{value}, x, y, Laws.bool_equality_sound(x, y, equality))

def Laws.patch_equality_sound(a, b, equality):
  match a b:
    case T.Patch{+a0, +a1, +a2, +a3, +a4} T.Patch{+b0, +b1, +b2, +b3, +b4}:
      comparison0 = Laws.and_true_left(Core.optional_string_eq(a0, b0), Bool.and(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)))), equality)
      +remaining1 = Laws.and_true_right(Core.optional_string_eq(a0, b0), Bool.and(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)))), equality)
      field0 = Laws.optional_string_equality_sound(a0, b0, comparison0)
      comparison1 = Laws.and_true_left(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4))), remaining1)
      +remaining2 = Laws.and_true_right(Core.optional_status_eq(a1, b1), Bool.and(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4))), remaining1)
      field1 = Laws.optional_status_equality_sound(a1, b1, comparison1)
      comparison2 = Laws.and_true_left(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)), remaining2)
      +remaining3 = Laws.and_true_right(Core.optional_priority_eq(a2, b2), Bool.and(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4)), remaining2)
      field2 = Laws.optional_priority_equality_sound(a2, b2, comparison2)
      comparison3 = Laws.and_true_left(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4), remaining3)
      +remaining4 = Laws.and_true_right(Core.optional_strings_eq(a3, b3), Core.optional_bool_eq(a4, b4), remaining3)
      field3 = Laws.optional_strings_equality_sound(a3, b3, comparison3)
      field4 = Laws.optional_bool_equality_sound(a4, b4, remaining4)
      %field0 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{_, b1, b2, b3, b4} : T.Patch}
      %field1 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, _, b2, b3, b4} : T.Patch}
      %field2 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, _, b3, b4} : T.Patch}
      %field3 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, a2, _, b4} : T.Patch}
      %field4 : {T.Patch{a0, a1, a2, a3, a4} == T.Patch{a0, a1, a2, a3, _} : T.Patch}
      {==}

def Laws.payload_equality_sound(a, b, equality):
  match a b:
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))))), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))))), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      comparison1 = Laws.and_true_left(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)))), remaining1)
      +remaining2 = Laws.and_true_right(String.eq(a1, b1), Bool.and(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)))), remaining1)
      field1 = Laws.string_equality_sound(a1, b1, comparison1)
      comparison2 = Laws.and_true_left(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))), remaining2)
      +remaining3 = Laws.and_true_right(Core.status_eq(a2, b2), Bool.and(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5))), remaining2)
      field2 = Laws.status_equality_sound(a2, b2, comparison2)
      comparison3 = Laws.and_true_left(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)), remaining3)
      +remaining4 = Laws.and_true_right(Core.priority_eq(a3, b3), Bool.and(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5)), remaining3)
      field3 = Laws.priority_equality_sound(a3, b3, comparison3)
      comparison4 = Laws.and_true_left(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5), remaining4)
      +remaining5 = Laws.and_true_right(Core.strings_eq(a4, b4), Core.bool_eq(a5, b5), remaining4)
      field4 = Laws.strings_equality_sound(a4, b4, comparison4)
      field5 = Laws.bool_equality_sound(a5, b5, remaining5)
      %field0 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{_, b1, b2, b3, b4, b5} : T.Payload}
      %field1 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, _, b2, b3, b4, b5} : T.Payload}
      %field2 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, _, b3, b4, b5} : T.Payload}
      %field3 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, _, b4, b5} : T.Payload}
      %field4 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, a3, _, b5} : T.Payload}
      %field5 : {T.Created{a0, a1, a2, a3, a4, a5} == T.Created{a0, a1, a2, a3, a4, _} : T.Payload}
      {==}
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Noted{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Edited{+b0, +b1}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Deleted{+b0}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Created{+a0, +a1, +a2, +a3, +a4, +a5} T.Opaque{+b0}:
      Empty.absurd({T.Created{a0, a1, a2, a3, a4, a5} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.StatusChanged{+b0, +b1}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Core.status_eq(a1, b1), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Core.status_eq(a1, b1), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      field1 = Laws.status_equality_sound(a1, b1, remaining1)
      %field0 : {T.StatusChanged{a0, a1} == T.StatusChanged{_, b1} : T.Payload}
      %field1 : {T.StatusChanged{a0, a1} == T.StatusChanged{a0, _} : T.Payload}
      {==}
    case T.StatusChanged{+a0, +a1} T.Noted{+b0, +b1}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Edited{+b0, +b1}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StatusChanged{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.StatusChanged{a0, a1} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Noted{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Noted{a0, a1} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Noted{+b0, +b1}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), String.eq(a1, b1), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), String.eq(a1, b1), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      field1 = Laws.string_equality_sound(a1, b1, remaining1)
      %field0 : {T.Noted{a0, a1} == T.Noted{_, b1} : T.Payload}
      %field1 : {T.Noted{a0, a1} == T.Noted{a0, _} : T.Payload}
      {==}
    case T.Noted{+a0, +a1} T.Edited{+b0, +b1}:
      Empty.absurd({T.Noted{a0, a1} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.Noted{a0, a1} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Noted{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Noted{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Noted{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.Noted{a0, a1} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Edited{a0, a1} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Edited{a0, a1} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Noted{+b0, +b1}:
      Empty.absurd({T.Edited{a0, a1} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Edited{+b0, +b1}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Core.patch_eq(a1, b1), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Core.patch_eq(a1, b1), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      field1 = Laws.patch_equality_sound(a1, b1, remaining1)
      %field0 : {T.Edited{a0, a1} == T.Edited{_, b1} : T.Payload}
      %field1 : {T.Edited{a0, a1} == T.Edited{a0, _} : T.Payload}
      {==}
    case T.Edited{+a0, +a1} T.Deleted{+b0}:
      Empty.absurd({T.Edited{a0, a1} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Edited{a0, a1} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Edited{a0, a1} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Edited{+a0, +a1} T.Opaque{+b0}:
      Empty.absurd({T.Edited{a0, a1} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Deleted{a0} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.Noted{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.Edited{+b0, +b1}:
      Empty.absurd({T.Deleted{a0} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.Deleted{+b0}:
      field0 = Laws.string_equality_sound(a0, b0, equality)
      %field0 : {T.Deleted{a0} == T.Deleted{_} : T.Payload}
      {==}
    case T.Deleted{+a0} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Deleted{a0} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Deleted{a0} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Deleted{+a0} T.Opaque{+b0}:
      Empty.absurd({T.Deleted{a0} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Noted{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Edited{+b0, +b1}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Deleted{+b0}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.SummarySet{+b0, +b1, +b2}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      comparison1 = Laws.and_true_left(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      +remaining2 = Laws.and_true_right(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      field1 = Laws.string_equality_sound(a1, b1, comparison1)
      field2 = Laws.string_equality_sound(a2, b2, remaining2)
      %field0 : {T.SummarySet{a0, a1, a2} == T.SummarySet{_, b1, b2} : T.Payload}
      %field1 : {T.SummarySet{a0, a1, a2} == T.SummarySet{a0, _, b2} : T.Payload}
      %field2 : {T.SummarySet{a0, a1, a2} == T.SummarySet{a0, a1, _} : T.Payload}
      {==}
    case T.SummarySet{+a0, +a1, +a2} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.SummarySet{+a0, +a1, +a2} T.Opaque{+b0}:
      Empty.absurd({T.SummarySet{a0, a1, a2} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Noted{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Edited{+b0, +b1}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.Deleted{+b0}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.StandupSet{+a0, +a1, +a2} T.StandupSet{+b0, +b1, +b2}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), String.eq(a2, b2)), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      comparison1 = Laws.and_true_left(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      +remaining2 = Laws.and_true_right(String.eq(a1, b1), String.eq(a2, b2), remaining1)
      field1 = Laws.string_equality_sound(a1, b1, comparison1)
      field2 = Laws.string_equality_sound(a2, b2, remaining2)
      %field0 : {T.StandupSet{a0, a1, a2} == T.StandupSet{_, b1, b2} : T.Payload}
      %field1 : {T.StandupSet{a0, a1, a2} == T.StandupSet{a0, _, b2} : T.Payload}
      %field2 : {T.StandupSet{a0, a1, a2} == T.StandupSet{a0, a1, _} : T.Payload}
      {==}
    case T.StandupSet{+a0, +a1, +a2} T.Opaque{+b0}:
      Empty.absurd({T.StandupSet{a0, a1, a2} == T.Opaque{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.Created{+b0, +b1, +b2, +b3, +b4, +b5}:
      Empty.absurd({T.Opaque{a0} == T.Created{b0, b1, b2, b3, b4, b5} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.StatusChanged{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.StatusChanged{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.Noted{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.Noted{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.Edited{+b0, +b1}:
      Empty.absurd({T.Opaque{a0} == T.Edited{b0, b1} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.Deleted{+b0}:
      Empty.absurd({T.Opaque{a0} == T.Deleted{b0} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.SummarySet{+b0, +b1, +b2}:
      Empty.absurd({T.Opaque{a0} == T.SummarySet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.StandupSet{+b0, +b1, +b2}:
      Empty.absurd({T.Opaque{a0} == T.StandupSet{b0, b1, b2} : T.Payload}, Laws.false_is_not_true(equality))
    case T.Opaque{+a0} T.Opaque{+b0}:
      field0 = Laws.string_equality_sound(a0, b0, equality)
      %field0 : {T.Opaque{a0} == T.Opaque{_} : T.Payload}
      {==}

def Laws.event_equality_sound(a, b, equality):
  match a b:
    case T.Ev{+a0, +a1, +a2, +a3, +a4} T.Ev{+b0, +b1, +b2, +b3, +b4}:
      comparison0 = Laws.and_true_left(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)))), equality)
      +remaining1 = Laws.and_true_right(String.eq(a0, b0), Bool.and(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)))), equality)
      field0 = Laws.string_equality_sound(a0, b0, comparison0)
      comparison1 = Laws.and_true_left(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4))), remaining1)
      +remaining2 = Laws.and_true_right(String.eq(a1, b1), Bool.and(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4))), remaining1)
      field1 = Laws.string_equality_sound(a1, b1, comparison1)
      comparison2 = Laws.and_true_left(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)), remaining2)
      +remaining3 = Laws.and_true_right(String.eq(a2, b2), Bool.and(Core.payload_eq(a3, b3), String.eq(a4, b4)), remaining2)
      field2 = Laws.string_equality_sound(a2, b2, comparison2)
      comparison3 = Laws.and_true_left(Core.payload_eq(a3, b3), String.eq(a4, b4), remaining3)
      +remaining4 = Laws.and_true_right(Core.payload_eq(a3, b3), String.eq(a4, b4), remaining3)
      field3 = Laws.payload_equality_sound(a3, b3, comparison3)
      field4 = Laws.string_equality_sound(a4, b4, remaining4)
      %field0 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{_, b1, b2, b3, b4} : T.DomainEvent}
      %field1 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, _, b2, b3, b4} : T.DomainEvent}
      %field2 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, _, b3, b4} : T.DomainEvent}
      %field3 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, a2, _, b4} : T.DomainEvent}
      %field4 : {T.Ev{a0, a1, a2, a3, a4} == T.Ev{a0, a1, a2, a3, _} : T.DomainEvent}
      {==}

def Laws.string_propositional_equality_detected(a, b, equality):
  Equal.trans(Bool, String.eq(a, b), String.eq(b, b), True{},
    Equal.cong(String, Bool, left => String.eq(left, b), a, b, equality), Laws.string_equality_reflexive(b))

def Laws.event_inequality_is_detected(a, b, different):
  Laws.bool_not_true_is_false(Core.event_eq(a, b),
    same => different(Laws.event_equality_sound(a, b, same)))

def Laws.adjacent_content_conflict_is_rejected(event, previous, rest, acc, sameId, different):
  same_flag = Laws.string_propositional_equality_detected(Core.event_id(event), Core.event_id(previous), sameId)
  different_flag = Laws.event_inequality_is_detected(event, previous, different)
  condition = Laws.true_and(String.eq(Core.event_id(event), Core.event_id(previous)), Bool.not(Core.event_eq(event, previous)), same_flag,
    Equal.cong(Bool, Bool, same => Bool.not(same), Core.event_eq(event, previous), False{}, different_flag))
  Equal.cong(Bool, T.MergeResult,
    conflict => Bool.pick(T.MergeResult, conflict, T.EventConflict{Core.event_id(event)},
      Core.scan_ids(rest, Core.unique_put(event, acc, String.eq(Core.event_id(event), Core.event_id(previous))), Some{event})),
    Bool.and(String.eq(Core.event_id(event), Core.event_id(previous)), Bool.not(Core.event_eq(event, previous))), True{}, condition)

def Laws.inconsistent_events_exist():
  (Laws.collision_a(), (Laws.collision_b(), ({==},
    same => Laws.false_is_not_true(Equal.cong(T.DomainEvent, Bool, value => Core.event_eq(value, Laws.collision_b()), Laws.collision_a(), Laws.collision_b(), same)))))

def Laws.exact_membership_bridge(events, target):
  match events:
    case Nil{}:
      {==}
    case +h <> t:
      Equal.cong(Bool, Bool, member => Bool.or(Core.event_eq(h, target), member),
        Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, t), Core.exact_contains(t, target), Laws.exact_membership_bridge(t, target))

def Laws.id_sort_preserves_exact_events(events, target):
  Equal.trans(Bool,
    Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Core.exact_contains(events, target),
    Equal.sym(Bool, Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target), Laws.exact_membership_bridge(List.sort(~T.DomainEvent, ~Core.event_id_le, events), target)),
    Equal.trans(Bool,
      Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_id_le, events)), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, events), Core.exact_contains(events, target),
      Membership.sort(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, ~Core.event_id_le, target, events), Laws.exact_membership_bridge(events, target)))

def Laws.chronological_sort_preserves_exact_events(events, target):
  Equal.trans(Bool,
    Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_le, events), target), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Core.exact_contains(events, target),
    Equal.sym(Bool, Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_le, events), target), Laws.exact_membership_bridge(List.sort(~T.DomainEvent, ~Core.event_le, events), target)),
    Equal.trans(Bool,
      Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, List.sort(~T.DomainEvent, ~Core.event_le, events)), Membership.any(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, target, events), Core.exact_contains(events, target),
      Membership.sort(~T.DomainEvent, ~T.DomainEvent, ~Laws.event_matches, ~Core.event_le, target, events), Laws.exact_membership_bridge(events, target)))

def Laws.exact_append(xs, ys, target):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.trans(Bool,
        Core.exact_contains(List.append(&2, T.DomainEvent, h <> t, ys), target), Bool.or(Core.event_eq(h, target), Bool.or(Core.exact_contains(t, target), Core.exact_contains(ys, target))),
        Bool.or(Core.exact_contains(h <> t, target), Core.exact_contains(ys, target)),
        Equal.cong(Bool, Bool, member => Bool.or(Core.event_eq(h, target), member), Core.exact_contains(List.append(&2, T.DomainEvent, t, ys), target),
          Bool.or(Core.exact_contains(t, target), Core.exact_contains(ys, target)), Laws.exact_append(t, ys, target)),
        Laws.or_associative(Core.event_eq(h, target), Core.exact_contains(t, target), Core.exact_contains(ys, target)))

def Laws.exact_member_absorption(events, present, target, covered):
  Laws.boolean_absorption(Core.event_eq(present, target), Core.exact_contains(events, target),
    same => Equal.trans(Bool, Core.exact_contains(events, target), Core.exact_contains(events, present), True{},
      Equal.cong(T.DomainEvent, Bool, event => Core.exact_contains(events, event), target, present,
        Equal.sym(T.DomainEvent, present, target, Laws.event_equality_sound(present, target, same))), covered))

def Laws.exact_member_self_head(event, rest):
  Equal.cong(Bool, Bool, same => Bool.or(same, Core.exact_contains(rest, event)), Core.event_eq(event, event), True{}, Laws.event_equality_reflexive(event))

def ScanProof.rewrite_contents(result: T.MergeResult, +target: T.DomainEvent, a: Bool, b: Bool,
  equality: {a == b : Bool}, proof: Laws.SuccessfulContents(result, target, a)) -> Laws.SuccessfulContents(result, target, b):
  match result:
    case T.EventConflict{conflictId}:
      Unit{}
    case T.Merged{events}:
      Equal.trans(Bool, Core.exact_contains(events, target), a, b, proof, equality)

def ExactScan.step(+h: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, +previous: T.DomainEvent, +target: T.DomainEvent, same: Bool, equal: Bool,
  actual_equal: {equal == Core.event_eq(h, previous) : Bool}, covered: {Core.exact_contains(acc, previous) == True{} : Bool},
  continuation: {Core.exact_contains(Core.unique_put(h, acc, same), h) == True{} : Bool} -> Laws.SuccessfulContents(Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h}), target, Bool.or(Core.exact_contains(tail, target), Core.exact_contains(Core.unique_put(h, acc, same), target)))) ->
  Laws.SuccessfulContents(Bool.pick(T.MergeResult, Bool.and(same, Bool.not(equal)), T.EventConflict{Core.event_id(h)}, Core.scan_ids(tail, Core.unique_put(h, acc, same), Some{h})), target, Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target))):
  match same equal:
    case False{} False{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        continuation(Laws.exact_member_self_head(h, acc)))
    case False{} True{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        continuation(Laws.exact_member_self_head(h, acc)))
    case True{} False{}:
      Unit{}
    case True{} True{}:
      same_event = Laws.event_equality_sound(h, previous, Equal.sym(Bool, True{}, Core.event_eq(h, previous), actual_equal))
      +covered_head = Equal.trans(Bool, Core.exact_contains(acc, h), Core.exact_contains(acc, previous), True{},
        Equal.cong(T.DomainEvent, Bool, event => Core.exact_contains(acc, event), h, previous, same_event), covered)
      ScanProof.rewrite_contents(Core.scan_ids(tail, acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        Equal.trans(Bool,
          Bool.or(Core.exact_contains(tail, target), Core.exact_contains(acc, target)), Bool.or(Core.exact_contains(tail, target), Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target))),
          Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
          Equal.cong(Bool, Bool, member => Bool.or(Core.exact_contains(tail, target), member), Core.exact_contains(acc, target), Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target)),
            Equal.sym(Bool, Bool.or(Core.event_eq(h, target), Core.exact_contains(acc, target)), Core.exact_contains(acc, target), Laws.exact_member_absorption(acc, h, target, covered_head))),
          ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target))), continuation(covered_head))

def Laws.scan_preserves_exact_events(fuel, acc, previous, target, covered):
  match fuel previous:
    case Nil{} _:
      Laws.chronological_sort_preserves_exact_events(acc, target)
    case +h <> +tail None{}:
      ScanProof.rewrite_contents(Core.scan_ids(tail, h <> acc, Some{h}), target,
        Bool.or(Core.exact_contains(tail, target), Core.exact_contains(h <> acc, target)), Bool.or(Core.exact_contains(h <> tail, target), Core.exact_contains(acc, target)),
        ScanProof.shuffle(Core.event_eq(h, target), Core.exact_contains(tail, target), Core.exact_contains(acc, target)),
        Laws.scan_preserves_exact_events(tail, h <> acc, Some{h}, target, Laws.exact_member_self_head(h, acc)))
    case +h <> +tail Some{+p}:
      ExactScan.step(h, tail, acc, p, target, String.eq(Core.event_id(h), Core.event_id(p)), Core.event_eq(h, p), {==}, covered,
        next_covered => Laws.scan_preserves_exact_events(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}, target, next_covered))

def Laws.merge_preserves_exact_events(left, right, target):
  ScanProof.rewrite_contents(Core.merge(left, right), target,
    Bool.or(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), False{}),
    Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)),
    Equal.trans(Bool,
      Bool.or(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), False{}), Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target),
      Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)),
      Laws.or_false_right(Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target)),
      Equal.trans(Bool, Core.exact_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), target), Core.exact_contains(List.append(&2, T.DomainEvent, left, right), target),
        Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)), Laws.id_sort_preserves_exact_events(List.append(&2, T.DomainEvent, left, right), target), Laws.exact_append(left, right, target))),
    Laws.scan_preserves_exact_events(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{}, target, Unit{}))

def Laws.successful_merge_has_exact_input_events(left, right, output, target, success):
  %success : Laws.SuccessfulContents(_, target, Bool.or(Core.exact_contains(left, target), Core.exact_contains(right, target)))
  Laws.merge_preserves_exact_events(left, right, target)

def Laws.semantically_absent_has_no_exact_match(events, target, absent):
  match events:
    case Nil{}:
      {==}
    case +h <> t:
      (different, absent_tail) = absent
      Equal.trans(Bool, Core.exact_contains(h <> t, target), Bool.or(False{}, Core.exact_contains(t, target)), False{},
        Equal.cong(Bool, Bool, same => Bool.or(same, Core.exact_contains(t, target)), Core.event_eq(h, target), False{}, Laws.event_inequality_is_detected(h, target, different)),
        Laws.semantically_absent_has_no_exact_match(t, target, absent_tail))

def Laws.semantically_unapproved_event_remains_pending(event, rest, committed, absent):
  Laws.unapproved_event_remains_pending(event, rest, committed, Laws.semantically_absent_has_no_exact_match(committed, event, absent))

def Laws.id_sort_preserves_id_occurrences(events, id):
  Count.sort(~T.DomainEvent, ~String, ~Laws.id_matches, ~Core.event_id_le, id, events)

def Laws.chronological_sort_preserves_id_occurrences(events, id):
  Count.sort(~T.DomainEvent, ~String, ~Laws.id_matches, ~Core.event_le, id, events)

def Laws.singleton_has_one_id_occurrence(event):
  Equal.cong(Bool, Nat, same => Nat.add(Count.weight(same), 0n), String.eq(Core.event_id(event), Core.event_id(event)), True{}, Laws.string_equality_reflexive(Core.event_id(event)))

def Laws.id_count_refines_unique_counter(events, id):
  match events:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(Nat, Nat, n => Nat.add(Count.weight(String.eq(Core.event_id(h), id)), n),
        Laws.id_count(t, id), Unique.id_count(t, id), Laws.id_count_refines_unique_counter(t, id))

def Laws.successful_merge_has_unique_ids(left, right, output, id, success):
  Equal.trans(Bool, Nat.is_le(Laws.id_count(output, id), 1n), Nat.is_le(Unique.id_count(output, id), 1n), True{},
    Equal.cong(Nat, Bool, n => Nat.is_le(n, 1n), Laws.id_count(output, id), Unique.id_count(output, id), Laws.id_count_refines_unique_counter(output, id)),
    Unique.successful_merge_has_at_most_one_occurrence_per_id(left, right, output, id, success))

def Laws.successful_merge_has_structurally_unique_ids(left, right, output, success):
  Unique.successful_merge_unique_bool(left, right, output, success)

def OrderedScan.pick(condition: Bool, conflictId: String, result: T.MergeResult, proof: Laws.SuccessfulOrdered(result)) ->
  Laws.SuccessfulOrdered(Bool.pick(T.MergeResult, condition, T.EventConflict{conflictId}, result)):
  match condition:
    case False{}:
      proof
    case True{}:
      Unit{}

def OrderedScan.scan(fuel: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, previous: Maybe<&2, T.DomainEvent>) -> Laws.SuccessfulOrdered(Core.scan_ids(fuel, acc, previous)):
  match fuel previous:
    case Nil{} _:
      ChronologicalSort.sort_ordered(acc)
    case h <> tail None{}:
      OrderedScan.scan(tail, h <> acc, Some{h})
    case +h <> +tail Some{+p}:
      OrderedScan.pick(Bool.and(String.eq(Core.event_id(h), Core.event_id(p)), Bool.not(Core.event_eq(h, p))), Core.event_id(h),
        Core.scan_ids(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}),
        OrderedScan.scan(tail, Core.unique_put(h, acc, String.eq(Core.event_id(h), Core.event_id(p))), Some{h}))

def Laws.successful_merge_is_chronologically_ordered(left, right, output, success):
  %success : Laws.SuccessfulOrdered(_)
  OrderedScan.scan(List.sort(~T.DomainEvent, ~Core.event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{})

def ConflictProof.same_head_a(+head: T.DomainEvent, +a: T.DomainEvent, +b: T.DomainEvent,
  sameId: {Core.event_id(a) == Core.event_id(b) : String}, same_head: {Core.event_eq(head, a) == True{} : Bool}) -> {Core.event_id(b) == Core.event_id(head) : String}:
  head_is_a = Laws.event_equality_sound(head, a, same_head)
  Equal.sym(String, Core.event_id(head), Core.event_id(b),
    Equal.trans(String, Core.event_id(head), Core.event_id(a), Core.event_id(b),
      Equal.cong(T.DomainEvent, String, event => Core.event_id(event), head, a, head_is_a), sameId))

def ConflictProof.same_head_b(+head: T.DomainEvent, +a: T.DomainEvent, +b: T.DomainEvent,
  sameId: {Core.event_id(a) == Core.event_id(b) : String}, same_head: {Core.event_eq(head, b) == True{} : Bool}) -> {Core.event_id(a) == Core.event_id(head) : String}:
  head_is_b = Laws.event_equality_sound(head, b, same_head)
  Equal.trans(String, Core.event_id(a), Core.event_id(b), Core.event_id(head), sameId,
    Equal.sym(String, Core.event_id(head), Core.event_id(b), Equal.cong(T.DomainEvent, String, event => Core.event_id(event), head, b, head_is_b)))

def ConflictProof.unique_members_step(+head: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +a: T.DomainEvent, +b: T.DomainEvent, atHead: Bool, btHead: Bool,
  linkA: {Core.event_eq(head, a) == atHead : Bool}, linkB: {Core.event_eq(head, b) == btHead : Bool}, sameId: {Core.event_id(a) == Core.event_id(b) : String},
  +unique: {Unique.unique_ids(head <> tail) == True{} : Bool}, presentA: {Core.exact_contains(head <> tail, a) == True{} : Bool}, presentB: {Core.exact_contains(head <> tail, b) == True{} : Bool},
  continuation: {Unique.unique_ids(tail) == True{} : Bool} -> {Core.exact_contains(tail, a) == True{} : Bool} -> {Core.exact_contains(tail, b) == True{} : Bool} -> {a == b : T.DomainEvent}) -> {a == b : T.DomainEvent}:
  match atHead btHead:
    case True{} True{}:
      Equal.trans(T.DomainEvent, a, head, b, Equal.sym(T.DomainEvent, head, a, Laws.event_equality_sound(head, a, linkA)), Laws.event_equality_sound(head, b, linkB))
    case True{} False{}:
      Empty.absurd({a == b : T.DomainEvent}, Canonical.absent_matching_tail(head, tail, b,
        ConflictProof.same_head_a(head, a, b, sameId, linkA), Unique.unique_head_absent(head, tail, unique), presentB, linkB))
    case False{} True{}:
      Empty.absurd({a == b : T.DomainEvent}, Canonical.absent_matching_tail(head, tail, a,
        ConflictProof.same_head_b(head, a, b, sameId, linkB), Unique.unique_head_absent(head, tail, unique), presentA, linkA))
    case False{} False{}:
      continuation(Unique.unique_tail(head, tail, unique), Canonical.member_tail(head, tail, a, linkA, presentA), Canonical.member_tail(head, tail, b, linkB, presentB))

def Laws.unique_id_members_are_equal(events, a, b, sameId, unique, present_a, present_b):
  match events:
    case Nil{}:
      Empty.absurd({a == b : T.DomainEvent}, Laws.false_is_not_true(present_a))
    case +head <> +tail:
      ConflictProof.unique_members_step(head, tail, a, b, Core.event_eq(head, a), Core.event_eq(head, b), {==}, {==}, sameId, unique, present_a, present_b,
        unique_tail => member_a => member_b => Laws.unique_id_members_are_equal(tail, a, b, sameId, unique_tail, member_a, member_b))

def Laws.inconsistent_event_union_has_no_successful_merge(left, right, a, b, sameId, different, present_a, present_b, output, success):
  member_a = Equal.trans(Bool, Core.exact_contains(output, a), Bool.or(Core.exact_contains(left, a), Core.exact_contains(right, a)), True{},
    Laws.successful_merge_has_exact_input_events(left, right, output, a, success), present_a)
  member_b = Equal.trans(Bool, Core.exact_contains(output, b), Bool.or(Core.exact_contains(left, b), Core.exact_contains(right, b)), True{},
    Laws.successful_merge_has_exact_input_events(left, right, output, b, success), present_b)
  different(Laws.unique_id_members_are_equal(output, a, b, sameId, Unique.successful_merge_unique_bool(left, right, output, success), member_a, member_b))

def ConflictProof.capture(result: T.MergeResult, +left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +a: T.DomainEvent, +b: T.DomainEvent,
  sameId: {Core.event_id(a) == Core.event_id(b) : String}, different: {a != b : T.DomainEvent},
  present_a: {Bool.or(Core.exact_contains(left, a), Core.exact_contains(right, a)) == True{} : Bool}, present_b: {Bool.or(Core.exact_contains(left, b), Core.exact_contains(right, b)) == True{} : Bool},
  link: {result == Core.merge(left, right) : T.MergeResult}) -> &conflictId: String -> {Core.merge(left, right) == T.EventConflict{conflictId} : T.MergeResult}:
  match result:
    case T.EventConflict{id}:
      (id, Equal.sym(T.MergeResult, T.EventConflict{id}, Core.merge(left, right), link))
    case T.Merged{output}:
      Empty.absurd(&conflictId: String -> {Core.merge(left, right) == T.EventConflict{conflictId} : T.MergeResult},
        Laws.inconsistent_event_union_has_no_successful_merge(left, right, a, b, sameId, different, present_a, present_b, output,
          Equal.sym(T.MergeResult, T.Merged{output}, Core.merge(left, right), link)))

def Laws.inconsistent_event_union_returns_conflict(left, right, a, b, sameId, different, present_a, present_b):
  ConflictProof.capture(Core.merge(left, right), left, right, a, b, sameId, different, present_a, present_b, {==})

def CommandProof.complete(+event: T.DomainEvent, +state: T.State, existing: List<&2, T.DomainEvent>, valid: Bool,
  actual: {valid == Core.complete(state) : Bool}, replayed: {Core.replay(List.append(&2, T.DomainEvent, existing, [event])) == T.Replayed{state} : T.ReplayResult}) ->
  Laws.AcceptedComplete(Core.stage_candidate_complete(event, valid), existing):
  match valid:
    case False{}:
      Unit{}
    case True{}:
      (state, (replayed, Equal.sym(Bool, True{}, Core.complete(state), actual)))

def CommandProof.replayed(result: T.ReplayResult, +event: T.DomainEvent, existing: List<&2, T.DomainEvent>,
  link: {Core.replay(List.append(&2, T.DomainEvent, existing, [event])) == result : T.ReplayResult}) ->
  Laws.AcceptedComplete(Core.stage_candidate_replayed(result, event), existing):
  match result:
    case T.ReplayConflict{id}:
      Unit{}
    case T.Replayed{+state}:
      CommandProof.complete(event, state, existing, Core.complete(state), {==}, link)

def CommandProof.proposed(result: T.StageResult, +existing: List<&2, T.DomainEvent>) -> Laws.AcceptedComplete(Core.stage_proposed(result, existing), existing):
  match result:
    case T.StageRejected{reason}:
      Unit{}
    case T.StageAccepted{+event}:
      CommandProof.replayed(Core.replay(List.append(&2, T.DomainEvent, existing, [event])), event, existing, {==})

def Laws.accepted_command_has_complete_prospective_replay(existing, input, accepted, acceptance):
  %acceptance : Laws.AcceptedComplete(_, existing)
  CommandProof.proposed(Core.stage_unique(input, existing, Core.ids_contains(existing, Core.event_id(input))), existing)
