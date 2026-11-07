import Base
import ./Types.bend as T
import ./Core.bend as C

type StatusCount is Data:
  StatusCount{status: T.Status, count: Nat}

type TagCount is Data:
  TagCount{tag: String, count: Nat}

type DayCount is Data:
  DayCount{day: String, count: Nat}

# The adapter supplies Unicode-default lowercase of search_text(task), without
# choosing fields or independently evaluating the search predicate.
type SearchKey is Data:
  SearchKey{taskId: String, foldedText: String}

def tasks(state: T.State) -> List<&2, T.Task>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      tasks

def live_tasks(tasks: List<&2, T.Task>) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Task, h, live_tasks(t), Bool.not(C.task_deleted(h)))

def live_state(state: T.State) -> List<&2, T.Task>:
  live_tasks(tasks(state))

def priority_rank(priority: T.Priority) -> U32:
  match priority:
    case T.PUrgent{}:
      0
    case T.PHigh{}:
      1
    case T.PNormal{}:
      2
    case T.PLow{}:
      3

def recency_tie(ai: String, bi: String, at: String, bt: String, same: Bool) -> Bool:
  match same:
    case True{}:
      String.is_le(ai, bi)
    case False{}:
      String.is_ge(at, bt)

def recency_le(a: T.Task, b: T.Task) -> Bool:
  match a b:
    case T.Task{ai, aa, ast, ap, ag, av, ax, ac, +at, ad, an} T.Task{bi, ba, bst, bp, bg, bv, bx, bc, +bt, bd, bn}:
      recency_tie(ai, bi, at, bt, String.eq(at, bt))

def importance_tie(a: T.Task, b: T.Task, ar: U32, br: U32, same: Bool) -> Bool:
  match same:
    case True{}:
      recency_le(a, b)
    case False{}:
      U32.is_le(ar, br)

def importance_le(a: T.Task, b: T.Task) -> Bool:
  match a b:
    case T.Task{ai, aa, ast, +ap, ag, av, ax, ac, at, ad, an} T.Task{bi, ba, bst, +bp, bg, bv, bx, bc, bt, bd, bn}:
      +ar = priority_rank(ap)
      +br = priority_rank(bp)
      importance_tie(T.Task{ai, aa, ast, ap, ag, av, ax, ac, at, ad, an}, T.Task{bi, ba, bst, bp, bg, bv, bx, bc, bt, bd, bn}, ar, br, U32.is_eq(ar, br))

def sort_board(tasks: List<&2, T.Task>) -> List<&2, T.Task>:
  List.sort(~T.Task, ~importance_le, live_tasks(tasks))

def sort_wiki(tasks: List<&2, T.Task>) -> List<&2, T.Task>:
  List.sort(~T.Task, ~recency_le, live_tasks(tasks))

def board_tasks(state: T.State) -> List<&2, T.Task>:
  sort_board(tasks(state))

def wiki_tasks(state: T.State) -> List<&2, T.Task>:
  sort_wiki(tasks(state))

def task_status(task: T.Task) -> T.Status:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      status

def for_status(tasks: List<&2, T.Task>, +status: T.Status) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Task, h, for_status(t, status), C.status_eq(task_status(h), status))

def status_tasks(state: T.State, status: T.Status) -> List<&2, T.Task>:
  for_status(board_tasks(state), status)

def wiki_status_tasks(state: T.State, status: T.Status) -> List<&2, T.Task>:
  for_status(wiki_tasks(state), status)

def count_status(tasks: List<&2, T.Task>, +status: T.Status) -> Nat:
  List.length(&2, T.Task, for_status(live_tasks(tasks), status))

def status_counts_tasks(+tasks: List<&2, T.Task>) -> List<&2, StatusCount>:
  [StatusCount{T.SBacklog{}, count_status(tasks, T.SBacklog{})}, StatusCount{T.STodo{}, count_status(tasks, T.STodo{})}, StatusCount{T.SProgress{}, count_status(tasks, T.SProgress{})}, StatusCount{T.SBlocked{}, count_status(tasks, T.SBlocked{})}, StatusCount{T.SReview{}, count_status(tasks, T.SReview{})}, StatusCount{T.SDone{}, count_status(tasks, T.SDone{})}]

def status_counts(state: T.State) -> List<&2, StatusCount>:
  status_counts_tasks(tasks(state))

def note_texts(notes: List<&2, T.Note>) -> List<&2, String>:
  match notes:
    case Nil{}:
      Nil{}
    case T.Note{id, ts, text} <> t:
      text <> note_texts(t)

def search_text(task: T.Task) -> String:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      String.join(id <> title <> List.append(&2, String, tags, note_texts(notes)), " ")

def search_key_matches(keys: List<&2, SearchKey>, +id: String, +query: String) -> Bool:
  match keys:
    case Nil{}:
      False{}
    case SearchKey{taskId, foldedText} <> t:
      Bool.or(Bool.and(String.eq(taskId, id), String.contains(foldedText, query)), search_key_matches(t, id, query))

def search_selected(tasks: List<&2, T.Task>, +keys: List<&2, SearchKey>, +query: String) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Task, h, search_selected(t, keys, query), Bool.or(String.is_empty(query), search_key_matches(keys, C.task_id(h), query)))

def search_tasks(state: T.State, keys: List<&2, SearchKey>, query: String) -> List<&2, T.Task>:
  search_selected(board_tasks(state), keys, query)

def wiki_search_tasks(state: T.State, keys: List<&2, SearchKey>, query: String) -> List<&2, T.Task>:
  search_selected(wiki_tasks(state), keys, query)

def wiki_task(state: T.State, id: String) -> Maybe<&2, T.Task>:
  C.state_task(state, id)

def string_in(strings: List<&2, String>, +s: String) -> Bool:
  match strings:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(String.eq(h, s), string_in(t, s))

def task_tags(task: T.Task) -> List<&2, String>:
  match task:
    case T.Task{id, title, status, priority, tags, private, deleted, created, updated, completed, notes}:
      tags

def tagged_tasks(tasks: List<&2, T.Task>, +tag: String) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Task, h, tagged_tasks(t, tag), string_in(task_tags(h), tag))

def tag_tasks(state: T.State, tag: String) -> List<&2, T.Task>:
  tagged_tasks(wiki_tasks(state), tag)

def share_tags(left: List<&2, String>, +right: List<&2, String>) -> Bool:
  match left:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(string_in(right, h), share_tags(t, right))

def related_to(tasks: List<&2, T.Task>, +id: String, +tags: List<&2, String>) -> List<&2, T.Task>:
  match tasks:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Task, h, related_to(t, id, tags), Bool.and(Bool.not(String.eq(C.task_id(h), id)), share_tags(task_tags(h), tags)))

def related_found(found: Maybe<&2, T.Task>, tasks: List<&2, T.Task>, id: String) -> List<&2, T.Task>:
  match found:
    case None{}:
      Nil{}
    case Some{task}:
      related_to(tasks, id, task_tags(task))

def related_tasks(+state: T.State, +id: String) -> List<&2, T.Task>:
  related_found(wiki_task(state, id), wiki_tasks(state), id)

def tag_put(counts: List<&2, TagCount>, +tag: String) -> List<&2, TagCount>:
  match counts:
    case Nil{}:
      [TagCount{tag, 1n}]
    case TagCount{+key, +count} <> +t:
      Bool.pick(List<&2, TagCount>, String.eq(key, tag), TagCount{key, 1n+count} <> t, TagCount{key, count} <> tag_put(t, tag))

def tags_add(tags: List<&2, String>, +counts: List<&2, TagCount>, +seen: List<&2, String>) -> List<&2, TagCount>:
  match tags:
    case Nil{}:
      counts
    case +h <> t:
      tags_add(t, Bool.pick(List<&2, TagCount>, string_in(seen, h), counts, tag_put(counts, h)), h <> seen)

def tags_count(tasks: List<&2, T.Task>, counts: List<&2, TagCount>) -> List<&2, TagCount>:
  match tasks:
    case Nil{}:
      counts
    case h <> t:
      tags_count(t, tags_add(task_tags(h), counts, Nil{}))

def tag_count_tie(at: String, bt: String, an: Nat, bn: Nat, same: Bool) -> Bool:
  match same:
    case True{}:
      String.is_le(at, bt)
    case False{}:
      Nat.is_ge(an, bn)

def tag_count_le(a: TagCount, b: TagCount) -> Bool:
  match a b:
    case TagCount{at, +an} TagCount{bt, +bn}:
      tag_count_tie(at, bt, an, bn, Nat.is_eq(an, bn))

def tag_counts(tasks: List<&2, T.Task>) -> List<&2, TagCount>:
  List.sort(~TagCount, ~tag_count_le, tags_count(live_tasks(tasks), Nil{}))

def tag_index(state: T.State) -> List<&2, TagCount>:
  tag_counts(tasks(state))

def payload_task_id(payload: T.Payload) -> Maybe<&2, String>:
  match payload:
    case T.Created{id, title, status, priority, tags, private}:
      Some{id}
    case T.StatusChanged{id, status}:
      Some{id}
    case T.Noted{id, text}:
      Some{id}
    case T.Edited{id, patch}:
      Some{id}
    case T.Deleted{id}:
      Some{id}
    case _:
      None{}

def event_task_id(event: T.DomainEvent) -> Maybe<&2, String>:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      payload_task_id(payload)

def optional_id_matches(value: Maybe<&2, String>, id: String) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{taskId}:
      String.eq(taskId, id)

def history_filter(events: List<&2, T.DomainEvent>, +id: String) -> List<&2, T.DomainEvent>:
  match events:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.DomainEvent, h, history_filter(t, id), optional_id_matches(event_task_id(h), id))

def history_result(result: T.MergeResult, id: String) -> List<&2, T.DomainEvent>:
  match result:
    case T.EventConflict{conflictId}:
      Nil{}
    case T.Merged{events}:
      history_filter(events, id)

def task_history(events: List<&2, T.DomainEvent>, id: String) -> List<&2, T.DomainEvent>:
  history_result(C.merge(events, Nil{}), id)

def event_day(event: T.DomainEvent) -> String:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      day

def day_filter(events: List<&2, T.DomainEvent>, +day: String) -> List<&2, T.DomainEvent>:
  match events:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.DomainEvent, h, day_filter(t, day), String.eq(event_day(h), day))

def day_result(result: T.MergeResult, day: String) -> List<&2, T.DomainEvent>:
  match result:
    case T.EventConflict{id}:
      Nil{}
    case T.Merged{events}:
      day_filter(events, day)

def day_events(events: List<&2, T.DomainEvent>, day: String) -> List<&2, T.DomainEvent>:
  day_result(C.merge(events, Nil{}), day)

def day_put(counts: List<&2, DayCount>, +day: String) -> List<&2, DayCount>:
  match counts:
    case Nil{}:
      [DayCount{day, 1n}]
    case DayCount{+key, +count} <> +t:
      Bool.pick(List<&2, DayCount>, String.eq(key, day), DayCount{key, 1n+count} <> t, DayCount{key, count} <> day_put(t, day))

def days_count(events: List<&2, T.DomainEvent>, counts: List<&2, DayCount>) -> List<&2, DayCount>:
  match events:
    case Nil{}:
      counts
    case h <> t:
      days_count(t, day_put(counts, event_day(h)))

def day_count_le(a: DayCount, b: DayCount) -> Bool:
  match a b:
    case DayCount{ad, an} DayCount{bd, bn}:
      String.is_ge(ad, bd)

def days_result(result: T.MergeResult) -> List<&2, DayCount>:
  match result:
    case T.EventConflict{id}:
      Nil{}
    case T.Merged{events}:
      List.sort(~DayCount, ~day_count_le, days_count(events, Nil{}))

def day_index(events: List<&2, T.DomainEvent>) -> List<&2, DayCount>:
  days_result(C.merge(events, Nil{}))

def record_day(record: T.Recorded) -> String:
  match record:
    case T.Recorded{id, ts, date, kind, body}:
      date

def records_for_day(records: List<&2, T.Recorded>, +day: String) -> List<&2, T.Recorded>:
  match records:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.filter.put(T.Recorded, h, records_for_day(t, day), String.eq(record_day(h), day))

def kind_rank(+kind: String) -> U32:
  Bool.pick(U32, String.eq(kind, "morning"), 0, Bool.pick(U32, String.eq(kind, "evening"), 1, 2))

def record_kind_le(a: T.Recorded, b: T.Recorded) -> Bool:
  match a b:
    case T.Recorded{ai, at, ad, ak, ab} T.Recorded{bi, bt, bd, bk, bb}:
      U32.is_le(kind_rank(ak), kind_rank(bk))

def day_summaries(state: T.State, day: String) -> List<&2, T.Recorded>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      List.sort(~T.Recorded, ~record_kind_le, records_for_day(summaries, day))

def day_reports(state: T.State, day: String) -> List<&2, T.Recorded>:
  match state:
    case T.State{tasks, summaries, reports, issues, complete}:
      List.sort(~T.Recorded, ~record_kind_le, records_for_day(reports, day))
