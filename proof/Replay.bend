import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as C
import ./Order.bend as O

# Real fold compositionality, with no chronological or state-result premise.
def fold_append(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +state: T.State) -> {C.fold_sorted(List.append(&2, T.DomainEvent, left, right), state) == C.fold_sorted(right, C.fold_sorted(left, state)) : T.State}:
  match left:
    case Nil{}:
      {==}
    case head <> tail:
      fold_append(tail, right, C.apply_event(state, head))

# The premise is exact canonical merge-result equality, including every typed
# payload and canonical envelope. Equal IDs or a watermark are insufficient.
def normalform_replay(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, normal: {C.merge(left, Nil{}) == C.merge(right, Nil{}) : T.MergeResult}) -> {C.replay(left) == C.replay(right) : T.ReplayResult}:
  Equal.cong(T.MergeResult, T.ReplayResult, merged => C.replay_merged(merged), C.merge(left, Nil{}), C.merge(right, Nil{}), normal)

def model_projection(result: T.MergeResult, +sendNotes: Bool) -> List<&2, T.ContextTask>:
  match result:
    case T.EventConflict{id}:
      Nil{}
    case T.Merged{events}:
      C.context(C.fold_sorted(events, C.empty_state()), sendNotes)

def history_projection(result: T.MergeResult, +sendNotes: Bool, +start: String, +end: String) -> List<&2, T.ContextEvent>:
  match result:
    case T.EventConflict{id}:
      Nil{}
    case T.Merged{+events}:
      C.context_events(C.fold_sorted(events, C.empty_state()), events, sendNotes, start, end)

def normalform_model(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +sendNotes: Bool, normal: {C.merge(left, Nil{}) == C.merge(right, Nil{}) : T.MergeResult}) -> {model_projection(C.merge(left, Nil{}), sendNotes) == model_projection(C.merge(right, Nil{}), sendNotes) : List<&2, T.ContextTask>}:
  Equal.cong(T.MergeResult, List<&2, T.ContextTask>, merged => model_projection(merged, sendNotes), C.merge(left, Nil{}), C.merge(right, Nil{}), normal)

def normalform_history(+left: List<&2, T.DomainEvent>, +right: List<&2, T.DomainEvent>, +sendNotes: Bool, +start: String, +end: String, normal: {C.merge(left, Nil{}) == C.merge(right, Nil{}) : T.MergeResult}) -> {history_projection(C.merge(left, Nil{}), sendNotes, start, end) == history_projection(C.merge(right, Nil{}), sendNotes, start, end) : List<&2, T.ContextEvent>}:
  Equal.cong(T.MergeResult, List<&2, T.ContextEvent>, merged => history_projection(merged, sendNotes, start, end), C.merge(left, Nil{}), C.merge(right, Nil{}), normal)

def recovery_refines_full(+covered: List<&2, T.DomainEvent>, +incoming: List<&2, T.DomainEvent>, +full: List<&2, T.DomainEvent>, coverage: {C.merge(covered, incoming) == C.merge(full, Nil{}) : T.MergeResult}) -> {C.reconcile(covered, incoming) == C.replay(full) : T.ReplayResult}:
  Equal.cong(T.MergeResult, T.ReplayResult, merged => C.replay_merged(merged), C.merge(covered, incoming), C.merge(full, Nil{}), coverage)

def status(task: T.Task) -> T.Status:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      status

def completion(task: T.Task) -> Maybe<&2, String>:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      completed

def note_keeps_status(+task: T.Task, note: T.Note, instant: String) -> {status(C.note_task(task, note, instant)) == status(task) : T.Status}:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def note_keeps_completion(+task: T.Task, note: T.Note, instant: String) -> {completion(C.note_task(task, note, instant)) == completion(task) : Maybe<&2, String>}:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def later_status_wins(task: T.Task, note: T.Note, noteInstant: String, +later: String, +desired: T.Status) -> {status(C.apply_payload(C.note_task(task, note, noteInstant), T.StatusChanged{"target", desired}, "status", later)) == desired : T.Status}:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      {==}

def record_date(record: T.Recorded) -> String:
  match record:
    case T.Recorded{id, ts, day, kind, body}:
      day

def record_kind(record: T.Recorded) -> String:
  match record:
    case T.Recorded{id, ts, day, kind, body}:
      kind

def record_find(records: List<&2, T.Recorded>, +key: T.Recorded) -> Maybe<&2, T.Recorded>:
  match records:
    case Nil{}:
      None{}
    case +head <> tail:
      Bool.pick(Maybe<&2, T.Recorded>, C.record_key_equal(head, key), Some{head}, record_find(tail, key))

def record_key_reflexive(+record: T.Recorded) -> {C.record_key_equal(record, record) == True{} : Bool}:
  match record:
    case T.Recorded{id, ts, +day, +kind, body}:
      Equal.trans(Bool, Bool.and(String.eq(day, day), String.eq(kind, kind)), String.eq(kind, kind), True{}, Equal.cong(Bool, Bool, value => Bool.and(value, String.eq(kind, kind)), String.eq(day, day), True{}, O.string_equality_reflexive(day)), O.string_equality_reflexive(kind))

def record_put_step(+head: T.Recorded, +tail: List<&2, T.Recorded>, +record: T.Recorded, choice: Bool, same: {C.record_key_equal(head, record) == choice : Bool}, rest: {record_find(C.put_record(tail, record), record) == Some{record} : Maybe<&2, T.Recorded>}) -> {record_find(Bool.pick(List<&2, T.Recorded>, choice, record <> tail, head <> C.put_record(tail, record)), record) == Some{record} : Maybe<&2, T.Recorded>}:
  match choice:
    case True{}:
      Equal.cong(Bool, Maybe<&2, T.Recorded>, value => Bool.pick(Maybe<&2, T.Recorded>, value, Some{record}, record_find(tail, record)), C.record_key_equal(record, record), True{}, record_key_reflexive(record))
    case False{}:
      Equal.trans(Maybe<&2, T.Recorded>, record_find(head <> C.put_record(tail, record), record), record_find(C.put_record(tail, record), record), Some{record}, Equal.cong(Bool, Maybe<&2, T.Recorded>, value => Bool.pick(Maybe<&2, T.Recorded>, value, Some{head}, record_find(C.put_record(tail, record), record)), C.record_key_equal(head, record), False{}, same), rest)

# For every preceding record collection, the most recently folded write is
# returned exactly, including its event ID, timestamp and full content.
def latest_record(+records: List<&2, T.Recorded>, +record: T.Recorded) -> {record_find(C.put_record(records, record), record) == Some{record} : Maybe<&2, T.Recorded>}:
  match records:
    case Nil{}:
      Equal.cong(Bool, Maybe<&2, T.Recorded>, value => Bool.pick(Maybe<&2, T.Recorded>, value, Some{record}, None{}), C.record_key_equal(record, record), True{}, record_key_reflexive(record))
    case +head <> +tail:
      record_put_step(head, tail, record, C.record_key_equal(head, record), {==}, latest_record(tail, record))

def summaries(state: T.State) -> List<&2, T.Recorded>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      summaries

def reports(state: T.State) -> List<&2, T.Recorded>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      reports

def latest_summary(state: T.State, +record: T.Recorded) -> {record_find(summaries(C.apply_summary(state, record)), record) == Some{record} : Maybe<&2, T.Recorded>}:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      latest_record(summaries, record)

def latest_report(state: T.State, +record: T.Recorded) -> {record_find(reports(C.apply_report(state, record)), record) == Some{record} : Maybe<&2, T.Recorded>}:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      latest_record(reports, record)

def saved_records(state: T.State) -> List<&2, T.Recorded> & List<&2, T.Recorded>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      (summaries, reports)

def put_keeps_records(+state: T.State, task: T.Task) -> {saved_records(C.state_put(state, task)) == saved_records(state) : List<&2, T.Recorded> & List<&2, T.Recorded>}:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      {==}

def diagnostic_keeps_records(+state: T.State, issue: T.Diagnostic) -> {saved_records(C.diagnostic(state, issue)) == saved_records(state) : List<&2, T.Recorded> & List<&2, T.Recorded>}:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      {==}

def live_update_keeps_records(+state: T.State, task: T.Task, payload: T.Payload, id: String, instant: String, taskId: String, deleted: Bool) -> {saved_records(C.update_live(state, task, payload, id, instant, taskId, deleted)) == saved_records(state) : List<&2, T.Recorded> & List<&2, T.Recorded>}:
  match deleted:
    case True{}:
      diagnostic_keeps_records(state, T.AfterDelete{id, taskId})
    case False{}:
      put_keeps_records(state, C.apply_payload(task, payload, id, instant))

def found_update_keeps_records(+state: T.State, payload: T.Payload, id: String, instant: String, taskId: String, found: Maybe<&2, T.Task>) -> {saved_records(C.update_found(state, payload, id, instant, taskId, found)) == saved_records(state) : List<&2, T.Recorded> & List<&2, T.Recorded>}:
  match found:
    case None{}:
      diagnostic_keeps_records(state, T.MissingTask{id, taskId})
    case Some{+task}:
      live_update_keeps_records(state, task, payload, id, instant, taskId, C.task_deleted(task))

def task_update_keeps_records(+state: T.State, payload: T.Payload, id: String, instant: String, +taskId: String) -> {saved_records(C.update_existing(state, payload, id, instant, taskId)) == saved_records(state) : List<&2, T.Recorded> & List<&2, T.Recorded>}:
  found_update_keeps_records(state, payload, id, instant, taskId, C.state_task(state, taskId))

def event(+id: String, hour: String, payload: T.Payload) -> T.DomainEvent:
  T.Ev{id, String.append("2026-11-01T", String.append(hour, ":00:00.000Z")), "2026-11-01", payload, id}

def created() -> T.DomainEvent:
  event("create", "01", T.Created{"secret", "PRIVATE_PROVENANCE", T.STodo{}, T.PNormal{}, ["retained"], True{}})

def noted() -> T.DomainEvent:
  event("note", "02", T.Noted{"secret", "PRIVATE_OLD_NOTE"})

def done() -> T.DomainEvent:
  event("done", "05", T.StatusChanged{"secret", T.SDone{}})

def deleted() -> T.DomainEvent:
  event("delete", "07", T.Deleted{"secret"})

def old_summary() -> T.DomainEvent:
  event("summary-old", "03", T.SummarySet{"2026-11-01", "morning", "OLD_SUMMARY"})

def new_summary() -> T.DomainEvent:
  event("summary-new", "06", T.SummarySet{"2026-11-01", "morning", "EXACT_NEW_SUMMARY"})

def old_report() -> T.DomainEvent:
  event("report-old", "04", T.StandupSet{"2026-11-01", "evening", "OLD_REPORT"})

def new_report() -> T.DomainEvent:
  event("report-new", "08", T.StandupSet{"2026-11-01", "evening", "EXACT_NEW_REPORT"})

def expected_task(deleted: Bool, updated: String) -> T.Task:
  T.Task{"secret", "PRIVATE_PROVENANCE", T.SDone{}, T.PNormal{}, ["retained"], True{}, deleted, "2026-11-01T01:00:00.000Z", updated, Some{"2026-11-01T05:00:00.000Z"}, [T.Note{"note", "2026-11-01T02:00:00.000Z", "PRIVATE_OLD_NOTE"}]}

# A backdated note arriving after the later status is reconciled into its true
# chronological position. Status, completion and updated all remain later.
def late_note_recovery_witness() -> {C.reconcile([done(), created()], [noted()]) == T.Replayed{T.State{[expected_task(False{}, "2026-11-01T05:00:00.000Z")], Nil{}, Nil{}, Nil{}, True{}}} : T.ReplayResult}:
  {==}

def shuffled_history() -> List<&2, T.DomainEvent>:
  [new_report(), deleted(), new_summary(), done(), old_report(), old_summary(), noted(), created()]

def expected_state() -> T.State:
  T.State{[expected_task(True{}, "2026-11-01T07:00:00.000Z")], [T.Recorded{"summary-new", "2026-11-01T06:00:00.000Z", "2026-11-01", "morning", "EXACT_NEW_SUMMARY"}], [T.Recorded{"report-new", "2026-11-01T08:00:00.000Z", "2026-11-01", "evening", "EXACT_NEW_REPORT"}], Nil{}, True{}}

# Exact whole-state equality, not merely a Boolean checked by a wrapper. The
# tombstone retains title, private flag, tag, note and completion provenance.
def full_private_replay_witness() -> {C.replay(shuffled_history()) == T.Replayed{expected_state()} : T.ReplayResult}:
  {==}

def private_context_witness() -> {model_projection(C.merge(shuffled_history(), Nil{}), True{}) == Nil{} : List<&2, T.ContextTask>}:
  {==}

def private_history_witness() -> {history_projection(C.merge(shuffled_history(), Nil{}), True{}, "2026-11-01", "2026-11-01") == Nil{} : List<&2, T.ContextEvent>}:
  {==}
