import Base
import ./Types.bend as T
import ./Core.bend as C

type ReportItem is Data:
  ReportItem{taskId: String, task: String, project: String, didToday: List<&2, String>, firstTs: String}

type Activity is Data:
  Activity{firstTs: Maybe<&2, String>, notes: List<&2, String>}

# Match ECMAScript whitespace used by the preserved report presentation.
def whitespace(char: Char) -> Bool:
  match char:
    case Chr{+x}:
      Bool.or(Bool.and(U32.is_ge(x, 9), U32.is_le(x, 13)), Bool.or(U32.is_eq(x, 32), Bool.or(U32.is_eq(x, 160), Bool.or(U32.is_eq(x, 5760), Bool.or(Bool.and(U32.is_ge(x, 8192), U32.is_le(x, 8202)), Bool.or(U32.is_eq(x, 8232), Bool.or(U32.is_eq(x, 8233), Bool.or(U32.is_eq(x, 8239), Bool.or(U32.is_eq(x, 8287), Bool.or(U32.is_eq(x, 12288), U32.is_eq(x, 65279)))))))))))

def one_line_go(text: String, +acc: String, +pending: Bool, +started: Bool) -> String:
  match text:
    case SNil{}:
      String.reverse(acc)
    case SCon{+h, t}:
      +space = whitespace(h)
      one_line_go(t, Bool.pick(String, space, acc, Bool.pick(String, Bool.and(pending, started), SCon{h, SCon{' ', acc}}, SCon{h, acc})), space, Bool.or(started, Bool.not(space)))

def one_line(text: String) -> String:
  one_line_go(text, "", False{}, False{})

def fragment_clean(+text: String) -> String:
  Bool.pick(String, Bool.and(String.ends_with(text, "."), Bool.not(String.ends_with(text, ".."))), String.trim_end(String.reverse(String.drop(String.reverse(text), 1n))), text)

def fragment(text: String) -> String:
  fragment_clean(one_line(text))

def nonblank_or_misc(+text: String) -> String:
  Bool.pick(String, String.is_empty(text), "Misc", text)

def project_of(tags: List<&2, String>) -> String:
  match tags:
    case Nil{}:
      "Misc"
    case h <> t:
      nonblank_or_misc(one_line(h))

def reportable(+kind: String) -> Bool:
  Bool.or(String.eq(kind, "task.create"), Bool.or(String.eq(kind, "task.status"), String.eq(kind, "task.note")))

def in_flight(status: T.Status) -> Bool:
  match status:
    case T.SProgress{}:
      True{}
    case T.SBlocked{}:
      True{}
    case _:
      False{}

def append_note(+notes: List<&2, String>, +text: String, sendNotes: Bool) -> List<&2, String>:
  Bool.pick(List<&2, String>, Bool.and(sendNotes, Bool.not(String.is_empty(text))), List.append(&2, String, notes, [text]), notes)

def activity_add(activity: Activity, ts: String, text: String, sendNotes: Bool) -> Activity:
  match activity:
    case Activity{firstTs, notes}:
      Activity{Maybe.or(&2, String, firstTs, Some{ts}), append_note(notes, fragment(text), sendNotes)}

def activity_event(event: T.ContextEvent, +activity: Activity, id: String, sendNotes: Bool) -> Activity:
  match event:
    case T.ContextEvent{eventId, ts, day, taskId, +kind, title, status, text}:
      Bool.pick(Activity, Bool.and(String.eq(taskId, id), reportable(kind)), activity_add(activity, ts, text, Bool.and(sendNotes, String.eq(kind, "task.note"))), activity)

def task_activity(events: List<&2, T.ContextEvent>, +id: String, +sendNotes: Bool, activity: Activity) -> Activity:
  match events:
    case Nil{}:
      activity
    case h <> t:
      task_activity(t, id, sendNotes, activity_event(h, activity, id, sendNotes))

def evening_item(task: T.Task, activity: Activity) -> Maybe<&2, ReportItem>:
  match task activity:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, taskNotes} Activity{None{}, notes}:
      None{}
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, taskNotes} Activity{Some{firstTs}, notes}:
      Some{ReportItem{id, one_line(title), project_of(tags), notes, firstTs}}

def morning_item(task: T.Task, includePlan: Bool) -> Maybe<&2, ReportItem>:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      Bool.pick(Maybe<&2, ReportItem>, Bool.and(includePlan, in_flight(status)), Some{ReportItem{id, one_line(title), project_of(tags), Nil{}, updated}}, None{})

def report_item(+task: T.Task, events: List<&2, T.ContextEvent>, sendNotes: Bool, morning: Bool, includePlan: Bool) -> Maybe<&2, ReportItem>:
  match morning:
    case True{}:
      morning_item(task, includePlan)
    case False{}:
      evening_item(task, task_activity(events, C.task_id(task), sendNotes, Activity{None{}, Nil{}}))

def item_put(chosen: Maybe<&2, ReportItem>, rest: List<&2, ReportItem>, eligible: Bool) -> List<&2, ReportItem>:
  match chosen eligible:
    case Some{item} True{}:
      item <> rest
    case _ _:
      rest

def report_tasks(tasks: List<&2, T.Task>, +events: List<&2, T.ContextEvent>, +sendNotes: Bool, +morning: Bool, +includePlan: Bool) -> List<&2, ReportItem>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      item_put(report_item(h, events, sendNotes, morning, includePlan), report_tasks(t, events, sendNotes, morning, includePlan), C.eligible(h))

def item_le_tie(ai: String, bi: String, at: String, bt: String, same: Bool) -> Bool:
  match same:
    case True{}:
      String.is_le(ai, bi)
    case False{}:
      String.is_le(at, bt)

def item_le(a: ReportItem, b: ReportItem) -> Bool:
  match a b:
    case ReportItem{ai, aa, ap, an, +at} ReportItem{bi, ba, bp, bn, +bt}:
      item_le_tie(ai, bi, at, bt, String.eq(at, bt))

def report_state(state: T.State, events: List<&2, T.ContextEvent>, sendNotes: Bool, morning: Bool, includePlan: Bool) -> List<&2, ReportItem>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      Bool.pick(List<&2, ReportItem>, complete, List.sort(~ReportItem, ~item_le, report_tasks(tasks, events, sendNotes, morning, includePlan)), Nil{})

def report_merged(result: T.MergeResult, +state: T.State, sendNotes: Bool, +day: String, morning: Bool, includePlan: Bool) -> List<&2, ReportItem>:
  match result:
    case T.EventConflict{id}:
      Nil{}
    case T.Merged{events}:
      report_state(state, C.context_events(state, events, True{}, day, day), sendNotes, morning, includePlan)

def report_items(state: T.State, events: List<&2, T.DomainEvent>, sendNotes: Bool, day: String, morning: Bool, includePlan: Bool) -> List<&2, ReportItem>:
  report_merged(C.merge(events, Nil{}), state, sendNotes, day, morning, includePlan)

type ModelItem is Data:
  ModelItem{task: String, project: String, didToday: List<&2, String>}

def model_item(item: ReportItem) -> ModelItem:
  match item:
    case ReportItem{id, task, project, didToday, firstTs}:
      ModelItem{task, project, didToday}

def model_items(items: List<&2, ReportItem>) -> List<&2, ModelItem>:
  match items:
    case Nil{}:
      Nil{}
    case h <> t:
      model_item(h) <> model_items(t)

def model_report(state: T.State, events: List<&2, T.DomainEvent>, sendNotes: Bool, day: String, morning: Bool, includePlan: Bool) -> List<&2, ModelItem>:
  model_items(report_items(state, events, sendNotes, day, morning, includePlan))

type ReminderDecision is Data:
  ReminderOff{}
  ReminderDue{pending: Bool, missingSummary: Bool, missingSignOff: Bool}

def reminder_needed(hasPending: Bool, hasEveningSummary: Bool, hasSignOff: Bool) -> Bool:
  Bool.or(hasPending, Bool.or(Bool.not(hasEveningSummary), Bool.not(hasSignOff)))

def reminder_decision(enabled: Bool, alreadyFired: Bool, +nowMinutes: U32, +targetMinutes: U32, +hasPending: Bool, +hasEveningSummary: Bool, +hasSignOff: Bool) -> ReminderDecision:
  Bool.pick(ReminderDecision, Bool.and(enabled, Bool.and(Bool.not(alreadyFired), Bool.and(U32.is_lt(nowMinutes, 1440), Bool.and(U32.is_lt(targetMinutes, 1440), Bool.and(U32.is_ge(nowMinutes, targetMinutes), reminder_needed(hasPending, hasEveningSummary, hasSignOff)))))), ReminderDue{hasPending, Bool.not(hasEveningSummary), Bool.not(hasSignOff)}, ReminderOff{})
