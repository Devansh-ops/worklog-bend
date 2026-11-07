import Base
import ./Types.bend as T
import ./Core.bend as C
import ./Publication.bend as P

type SourceMonth is Data:
  SourceMonth{month: String, currentExists: Bool, legacyExists: Bool, events: List<&2, T.DomainEvent>}

type Flags is Data:
  Flags{current: Bool, legacy: Bool}

type MonthGroup is Data:
  MonthGroup{month: String, events: List<&2, T.DomainEvent>, count: Nat, days: Nat, hadCurrent: Bool, hadLegacy: Bool, write: Bool, deleteLegacy: Bool}

type PlanResult is Data:
  Planned{events: List<&2, T.DomainEvent>, groups: List<&2, MonthGroup>}
  PlanningRefused{reason: String}

def event_day(event: T.DomainEvent) -> String:
  match event:
    case T.Ev{id, ts, day, payload, canonical}:
      day

def event_month(event: T.DomainEvent) -> String:
  String.take(event_day(event), 7n)

def string_in(strings: List<&2, String>, +value: String) -> Bool:
  match strings:
    case Nil{}:
      False{}
    case head <> tail:
      Bool.or(String.eq(head, value), string_in(tail, value))

def string_put(+value: String, +strings: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, string_in(strings, value), strings, value <> strings)

def event_months(events: List<&2, T.DomainEvent>, months: List<&2, String>) -> List<&2, String>:
  match events:
    case Nil{}:
      months
    case head <> tail:
      event_months(tail, string_put(event_month(head), months))

def source_months(sources: List<&2, SourceMonth>, months: List<&2, String>) -> List<&2, String>:
  match sources:
    case Nil{}:
      months
    case SourceMonth{month, current, legacy, events} <> tail:
      source_months(tail, string_put(month, months))

def source_events(sources: List<&2, SourceMonth>) -> List<&2, T.DomainEvent>:
  match sources:
    case Nil{}:
      Nil{}
    case SourceMonth{month, current, legacy, events} <> tail:
      List.append(&2, T.DomainEvent, events, source_events(tail))

def source_valid(sources: List<&2, SourceMonth>) -> Bool:
  match sources:
    case Nil{}:
      True{}
    case SourceMonth{month, current, legacy, events} <> tail:
      Bool.and(Bool.or(Bool.or(current, legacy), List.is_empty(&2, T.DomainEvent, events)), source_valid(tail))

def flags_add(current: Bool, legacy: Bool, rest: Flags, same: Bool) -> Flags:
  match rest same:
    case Flags{a, b} True{}:
      Flags{Bool.or(current, a), Bool.or(legacy, b)}
    case Flags{a, b} False{}:
      Flags{a, b}

def source_flags(sources: List<&2, SourceMonth>, +month: String) -> Flags:
  match sources:
    case Nil{}:
      Flags{False{}, False{}}
    case SourceMonth{key, current, legacy, events} <> tail:
      flags_add(current, legacy, source_flags(tail, month), String.eq(key, month))

def relocation_put(+source: String, +target: String, +dirty: List<&2, String>, same: Bool) -> List<&2, String>:
  match same:
    case True{}:
      dirty
    case False{}:
      string_put(target, string_put(source, dirty))

def relocation_events(events: List<&2, T.DomainEvent>, +source: String, dirty: List<&2, String>) -> List<&2, String>:
  match events:
    case Nil{}:
      dirty
    case head <> tail:
      +target = event_month(head)
      relocation_events(tail, source, relocation_put(source, target, dirty, String.eq(source, target)))

def relocation_sources(sources: List<&2, SourceMonth>, dirty: List<&2, String>) -> List<&2, String>:
  match sources:
    case Nil{}:
      dirty
    case SourceMonth{month, current, legacy, events} <> tail:
      relocation_sources(tail, relocation_events(events, month, dirty))

def events_for_month(events: List<&2, T.DomainEvent>, +month: String) -> List<&2, T.DomainEvent>:
  match events:
    case Nil{}:
      Nil{}
    case +head <> tail:
      List.filter.put(T.DomainEvent, head, events_for_month(tail, month), String.eq(event_month(head), month))

def event_days(events: List<&2, T.DomainEvent>, days: List<&2, String>) -> List<&2, String>:
  match events:
    case Nil{}:
      days
    case head <> tail:
      event_days(tail, string_put(event_day(head), days))

def make_group(month: String, +events: List<&2, T.DomainEvent>, flags: Flags, +migration: Bool, dirty: Bool) -> MonthGroup:
  match flags:
    case Flags{+current, +legacy}:
      MonthGroup{month, events, List.length(&2, T.DomainEvent, events), List.length(&2, String, event_days(events, Nil{})), current, legacy, Bool.or(migration, dirty), Bool.and(migration, legacy)}

def groups_for(months: List<&2, String>, +events: List<&2, T.DomainEvent>, +sources: List<&2, SourceMonth>, +migration: Bool, +dirty: List<&2, String>) -> List<&2, MonthGroup>:
  match months:
    case Nil{}:
      Nil{}
    case +head <> tail:
      make_group(head, events_for_month(events, head), source_flags(sources, head), migration, string_in(dirty, head)) <> groups_for(tail, events, sources, migration, dirty)

def group_events(group: MonthGroup) -> List<&2, T.DomainEvent>:
  match group:
    case MonthGroup{month, events, count, days, current, legacy, write, deleteLegacy}:
      events

def group_month(group: MonthGroup) -> String:
  match group:
    case MonthGroup{month, events, count, days, current, legacy, write, deleteLegacy}:
      month

def matching_events(events: List<&2, T.DomainEvent>, +month: String) -> Bool:
  match events:
    case Nil{}:
      True{}
    case head <> tail:
      Bool.and(String.eq(event_month(head), month), matching_events(tail, month))

def groups_match(groups: List<&2, MonthGroup>) -> Bool:
  match groups:
    case Nil{}:
      True{}
    case +head <> tail:
      Bool.and(matching_events(group_events(head), group_month(head)), groups_match(tail))

def contains_event(groups: List<&2, MonthGroup>, +event: T.DomainEvent, +writtenOnly: Bool) -> Bool:
  match groups:
    case Nil{}:
      False{}
    case MonthGroup{month, events, count, days, current, legacy, write, deleteLegacy} <> tail:
      Bool.or(Bool.and(String.eq(event_month(event), month), Bool.and(Bool.or(Bool.not(writtenOnly), write), C.exact_contains(events, event))), contains_event(tail, event, writtenOnly))

def events_covered(events: List<&2, T.DomainEvent>, +groups: List<&2, MonthGroup>, +writtenOnly: Bool) -> Bool:
  match events:
    case Nil{}:
      True{}
    case head <> tail:
      Bool.and(contains_event(groups, head, writtenOnly), events_covered(tail, groups, writtenOnly))

def legacy_events(sources: List<&2, SourceMonth>, +month: String) -> List<&2, T.DomainEvent>:
  match sources:
    case Nil{}:
      Nil{}
    case SourceMonth{key, current, +legacy, events} <> tail:
      List.append(&2, T.DomainEvent, Bool.pick(List<&2, T.DomainEvent>, Bool.and(legacy, String.eq(key, month)), events, Nil{}), legacy_events(tail, month))

def flag_legacy(flags: Flags) -> Bool:
  match flags:
    case Flags{current, legacy}:
      legacy

def deletion_safe(group: MonthGroup, +groups: List<&2, MonthGroup>, +sources: List<&2, SourceMonth>, migration: Bool) -> Bool:
  match group:
    case MonthGroup{+month, events, count, days, current, legacy, write, deleteLegacy}:
      Bool.or(Bool.not(deleteLegacy), Bool.and(migration, Bool.and(write, Bool.and(flag_legacy(source_flags(sources, month)), events_covered(legacy_events(sources, month), groups, True{})))))

def deletions_safe(remaining: List<&2, MonthGroup>, +groups: List<&2, MonthGroup>, +sources: List<&2, SourceMonth>, +migration: Bool) -> Bool:
  match remaining:
    case Nil{}:
      True{}
    case head <> tail:
      Bool.and(deletion_safe(head, groups, sources, migration), deletions_safe(tail, groups, sources, migration))

def checks(+schemas: List<&2, U32>, +sources: List<&2, SourceMonth>, pending: List<&2, T.DomainEvent>, +events: List<&2, T.DomainEvent>, +groups: List<&2, MonthGroup>, migration: Bool) -> Bool:
  Bool.and(P.schemas_compatible(schemas), Bool.and(source_valid(sources), Bool.and(groups_match(groups), Bool.and(events_covered(List.append(&2, T.DomainEvent, source_events(sources), pending), groups, False{}), Bool.and(events_covered(events, groups, False{}), deletions_safe(groups, groups, sources, migration))))))

def finish(events: List<&2, T.DomainEvent>, groups: List<&2, MonthGroup>, valid: Bool) -> PlanResult:
  match valid:
    case False{}:
      PlanningRefused{"planning coverage or relocation check failed"}
    case True{}:
      Planned{events, groups}

def grouped(+schemas: List<&2, U32>, +sources: List<&2, SourceMonth>, +pending: List<&2, T.DomainEvent>, +events: List<&2, T.DomainEvent>, currentMonth: String, +migration: Bool) -> PlanResult:
  months = List.sort(~String, ~String.is_le, source_months(sources, event_months(events, [currentMonth])))
  dirty = relocation_sources(sources, event_months(pending, Nil{}))
  +groups = groups_for(months, events, sources, migration, dirty)
  finish(events, groups, Bool.and(checks(schemas, sources, pending, events, groups, migration), events_covered(pending, groups, True{})))

def replayed(result: T.ReplayResult, schemas: List<&2, U32>, sources: List<&2, SourceMonth>, pending: List<&2, T.DomainEvent>, events: List<&2, T.DomainEvent>, currentMonth: String, migration: Bool) -> PlanResult:
  match result:
    case T.ReplayConflict{id}:
      PlanningRefused{"event ID content conflict"}
    case T.Replayed{state}:
      match state:
        case T.State{tasks, summaries, reports, issues, complete}:
          match complete:
            case False{}:
              PlanningRefused{"incomplete or unsupported source semantics"}
            case True{}:
              grouped(schemas, sources, pending, events, currentMonth, migration)

def merged(result: T.MergeResult, schemas: List<&2, U32>, sources: List<&2, SourceMonth>, pending: List<&2, T.DomainEvent>, currentMonth: String, migration: Bool) -> PlanResult:
  match result:
    case T.EventConflict{id}:
      PlanningRefused{"event ID content conflict"}
    case T.Merged{+events}:
      replayed(C.replay(events), schemas, sources, pending, events, currentMonth, migration)

def schema_gate(allowed: Bool, schemas: List<&2, U32>, +sources: List<&2, SourceMonth>, +pending: List<&2, T.DomainEvent>, currentMonth: String, migration: Bool) -> PlanResult:
  match allowed:
    case False{}:
      PlanningRefused{"unsupported source schema"}
    case True{}:
      merged(C.merge(source_events(sources), pending), schemas, sources, pending, currentMonth, migration)

def plan(+schemas: List<&2, U32>, sources: List<&2, SourceMonth>, pending: List<&2, T.DomainEvent>, currentMonth: String, migration: Bool) -> PlanResult:
  schema_gate(P.schemas_compatible(schemas), schemas, sources, pending, currentMonth, migration)

def group_write(group: MonthGroup) -> Bool:
  match group:
    case MonthGroup{month, events, count, days, current, legacy, write, deleteLegacy}:
      write

def writes(result: PlanResult) -> List<&2, MonthGroup>:
  match result:
    case PlanningRefused{reason}:
      Nil{}
    case Planned{events, groups}:
      List.filter(~MonthGroup, ~group_write, groups)

