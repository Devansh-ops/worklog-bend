import Base
import ./bend/Types.bend as T
import ./bend/Core.bend as Core
import ./bend/Publication.bend as Publication

# Supporting order facts for canonical event identity and sorting.
# These are not substitutes for the full merge membership/algebra obligations.
law word_order_reflexive:
  for n: Nat
  for w: Word(n)
  {Word.cmp(n, w, w) == EQ{} : Cmp}

law u32_order_reflexive:
  for x: U32
  {U32.cmp(x, x) == EQ{} : Cmp}

law string_order_reflexive:
  for s: String
  {String.order(s, s) == EQ{} : Cmp}

law string_equality_reflexive:
  for s: String
  {String.eq(s, s) == True{} : Bool}

# Independent specification: completion is present exactly for Done.
def CompletionMatches(status: T.Status, instant: String, result: Maybe<&2, String>) -> Type:
  match status:
    case T.SDone{}:
      {result == Some{instant} : Maybe<&2, String>}
    case _:
      {result == None{} : Maybe<&2, String>}

law completion_metadata:
  for status: T.Status
  for instant: String
  CompletionMatches(status, instant, Core.completion(status, instant))

def force_private(task: T.Task) -> T.Task:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      T.Task{id, title, status, priority, tags, True{}, deleted, created, updated, completed, notes}

def task_completion(task: T.Task) -> Maybe<&2, String>:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      completed

law private_is_ineligible:
  for task: T.Task
  {Core.eligible(force_private(task)) == False{} : Bool}

law deleted_is_ineligible:
  for task: T.Task
  for instant: String
  {Core.eligible(Core.delete_task(task, instant)) == False{} : Bool}

law deletion_preserves_tombstone:
  for task: T.Task
  for instant: String
  {Core.task_deleted(Core.delete_task(task, instant)) == True{} : Bool}

law edit_cannot_resurrect:
  for task: T.Task
  for patch: T.Patch
  for instant: String
  {Core.task_deleted(Core.edit_task(task, patch, instant)) == Core.task_deleted(task) : Bool}

law note_cannot_resurrect:
  for task: T.Task
  for note: T.Note
  for instant: String
  {Core.task_deleted(Core.note_task(task, note, instant)) == Core.task_deleted(task) : Bool}

law notes_off_omits_all_direct_notes:
  for task: T.Task
  {Core.context_notes(Core.project(task, False{})) == Nil{} : List<&2, T.Note>}

law edit_without_status_keeps_completion:
  for task: T.Task
  for title: Maybe<&2, String>
  for priority: Maybe<&2, T.Priority>
  for tags: Maybe<&2, List<&2, String>>
  for private: Maybe<&2, Bool>
  for instant: String
  {task_completion(Core.edit_task(task, T.Patch{title, None{}, priority, tags, private}, instant)) == task_completion(task) : Maybe<&2, String>}

law edit_to_done_records_completion:
  for task: T.Task
  for instant: String
  {task_completion(Core.edit_task(task, T.Patch{None{}, Some{T.SDone{}}, None{}, None{}, None{}}, instant)) == Some{instant} : Maybe<&2, String>}

law edit_to_todo_clears_completion:
  for task: T.Task
  for instant: String
  {task_completion(Core.edit_task(task, T.Patch{None{}, Some{T.STodo{}}, None{}, None{}, None{}}, instant)) == None{} : Maybe<&2, String>}

law private_context_head_is_omitted:
  for task: T.Task
  for rest: List<&2, T.Task>
  for sendNotes: Bool
  {Core.context_tasks(force_private(task) <> rest, sendNotes) == Core.context_tasks(rest, sendNotes) : List<&2, T.ContextTask>}

law deleted_context_head_is_omitted:
  for task: T.Task
  for instant: String
  for rest: List<&2, T.Task>
  for sendNotes: Bool
  {Core.context_tasks(Core.delete_task(task, instant) <> rest, sendNotes) == Core.context_tasks(rest, sendNotes) : List<&2, T.ContextTask>}

def context_has_no_notes(tasks: List<&2, T.ContextTask>) -> Bool:
  match tasks:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(List.is_empty(&2, T.Note, Core.context_notes(h)), context_has_no_notes(t))

law notes_off_context_has_no_notes:
  for tasks: List<&2, T.Task>
  {context_has_no_notes(Core.context_tasks(tasks, False{})) == True{} : Bool}

law incomplete_state_withholds_context:
  for tasks: List<&2, T.Task>
  for summaries: List<&2, T.Recorded>
  for reports: List<&2, T.Recorded>
  for diagnostics: List<&2, T.Diagnostic>
  for sendNotes: Bool
  {Core.context(T.State{tasks, summaries, reports, diagnostics, False{}}, sendNotes) == Nil{} : List<&2, T.ContextTask>}

law failed_publication_preserves_pending:
  for pending: List<&2, T.DomainEvent>
  for committed: List<&2, T.DomainEvent>
  {Core.acknowledge(pending, committed, False{}) == pending : List<&2, T.DomainEvent>}

law empty_approval_preserves_pending:
  for pending: List<&2, T.DomainEvent>
  {Core.acknowledge(pending, Nil{}, True{}) == pending : List<&2, T.DomainEvent>}

# An explicit noncircular precondition: this event does not exactly match any
# event in the committed plan. The empty committed list is a concrete witness.
law unapproved_event_remains_pending:
  for event: T.DomainEvent
  for rest: List<&2, T.DomainEvent>
  for committed: List<&2, T.DomainEvent>
  for absent: {Core.exact_contains(committed, event) == False{} : Bool}
  {Core.acknowledge(event <> rest, committed, True{}) == event <> Core.acknowledge(rest, committed, True{}) : List<&2, T.DomainEvent>}

# Numeric facts, rather than a hypothesis about schema_allowed's own result.
law unrecognized_schema_is_refused:
  for version: U32
  for not_one: {U32.is_eq(version, 1) == False{} : Bool}
  for not_two: {U32.is_eq(version, 2) == False{} : Bool}
  {Core.schema_allowed(version) == False{} : Bool}

# Nonvacuous witnesses for the policy and schema premises above.
law eligible_task_exists:
  exs task: T.Task
  {Core.eligible(task) == True{} : Bool}

law unsupported_schema_exists:
  exs version: U32
  {U32.is_eq(version, 1) == False{} : Bool} & {U32.is_eq(version, 2) == False{} : Bool}

law true_and:
  for -a: Bool
  for -b: Bool
  for pa: {a == True{} : Bool}
  for pb: {b == True{} : Bool}
  {Bool.and(a, b) == True{} : Bool}

law bool_equality_reflexive:
  for b: Bool
  {Core.bool_eq(b, b) == True{} : Bool}

law status_equality_reflexive:
  for status: T.Status
  {Core.status_eq(status, status) == True{} : Bool}

law priority_equality_reflexive:
  for priority: T.Priority
  {Core.priority_eq(priority, priority) == True{} : Bool}

law strings_equality_reflexive:
  for strings: List<&2, String>
  {Core.strings_eq(strings, strings) == True{} : Bool}

law optional_string_equality_reflexive:
  for value: Maybe<&2, String>
  {Core.optional_string_eq(value, value) == True{} : Bool}

law optional_status_equality_reflexive:
  for value: Maybe<&2, T.Status>
  {Core.optional_status_eq(value, value) == True{} : Bool}

law optional_priority_equality_reflexive:
  for value: Maybe<&2, T.Priority>
  {Core.optional_priority_eq(value, value) == True{} : Bool}

law optional_strings_equality_reflexive:
  for value: Maybe<&2, List<&2, String>>
  {Core.optional_strings_eq(value, value) == True{} : Bool}

law optional_bool_equality_reflexive:
  for value: Maybe<&2, Bool>
  {Core.optional_bool_eq(value, value) == True{} : Bool}

law patch_equality_reflexive:
  for patch: T.Patch
  {Core.patch_eq(patch, patch) == True{} : Bool}

law payload_equality_reflexive:
  for payload: T.Payload
  {Core.payload_eq(payload, payload) == True{} : Bool}

law event_equality_reflexive:
  for event: T.DomainEvent
  {Core.event_eq(event, event) == True{} : Bool}

law identical_pair_sort:
  for event: T.DomainEvent
  for order: Bool
  {List.sort.pair(T.DomainEvent, event, event, order) == [event, event] : List<&2, T.DomainEvent>}

law scan_identical_pair:
  for +event: T.DomainEvent
  {Core.scan_ids([event, event], Nil{}, None{}) == T.Merged{[event]} : T.MergeResult}

# Universal duplicate-delivery law for every complete event value, including
# all payload variants and retained canonical data. General-list algebra is a
# separate obligation and is not implied by this two-delivery theorem.
law duplicate_delivery_single_event:
  for +event: T.DomainEvent
  {Core.merge([event], [event]) == T.Merged{[event]} : T.MergeResult}

law create_done_has_completion:
  for taskId: String
  for title: String
  for priority: T.Priority
  for tags: List<&2, String>
  for private: Bool
  for eventId: String
  for instant: String
  for day: String
  for canonical: String
  {Core.apply_event(Core.empty_state(), T.Ev{eventId, instant, day, T.Created{taskId, title, T.SDone{}, priority, tags, private}, canonical}) == T.State{[T.Task{taskId, title, T.SDone{}, priority, tags, private, False{}, instant, instant, Some{instant}, Nil{}}], Nil{}, Nil{}, Nil{}, True{}} : T.State}

law status_done_has_completion:
  for task: T.Task
  for taskId: String
  for eventId: String
  for instant: String
  {task_completion(Core.apply_payload(task, T.StatusChanged{taskId, T.SDone{}}, eventId, instant)) == Some{instant} : Maybe<&2, String>}

law status_todo_clears_completion:
  for task: T.Task
  for taskId: String
  for eventId: String
  for instant: String
  {task_completion(Core.apply_payload(task, T.StatusChanged{taskId, T.STodo{}}, eventId, instant)) == None{} : Maybe<&2, String>}

law updates_after_deletion_are_diagnostic:
  for state: T.State
  for task: T.Task
  for payload: T.Payload
  for eventId: String
  for instant: String
  for deletionInstant: String
  {Core.update_found(state, payload, eventId, instant, Core.task_id(task), Some{Core.delete_task(task, deletionInstant)}) == Core.diagnostic(state, T.AfterDelete{eventId, Core.task_id(task)}) : T.State}

law unknown_event_withholds_context:
  for state: T.State
  for eventId: String
  for instant: String
  for day: String
  for kind: String
  for canonical: String
  for sendNotes: Bool
  {Core.context(Core.apply_event(state, T.Ev{eventId, instant, day, T.Opaque{kind}, canonical}), sendNotes) == Nil{} : List<&2, T.ContextTask>}

def false_true_discriminator(value: Bool) -> Type:
  match value:
    case False{}:
      Empty
    case True{}:
      Unit

law false_is_not_true:
  for contradiction: {False{} == True{} : Bool}
  Empty

law bool_order_equality_sound:
  for a: Bool
  for b: Bool
  for equality: {Bool.cmp(a, b) == EQ{} : Cmp}
  {a == b : Bool}

law word_cmp_fin_tail:
  for a: Bool
  for b: Bool
  for tail: Cmp
  for equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}
  {tail == EQ{} : Cmp}

law word_cmp_fin_head:
  for a: Bool
  for b: Bool
  for tail: Cmp
  for tail_equal: {tail == EQ{} : Cmp}
  for equality: {Word.cmp.fin(a, b, tail) == EQ{} : Cmp}
  {Bool.cmp(a, b) == EQ{} : Cmp}

law word_order_equality_sound:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for +equality: {Word.cmp(n, a, b) == EQ{} : Cmp}
  {a == b : Word(n)}

law u32_order_equality_sound:
  for a: U32
  for b: U32
  for equality: {U32.cmp(a, b) == EQ{} : Cmp}
  {a == b : U32}

law string_order_go_lt:
  for a: String
  for b: String
  {String.order.go(a, b, LT{}) == LT{} : Cmp}

law string_order_go_gt:
  for a: String
  for b: String
  {String.order.go(a, b, GT{}) == GT{} : Cmp}

law string_order_go_eq_premise:
  for a: String
  for b: String
  for order: Cmp
  for equality: {String.order.go(a, b, order) == EQ{} : Cmp}
  {order == EQ{} : Cmp}

law string_order_equality_sound:
  for a: String
  for b: String
  for +equality: {String.order(a, b) == EQ{} : Cmp}
  {a == b : String}

law cmp_is_eq_sound:
  for order: Cmp
  for equality: {Cmp.is_eq(order) == True{} : Bool}
  {order == EQ{} : Cmp}

law string_equality_sound:
  for +a: String
  for +b: String
  for equality: {String.eq(a, b) == True{} : Bool}
  {a == b : String}

law and_false_right:
  for value: Bool
  {Bool.and(value, False{}) == False{} : Bool}

law and_true_right:
  for a: Bool
  for b: Bool
  for equality: {Bool.and(a, b) == True{} : Bool}
  {b == True{} : Bool}

law publication_requires_exact_plan:
  for schemas: List<&2, U32>
  for +approvedPlan: String
  for +executionPlan: String
  for accepted: {Publication.approved(schemas, approvedPlan, executionPlan) == True{} : Bool}
  {approvedPlan == executionPlan : String}

law bool_not_true_is_false:
  for value: Bool
  for reject: {value == True{} : Bool} -> Empty
  {value == False{} : Bool}

law publication_rejects_changed_plan:
  for +schemas: List<&2, U32>
  for +approvedPlan: String
  for +executionPlan: String
  for different: {approvedPlan != executionPlan : String}
  {Publication.approved(schemas, approvedPlan, executionPlan) == False{} : Bool}

law unsupported_schema_anywhere:
  for prefix: List<&2, U32>
  for suffix: List<&2, U32>
  for version: U32
  for not_one: {U32.is_eq(version, 1) == False{} : Bool}
  for not_two: {U32.is_eq(version, 2) == False{} : Bool}
  {Publication.schemas_compatible(List.append(&2, U32, prefix, version <> suffix)) == False{} : Bool}

law publication_rejects_unsupported_schema_anywhere:
  for prefix: List<&2, U32>
  for suffix: List<&2, U32>
  for version: U32
  for approvedPlan: String
  for executionPlan: String
  for not_one: {U32.is_eq(version, 1) == False{} : Bool}
  for not_two: {U32.is_eq(version, 2) == False{} : Bool}
  {Publication.approved(List.append(&2, U32, prefix, version <> suffix), approvedPlan, executionPlan) == False{} : Bool}

law approved_publication_exists:
  exs plan: String
  {Publication.approved([1, 2], plan, plan) == True{} : Bool}

# Concrete counterexample witnesses also keep mutation checks independent of
# proof scripts that could need repair after a harmless definition refactor.
law future_schema_refused_witness:
  {Publication.approved([1, 999, 2], "same plan", "same plan") == False{} : Bool}

law changed_plan_refused_witness:
  {Publication.approved([1, 2], "approved plan", "substituted plan") == False{} : Bool}

law or_associative:
  for a: Bool
  for b: Bool
  for c: Bool
  {Bool.or(a, Bool.or(b, c)) == Bool.or(Bool.or(a, b), c) : Bool}

law or_commutative:
  for a: Bool
  for b: Bool
  {Bool.or(a, b) == Bool.or(b, a) : Bool}

law or_false_right:
  for a: Bool
  {Bool.or(a, False{}) == a : Bool}

law or_move_left:
  for a: Bool
  for b: Bool
  for c: Bool
  {Bool.or(a, Bool.or(b, c)) == Bool.or(b, Bool.or(a, c)) : Bool}

law ids_append:
  for xs: List<&2, T.DomainEvent>
  for +ys: List<&2, T.DomainEvent>
  for +id: String
  {Core.ids_contains(List.append(&2, T.DomainEvent, xs, ys), id) == Bool.or(Core.ids_contains(xs, id), Core.ids_contains(ys, id)) : Bool}

law ids_reverse_accumulator:
  for xs: List<&2, T.DomainEvent>
  for +acc: List<&2, T.DomainEvent>
  for +id: String
  {Core.ids_contains(List.reverse.go(&2, T.DomainEvent, xs, acc), id) == Bool.or(Core.ids_contains(xs, id), Core.ids_contains(acc, id)) : Bool}

def merge_state_ids(state: List<&2, T.DomainEvent> & List<&2, T.DomainEvent> & List<&2, T.DomainEvent>, +id: String) -> Bool:
  (acc, xs, ys) = state
  Bool.or(Core.ids_contains(acc, id), Bool.or(Core.ids_contains(xs, id), Core.ids_contains(ys, id)))

def runs_ids(runs: List<&2, List<&2, T.DomainEvent>>, +id: String) -> Bool:
  match runs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(Core.ids_contains(h, id), runs_ids(t, id))

law ids_concat:
  for runs: List<&2, List<&2, T.DomainEvent>>
  for +id: String
  {Core.ids_contains(List.concat(&2, T.DomainEvent, runs), id) == runs_ids(runs, id) : Bool}

law or_pair_swap:
  for a: Bool
  for b: Bool
  {Bool.or(a, Bool.or(b, False{})) == Bool.or(b, Bool.or(a, False{})) : Bool}

law id_sort_preserves_ids:
  for xs: List<&2, T.DomainEvent>
  for +id: String
  {Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_id_le, xs), id) == Core.ids_contains(xs, id) : Bool}

law chronological_sort_preserves_ids:
  for xs: List<&2, T.DomainEvent>
  for +id: String
  {Core.ids_contains(List.sort(~T.DomainEvent, ~Core.event_le, xs), id) == Core.ids_contains(xs, id) : Bool}

law boolean_absorption:
  for condition: Bool
  for member: Bool
  for implication: {condition == True{} : Bool} -> {member == True{} : Bool}
  {Bool.or(condition, member) == member : Bool}

law member_absorption:
  for +events: List<&2, T.DomainEvent>
  for +presentId: String
  for +id: String
  for present: {Core.ids_contains(events, presentId) == True{} : Bool}
  {Bool.or(String.eq(presentId, id), Core.ids_contains(events, id)) == Core.ids_contains(events, id) : Bool}

law member_self_head:
  for +event: T.DomainEvent
  for +rest: List<&2, T.DomainEvent>
  {Core.ids_contains(event <> rest, Core.event_id(event)) == True{} : Bool}

# A scan may omit a same-ID delivery only when its previous ID is already
# represented by the accumulator. None imposes no premise, inhabited by Unit.
def PreviousCovered(previous: Maybe<&2, T.DomainEvent>, acc: List<&2, T.DomainEvent>) -> Data:
  match previous:
    case None{}:
      Unit
    case Some{event}:
      {Core.ids_contains(acc, Core.event_id(event)) == True{} : Bool}

# Errors make no claim about output membership because they return no events.
# The public successful_merge_has_exact_input_ids law below extracts the actual
# output equality from an explicit successful result, not a correctness premise.
def SuccessfulIds(result: T.MergeResult, id: String, expected: Bool) -> Type:
  match result:
    case T.EventConflict{conflictId}:
      Unit
    case T.Merged{events}:
      {Core.ids_contains(events, id) == expected : Bool}

law scan_preserves_ids:
  for fuel: List<&2, T.DomainEvent>
  for +acc: List<&2, T.DomainEvent>
  for previous: Maybe<&2, T.DomainEvent>
  for +id: String
  for +covered: PreviousCovered(previous, acc)
  SuccessfulIds(Core.scan_ids(fuel, acc, previous), id, Bool.or(Core.ids_contains(fuel, id), Core.ids_contains(acc, id)))

law merge_preserves_ids:
  for +left: List<&2, T.DomainEvent>
  for +right: List<&2, T.DomainEvent>
  for +id: String
  SuccessfulIds(Core.merge(left, right), id, Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)))

law successful_merge_has_exact_input_ids:
  for left: List<&2, T.DomainEvent>
  for right: List<&2, T.DomainEvent>
  for output: List<&2, T.DomainEvent>
  for id: String
  for success: {Core.merge(left, right) == T.Merged{output} : T.MergeResult}
  {Core.ids_contains(output, id) == Bool.or(Core.ids_contains(left, id), Core.ids_contains(right, id)) : Bool}
