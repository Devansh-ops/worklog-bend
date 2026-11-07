import Base
import ./LAWS.bend as Laws
import ./bend/Types.bend as T
import ./bend/Core.bend as Core
import ./bend/Publication.bend as Publication
import ./bend/Reports.bend as Reports

def Laws.future_schema_refused_witness():
  {==}

def Laws.changed_plan_refused_witness():
  {==}

def Laws.reminder_disabled_witness():
  {==}

def Laws.reminder_complete_day_witness():
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
