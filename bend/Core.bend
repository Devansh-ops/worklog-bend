import Base
import ./Types.bend as T

def status_eq(a: T.Status, b: T.Status) -> Bool:
  match a b:
    case T.SBacklog{} T.SBacklog{}:
      True{}
    case T.STodo{} T.STodo{}:
      True{}
    case T.SProgress{} T.SProgress{}:
      True{}
    case T.SBlocked{} T.SBlocked{}:
      True{}
    case T.SReview{} T.SReview{}:
      True{}
    case T.SDone{} T.SDone{}:
      True{}
    case _ _:
      False{}

def priority_eq(a: T.Priority, b: T.Priority) -> Bool:
  match a b:
    case T.PLow{} T.PLow{}:
      True{}
    case T.PNormal{} T.PNormal{}:
      True{}
    case T.PHigh{} T.PHigh{}:
      True{}
    case T.PUrgent{} T.PUrgent{}:
      True{}
    case _ _:
      False{}

def bool_eq(a: Bool, b: Bool) -> Bool:
  Cmp.is_eq(Bool.cmp(a, b))

def strings_eq(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case x <> xt y <> yt:
      Bool.and(String.eq(x, y), strings_eq(xt, yt))
    case _ _:
      False{}

def optional_string_eq(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      String.eq(x, y)
    case _ _:
      False{}

def optional_status_eq(a: Maybe<&2, T.Status>, b: Maybe<&2, T.Status>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      status_eq(x, y)
    case _ _:
      False{}

def optional_priority_eq(a: Maybe<&2, T.Priority>, b: Maybe<&2, T.Priority>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      priority_eq(x, y)
    case _ _:
      False{}

def optional_strings_eq(a: Maybe<&2, List<&2, String>>, b: Maybe<&2, List<&2, String>>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      strings_eq(x, y)
    case _ _:
      False{}

def optional_bool_eq(a: Maybe<&2, Bool>, b: Maybe<&2, Bool>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      bool_eq(x, y)
    case _ _:
      False{}

def patch_eq(a: T.Patch, b: T.Patch) -> Bool:
  match a b:
    case T.Patch{at, ast, ap, ag, av} T.Patch{bt, bst, bp, bg, bv}:
      Bool.and(optional_string_eq(at, bt), Bool.and(optional_status_eq(ast, bst), Bool.and(optional_priority_eq(ap, bp), Bool.and(optional_strings_eq(ag, bg), optional_bool_eq(av, bv)))))

def payload_eq(a: T.Payload, b: T.Payload) -> Bool:
  match a b:
    case T.Created{ai, at, ast, ap, ag, av} T.Created{bi, bt, bst, bp, bg, bv}:
      Bool.and(String.eq(ai, bi), Bool.and(String.eq(at, bt), Bool.and(status_eq(ast, bst), Bool.and(priority_eq(ap, bp), Bool.and(strings_eq(ag, bg), bool_eq(av, bv))))))
    case T.StatusChanged{ai, ast} T.StatusChanged{bi, bst}:
      Bool.and(String.eq(ai, bi), status_eq(ast, bst))
    case T.Noted{ai, at} T.Noted{bi, bt}:
      Bool.and(String.eq(ai, bi), String.eq(at, bt))
    case T.Edited{ai, ap} T.Edited{bi, bp}:
      Bool.and(String.eq(ai, bi), patch_eq(ap, bp))
    case T.Deleted{ai} T.Deleted{bi}:
      String.eq(ai, bi)
    case T.SummarySet{ad, ak, ab} T.SummarySet{bd, bk, bb}:
      Bool.and(String.eq(ad, bd), Bool.and(String.eq(ak, bk), String.eq(ab, bb)))
    case T.StandupSet{ad, ak, ab} T.StandupSet{bd, bk, bb}:
      Bool.and(String.eq(ad, bd), Bool.and(String.eq(ak, bk), String.eq(ab, bb)))
    case T.Opaque{ak} T.Opaque{bk}:
      String.eq(ak, bk)
    case _ _:
      False{}

def event_id(e: T.DomainEvent) -> String:
  match e:
    case T.Ev{id, ts, day, payload, canonical}:
      id

def event_eq(a: T.DomainEvent, b: T.DomainEvent) -> Bool:
  match a b:
    case T.Ev{ai, at, ad, ap, ac} T.Ev{bi, bt, bd, bp, bc}:
      Bool.and(String.eq(ai, bi), Bool.and(String.eq(at, bt), Bool.and(String.eq(ad, bd), Bool.and(payload_eq(ap, bp), String.eq(ac, bc)))))

def event_le_tie(ai: String, bi: String, at: String, bt: String, same: Bool) -> Bool:
  match same:
    case True{}:
      String.is_le(ai, bi)
    case False{}:
      String.is_le(at, bt)

def event_le(a: T.DomainEvent, b: T.DomainEvent) -> Bool:
  match a b:
    case T.Ev{ai, +at, ad, ap, ac} T.Ev{bi, +bt, bd, bp, bc}:
      event_le_tie(ai, bi, at, bt, String.eq(at, bt))

def ids_contains(xs: List<&2, T.DomainEvent>, +id: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(String.eq(event_id(h), id), ids_contains(t, id))

def unique_put(e: T.DomainEvent, xs: List<&2, T.DomainEvent>, exists: Bool) -> List<&2, T.DomainEvent>:
  match exists:
    case True{}:
      xs
    case False{}:
      e <> xs

def event_id_le(a: T.DomainEvent, b: T.DomainEvent) -> Bool:
  String.is_le(event_id(a), event_id(b))

def scan_ids(fuel: List<&2, T.DomainEvent>, +acc: List<&2, T.DomainEvent>, previous: Maybe<&2, T.DomainEvent>) -> T.MergeResult:
  match fuel previous:
    case Nil{} _:
      T.Merged{List.sort(~T.DomainEvent, ~event_le, acc)}
    case +h <> t None{}:
      scan_ids(t, h <> acc, Some{h})
    case +h <> t Some{+p}:
      +same = String.eq(event_id(h), event_id(p))
      Bool.pick(T.MergeResult, Bool.and(same, Bool.not(event_eq(h, p))), T.EventConflict{event_id(h)}, scan_ids(t, unique_put(h, acc, same), Some{h}))

def merge(left: List<&2, T.DomainEvent>, right: List<&2, T.DomainEvent>) -> T.MergeResult:
  scan_ids(List.sort(~T.DomainEvent, ~event_id_le, List.append(&2, T.DomainEvent, left, right)), Nil{}, None{})

def completion(status: T.Status, instant: String) -> Maybe<&2, String>:
  match status:
    case T.SDone{}:
      Some{instant}
    case _:
      None{}

def eligible(task: T.Task) -> Bool:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      Bool.and(Bool.not(private), Bool.not(deleted))

def chosen_notes(notes: List<&2, T.Note>, sendNotes: Bool) -> List<&2, T.Note>:
  match sendNotes:
    case False{}:
      Nil{}
    case True{}:
      notes

def project(task: T.Task, sendNotes: Bool) -> T.ContextTask:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      T.ContextTask{id, title, status, priority, tags, chosen_notes(notes, sendNotes)}

def context_notes(task: T.ContextTask) -> List<&2, T.Note>:
  match task:
    case T.ContextTask{id, title, status, priority, tags, notes}:
      notes

def task_id(task: T.Task) -> String:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      id

def task_deleted(task: T.Task) -> Bool:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      deleted

def task_find(tasks: List<&2, T.Task>, +id: String) -> Maybe<&2, T.Task>:
  match tasks:
    case Nil{}:
      None{}
    case +h <> t:
      Bool.pick(Maybe<&2, T.Task>, String.eq(task_id(h), id), Some{h}, task_find(t, id))

def put_task(tasks: List<&2, T.Task>, +task: T.Task) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      [task]
    case +h <> +t:
      Bool.pick(List<&2, T.Task>, String.eq(task_id(h), task_id(task)), task <> t, h <> put_task(t, task))

def record_key_equal(a: T.Recorded, b: T.Recorded) -> Bool:
  match a b:
    case T.Recorded{ai, at, ad, ak, ab} T.Recorded{bi, bt, bd, bk, bb}:
      Bool.and(String.eq(ad, bd), String.eq(ak, bk))

def put_record(records: List<&2, T.Recorded>, +record: T.Recorded) -> List<&2, T.Recorded>:
  match records:
    case Nil{}:
      [record]
    case +h <> +t:
      Bool.pick(List<&2, T.Recorded>, record_key_equal(h, record), record <> t, h <> put_record(t, record))

def patch_completion(change: Maybe<&2, T.Status>, instant: String, previous: Maybe<&2, String>) -> Maybe<&2, String>:
  match change:
    case None{}:
      previous
    case Some{s}:
      completion(s, instant)

def edit_task(task: T.Task, patch: T.Patch, +instant: String) -> T.Task:
  match task patch:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes} T.Patch{pt, +ps, pp, pg, pv}:
      T.Task{id, Maybe.default(&2, String, pt, title), Maybe.default(&2, T.Status, ps, status), Maybe.default(&2, T.Priority, pp, priority), Maybe.default(&2, List<&2, String>, pg, tags), Maybe.default(&2, Bool, pv, private), deleted, created, instant, patch_completion(ps, instant, completed), notes}

def note_task(task: T.Task, note: T.Note, instant: String) -> T.Task:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      T.Task{id, title, status, priority, tags, private, deleted, created, instant, completed, List.append(&2, T.Note, notes, [note])}

def delete_task(task: T.Task, instant: String) -> T.Task:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      T.Task{id, title, status, priority, tags, private, True{}, created, instant, completed, notes}

def apply_payload(task: T.Task, payload: T.Payload, +id: String, +instant: String) -> T.Task:
  match payload:
    case T.StatusChanged{taskId, status}:
      edit_task(task, T.Patch{None{}, Some{status}, None{}, None{}, None{}}, instant)
    case T.Noted{taskId, text}:
      note_task(task, T.Note{id, instant, text}, instant)
    case T.Edited{taskId, patch}:
      edit_task(task, patch, instant)
    case T.Deleted{taskId}:
      delete_task(task, instant)
    case _:
      task

def empty_state() -> T.State:
  T.State{Nil{}, Nil{}, Nil{}, Nil{}, True{}}

def diagnostic(state: T.State, issue: T.Diagnostic) -> T.State:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      T.State{tasks, summaries, reports, List.append(&2, T.Diagnostic, issues, [issue]), False{}}

def state_put(state: T.State, task: T.Task) -> T.State:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      T.State{put_task(tasks, task), summaries, reports, issues, complete}

def state_task(state: T.State, id: String) -> Maybe<&2, T.Task>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      task_find(tasks, id)

def create_found(state: T.State, task: T.Task, eventId: String, +taskId: String, previous: Maybe<&2, T.Task>) -> T.State:
  match previous:
    case None{}:
      state_put(state, task)
    case Some{old}:
      diagnostic(state, T.DuplicateCreate{eventId, taskId})

def update_live(state: T.State, task: T.Task, payload: T.Payload, id: String, instant: String, taskId: String, deleted: Bool) -> T.State:
  match deleted:
    case False{}:
      state_put(state, apply_payload(task, payload, id, instant))
    case True{}:
      diagnostic(state, T.AfterDelete{id, taskId})

def update_found(state: T.State, payload: T.Payload, id: String, instant: String, taskId: String, found: Maybe<&2, T.Task>) -> T.State:
  match found:
    case None{}:
      diagnostic(state, T.MissingTask{id, taskId})
    case Some{+task}:
      update_live(state, task, payload, id, instant, taskId, task_deleted(task))

def update_existing(+state: T.State, payload: T.Payload, id: String, instant: String, +taskId: String) -> T.State:
  update_found(state, payload, id, instant, taskId, state_task(state, taskId))

def apply_summary(state: T.State, record: T.Recorded) -> T.State:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      T.State{tasks, put_record(summaries, record), reports, issues, complete}

def apply_report(state: T.State, record: T.Recorded) -> T.State:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      T.State{tasks, summaries, put_record(reports, record), issues, complete}

def apply_event(+state: T.State, event: T.DomainEvent) -> T.State:
  match event:
    case T.Ev{id, +ts, day, payload, canonical}:
      match payload:
        case T.Created{+taskId, title, +status, priority, tags, private}:
          create_found(state, T.Task{taskId, title, status, priority, tags, private, False{}, ts, ts, completion(status, ts), Nil{}}, id, taskId, state_task(state, taskId))
        case T.StatusChanged{+taskId, status}:
          update_existing(state, T.StatusChanged{taskId, status}, id, ts, taskId)
        case T.Noted{+taskId, text}:
          update_existing(state, T.Noted{taskId, text}, id, ts, taskId)
        case T.Edited{+taskId, patch}:
          update_existing(state, T.Edited{taskId, patch}, id, ts, taskId)
        case T.Deleted{+taskId}:
          update_existing(state, T.Deleted{taskId}, id, ts, taskId)
        case T.SummarySet{date, kind, body}:
          apply_summary(state, T.Recorded{id, ts, date, kind, body})
        case T.StandupSet{date, kind, text}:
          apply_report(state, T.Recorded{id, ts, date, kind, text})
        case T.Opaque{kind}:
          diagnostic(state, T.Unsupported{id, kind})

def fold_sorted(events: List<&2, T.DomainEvent>, state: T.State) -> T.State:
  match events:
    case Nil{}:
      state
    case h <> t:
      fold_sorted(t, apply_event(state, h))

def replay_merged(result: T.MergeResult) -> T.ReplayResult:
  match result:
    case T.EventConflict{id}:
      T.ReplayConflict{id}
    case T.Merged{events}:
      T.Replayed{fold_sorted(events, empty_state())}

def replay(events: List<&2, T.DomainEvent>) -> T.ReplayResult:
  replay_merged(merge(events, Nil{}))

# A watermark is never accepted as a coverage proof. Reconcile authoritative
# covered events and newly fetched events before replay, including backdated ones.
def reconcile(covered: List<&2, T.DomainEvent>, incoming: List<&2, T.DomainEvent>) -> T.ReplayResult:
  replay_merged(merge(covered, incoming))

def complete(state: T.State) -> Bool:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      complete

def context_put(task: T.Task, rest: List<&2, T.ContextTask>, sendNotes: Bool, keep: Bool) -> List<&2, T.ContextTask>:
  match keep:
    case False{}:
      rest
    case True{}:
      project(task, sendNotes) <> rest

def context_tasks(tasks: List<&2, T.Task>, +sendNotes: Bool) -> List<&2, T.ContextTask>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      context_put(h, context_tasks(t, sendNotes), sendNotes, eligible(h))

def context_state(safe: Bool, state: T.State, sendNotes: Bool) -> List<&2, T.ContextTask>:
  match safe:
    case False{}:
      Nil{}
    case True{}:
      match state:
        case T.State{tasks, summaries, reports, issues, complete}:
          context_tasks(tasks, sendNotes)

def context(+state: T.State, sendNotes: Bool) -> List<&2, T.ContextTask>:
  context_state(complete(state), state, sendNotes)

def valid_text(+text: String, bound: Nat) -> Bool:
  Bool.and(Bool.not(String.is_empty(String.trim(text))), Nat.is_le(String.length(text), bound))

def valid_tags(tags: List<&2, String>) -> Bool:
  match tags:
    case Nil{}:
      True{}
    case +h <> t:
      Bool.and(valid_text(h, 64n), valid_tags(t))

def valid_optional_title(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{text}:
      valid_text(text, 200n)

def valid_optional_tags(value: Maybe<&2, List<&2, String>>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{+tags}:
      Bool.and(Nat.is_le(List.length(&2, String, tags), 50n), valid_tags(tags))

def valid_patch(patch: T.Patch) -> Bool:
  match patch:
    case T.Patch{title, status, priority, tags, private}:
      Bool.and(valid_optional_title(title), valid_optional_tags(tags))

def live(found: Maybe<&2, T.Task>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{task}:
      Bool.not(task_deleted(task))

def absent(found: Maybe<&2, T.Task>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{task}:
      False{}

def valid_kind(+kind: String) -> Bool:
  Bool.or(String.eq(kind, "morning"), String.eq(kind, "evening"))

def command_valid(state: T.State, payload: T.Payload) -> Bool:
  match payload:
    case T.Created{taskId, title, status, priority, +tags, private}:
      Bool.and(absent(state_task(state, taskId)), Bool.and(valid_text(title, 200n), Bool.and(Nat.is_le(List.length(&2, String, tags), 50n), valid_tags(tags))))
    case T.StatusChanged{taskId, status}:
      live(state_task(state, taskId))
    case T.Noted{taskId, text}:
      Bool.and(live(state_task(state, taskId)), valid_text(text, 20000n))
    case T.Edited{taskId, patch}:
      Bool.and(live(state_task(state, taskId)), valid_patch(patch))
    case T.Deleted{taskId}:
      live(state_task(state, taskId))
    case T.SummarySet{date, kind, body}:
      Bool.and(Bool.not(String.is_empty(date)), Bool.and(valid_kind(kind), Bool.not(String.is_empty(body))))
    case T.StandupSet{date, kind, text}:
      Bool.and(Bool.not(String.is_empty(date)), Bool.and(valid_kind(kind), valid_text(text, 20000n)))
    case T.Opaque{kind}:
      False{}

def stage_valid(event: T.DomainEvent, valid: Bool) -> T.StageResult:
  match valid:
    case False{}:
      T.StageRejected{"invalid command or unavailable task"}
    case True{}:
      T.StageAccepted{event}

def stage_state(result: T.ReplayResult, event: T.DomainEvent) -> T.StageResult:
  match result:
    case T.ReplayConflict{id}:
      T.StageRejected{"event ID content conflict"}
    case T.Replayed{+state}:
      match event:
        case T.Ev{+id, +ts, +day, +payload, canonical}:
          stage_valid(T.Ev{id, ts, day, payload, canonical}, Bool.and(complete(state), Bool.and(command_valid(state, payload), Bool.and(Bool.not(String.is_empty(id)), Bool.and(Bool.not(String.is_empty(ts)), Bool.not(String.is_empty(day)))))))

def stage_unique(event: T.DomainEvent, existing: List<&2, T.DomainEvent>, duplicate: Bool) -> T.StageResult:
  match duplicate:
    case True{}:
      T.StageRejected{"event ID already exists"}
    case False{}:
      stage_state(replay(existing), event)

def stage(+events: List<&2, T.DomainEvent>, +event: T.DomainEvent) -> T.StageResult:
  stage_unique(event, events, ids_contains(events, event_id(event)))

def schema_allowed(+version: U32) -> Bool:
  Bool.or(U32.is_eq(version, 1), U32.is_eq(version, 2))

def exact_contains(events: List<&2, T.DomainEvent>, +event: T.DomainEvent) -> Bool:
  match events:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(event_eq(h, event), exact_contains(t, event))

def acknowledge_put(event: T.DomainEvent, rest: List<&2, T.DomainEvent>, acknowledged: Bool) -> List<&2, T.DomainEvent>:
  match acknowledged:
    case True{}:
      rest
    case False{}:
      event <> rest

def acknowledge_success(pending: List<&2, T.DomainEvent>, +committed: List<&2, T.DomainEvent>) -> List<&2, T.DomainEvent>:
  match pending:
    case Nil{}:
      Nil{}
    case +h <> t:
      acknowledge_put(h, acknowledge_success(t, committed), exact_contains(committed, h))

def acknowledge(pending: List<&2, T.DomainEvent>, committed: List<&2, T.DomainEvent>, success: Bool) -> List<&2, T.DomainEvent>:
  match success:
    case False{}:
      pending
    case True{}:
      acknowledge_success(pending, committed)

def eligible_found(found: Maybe<&2, T.Task>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{task}:
      eligible(task)

def eligible_target(+state: T.State, id: String) -> Bool:
  Bool.and(complete(state), eligible_found(state_task(state, id)))

def history_chosen(event: T.ContextEvent, allowed: Bool) -> Maybe<&2, T.ContextEvent>:
  match allowed:
    case False{}:
      None{}
    case True{}:
      Some{event}

def history_patch(patch: T.Patch, id: String, ts: String, day: String, taskId: String) -> T.ContextEvent:
  match patch:
    case T.Patch{title, status, priority, tags, private}:
      T.ContextEvent{id, ts, day, taskId, "task.edit", Maybe.default(&2, String, title, ""), status, ""}

def history_payload(payload: T.Payload, state: T.State, id: String, ts: String, day: String, sendNotes: Bool) -> Maybe<&2, T.ContextEvent>:
  match payload:
    case T.Created{+taskId, title, status, priority, tags, private}:
      history_chosen(T.ContextEvent{id, ts, day, taskId, "task.create", title, Some{status}, ""}, eligible_target(state, taskId))
    case T.StatusChanged{+taskId, status}:
      history_chosen(T.ContextEvent{id, ts, day, taskId, "task.status", "", Some{status}, ""}, eligible_target(state, taskId))
    case T.Noted{+taskId, text}:
      history_chosen(T.ContextEvent{id, ts, day, taskId, "task.note", "", None{}, text}, Bool.and(sendNotes, eligible_target(state, taskId)))
    case T.Edited{+taskId, patch}:
      history_chosen(history_patch(patch, id, ts, day, taskId), eligible_target(state, taskId))
    case _:
      None{}

def in_window(+day: String, startDay: String, endDay: String) -> Bool:
  Bool.and(String.is_ge(day, startDay), String.is_le(day, endDay))

def history_window(event: Maybe<&2, T.ContextEvent>, allowed: Bool) -> Maybe<&2, T.ContextEvent>:
  match allowed:
    case False{}:
      None{}
    case True{}:
      event

def history_event(event: T.DomainEvent, state: T.State, sendNotes: Bool, startDay: String, endDay: String) -> Maybe<&2, T.ContextEvent>:
  match event:
    case T.Ev{id, ts, +day, payload, canonical}:
      history_window(history_payload(payload, state, id, ts, day, sendNotes), in_window(day, startDay, endDay))

def history_put(chosen: Maybe<&2, T.ContextEvent>, rest: List<&2, T.ContextEvent>) -> List<&2, T.ContextEvent>:
  match chosen:
    case None{}:
      rest
    case Some{event}:
      event <> rest

def context_events_go(events: List<&2, T.DomainEvent>, +state: T.State, +sendNotes: Bool, +startDay: String, +endDay: String) -> List<&2, T.ContextEvent>:
  match events:
    case Nil{}:
      Nil{}
    case h <> t:
      history_put(history_event(h, state, sendNotes, startDay, endDay), context_events_go(t, state, sendNotes, startDay, endDay))

def context_events(state: T.State, events: List<&2, T.DomainEvent>, sendNotes: Bool, startDay: String, endDay: String) -> List<&2, T.ContextEvent>:
  context_events_go(events, state, sendNotes, startDay, endDay)

def proposal_target_valid(state: T.State, payload: T.Payload) -> Bool:
  match payload:
    case T.Created{taskId, title, status, priority, tags, private}:
      True{}
    case T.StatusChanged{taskId, status}:
      eligible_target(state, taskId)
    case T.Noted{taskId, text}:
      eligible_target(state, taskId)
    case T.Edited{taskId, patch}:
      eligible_target(state, taskId)
    case _:
      False{}

def proposal_state(result: T.ReplayResult, events: List<&2, T.DomainEvent>, event: T.DomainEvent) -> T.StageResult:
  match result:
    case T.ReplayConflict{id}:
      T.StageRejected{"event ID content conflict"}
    case T.Replayed{state}:
      match event:
        case T.Ev{id, ts, day, +payload, canonical}:
          Bool.pick(T.StageResult, proposal_target_valid(state, payload), stage(events, T.Ev{id, ts, day, payload, canonical}), T.StageRejected{"proposal target is not eligible"})

def proposal_stage(+events: List<&2, T.DomainEvent>, event: T.DomainEvent) -> T.StageResult:
  proposal_state(replay(events), events, event)

