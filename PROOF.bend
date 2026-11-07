import Base
import ./LAWS.bend as Laws
import ./bend/Types.bend as T
import ./bend/Core.bend as Core
import ./bend/Publication.bend as Publication

def Laws.future_schema_refused_witness():
  {==}

def Laws.changed_plan_refused_witness():
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
