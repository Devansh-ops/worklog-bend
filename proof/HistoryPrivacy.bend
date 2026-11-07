import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as C

def allowed(state: T.State, event: T.ContextEvent) -> Bool:
  match event:
    case T.ContextEvent{id, ts, day, taskId, kind, title, status, text}:
      C.eligible_target(state, taskId)

def no_note(event: T.ContextEvent) -> Bool:
  match event:
    case T.ContextEvent{id, ts, day, taskId, kind, title, status, text}:
      Bool.and(String.eq(text, ""), Bool.not(String.eq(kind, "task.note")))

def safe_event(+state: T.State, +event: T.ContextEvent, sendNotes: Bool) -> Bool:
  Bool.and(allowed(state, event), Bool.or(sendNotes, no_note(event)))

def safe_maybe(+state: T.State, event: Maybe<&2, T.ContextEvent>, sendNotes: Bool) -> Bool:
  match event:
    case None{}:
      True{}
    case Some{event}:
      safe_event(state, event, sendNotes)

def safe_list(+state: T.State, events: List<&2, T.ContextEvent>, +sendNotes: Bool) -> Bool:
  match events:
    case Nil{}:
      True{}
    case head <> tail:
      Bool.and(safe_event(state, head, sendNotes), safe_list(state, tail, sendNotes))

def or_true(value: Bool) -> {Bool.or(value, True{}) == True{} : Bool}:
  match value:
    case False{}:
      {==}
    case True{}:
      {==}

def and_intro(+a: Bool, +b: Bool, pa: {a == True{} : Bool}, pb: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  Equal.trans(Bool, Bool.and(a, b), b, True{}, Equal.cong(Bool, Bool, x => Bool.and(x, b), a, True{}, pa), pb)

def chosen(+state: T.State, +event: T.ContextEvent, +sendNotes: Bool, flag: Bool,
  permitted: {allowed(state, event) == flag : Bool}, notes: {Bool.or(sendNotes, no_note(event)) == True{} : Bool}) ->
  {safe_maybe(state, C.history_chosen(event, flag), sendNotes) == True{} : Bool}:
  match flag:
    case False{}:
      {==}
    case True{}:
      and_intro(allowed(state, event), Bool.or(sendNotes, no_note(event)), permitted, notes)

def payload(payload: T.Payload, +state: T.State, id: String, ts: String, day: String, +sendNotes: Bool) ->
  {safe_maybe(state, C.history_payload(payload, state, id, ts, day, sendNotes), sendNotes) == True{} : Bool}:
  match payload:
    case T.Created{+taskId, title, status, priority, tags, private}:
      chosen(state, T.ContextEvent{id, ts, day, taskId, "task.create", title, Some{status}, ""}, sendNotes, C.eligible_target(state, taskId), {==}, or_true(sendNotes))
    case T.StatusChanged{+taskId, status}:
      chosen(state, T.ContextEvent{id, ts, day, taskId, "task.status", "", Some{status}, ""}, sendNotes, C.eligible_target(state, taskId), {==}, or_true(sendNotes))
    case T.Noted{+taskId, text}:
      match sendNotes:
        case False{}:
          {==}
        case True{}:
          chosen(state, T.ContextEvent{id, ts, day, taskId, "task.note", "", None{}, text}, True{}, C.eligible_target(state, taskId), {==}, {==})
    case T.Edited{+taskId, patch}:
      match patch:
        case T.Patch{title, status, priority, tags, private}:
          chosen(state, T.ContextEvent{id, ts, day, taskId, "task.edit", Maybe.default(&2, String, title, ""), status, ""}, sendNotes, C.eligible_target(state, taskId), {==}, or_true(sendNotes))
    case T.Deleted{taskId}:
      {==}
    case T.SummarySet{date, kind, body}:
      {==}
    case T.StandupSet{date, kind, text}:
      {==}
    case T.Opaque{kind}:
      {==}

def window(+state: T.State, event: Maybe<&2, T.ContextEvent>, +sendNotes: Bool, flag: Bool,
  safe: {safe_maybe(state, event, sendNotes) == True{} : Bool}) ->
  {safe_maybe(state, C.history_window(event, flag), sendNotes) == True{} : Bool}:
  match flag:
    case False{}:
      {==}
    case True{}:
      safe

def event(+event: T.DomainEvent, +state: T.State, +sendNotes: Bool, start: String, end: String) ->
  {safe_maybe(state, C.history_event(event, state, sendNotes, start, end), sendNotes) == True{} : Bool}:
  match event:
    case T.Ev{id, ts, +day, body, canonical}:
      window(state, C.history_payload(body, state, id, ts, day, sendNotes), sendNotes, C.in_window(day, start, end), payload(body, state, id, ts, day, sendNotes))

def put(+state: T.State, chosen: Maybe<&2, T.ContextEvent>, rest: List<&2, T.ContextEvent>, +sendNotes: Bool,
  head_safe: {safe_maybe(state, chosen, sendNotes) == True{} : Bool}, tail_safe: {safe_list(state, rest, sendNotes) == True{} : Bool}) ->
  {safe_list(state, C.history_put(chosen, rest), sendNotes) == True{} : Bool}:
  match chosen:
    case None{}:
      tail_safe
    case Some{head}:
      and_intro(safe_event(state, head, sendNotes), safe_list(state, rest, sendNotes), head_safe, tail_safe)

def history(events: List<&2, T.DomainEvent>, +state: T.State, +sendNotes: Bool, +start: String, +end: String) ->
  {safe_list(state, C.context_events(state, events, sendNotes, start, end), sendNotes) == True{} : Bool}:
  match events:
    case Nil{}:
      {==}
    case +head <> +tail:
      put(state, C.history_event(head, state, sendNotes, start, end), C.context_events_go(tail, state, sendNotes, start, end), sendNotes,
        event(head, state, sendNotes, start, end), history(tail, state, sendNotes, start, end))
