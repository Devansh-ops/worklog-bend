import Base
import ../bend/Types.bend as T
import ../bend/Core.bend as C
import ../bend/Publication.bend as Pub
import ../bend/Planning.bend as P

# The relation independently inspects every emitted group, full event content,
# source schemas and each requested legacy deletion. Refusal has no effects.
def safe(result: P.PlanResult, schemas: List<&2, U32>, sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, migration: Bool) -> Bool:
  match result:
    case P.PlanningRefused{reason}:
      True{}
    case P.Planned{events, +groups}:
      Bool.and(P.checks(schemas, sources, pending, events, groups, migration), P.events_covered(pending, groups, True{}))

def finish_safe(+events: List<&2, T.DomainEvent>, +groups: List<&2, P.MonthGroup>, +schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +migration: Bool, choice: Bool, checked: {Bool.and(P.checks(schemas, sources, pending, events, groups, migration), P.events_covered(pending, groups, True{})) == choice : Bool}) -> {safe(P.finish(events, groups, choice), schemas, sources, pending, migration) == True{} : Bool}:
  match choice:
    case False{}:
      {==}
    case True{}:
      checked

def grouped_safe(+schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +events: List<&2, T.DomainEvent>, +current: String, +migration: Bool) -> {safe(P.grouped(schemas, sources, pending, events, current, migration), schemas, sources, pending, migration) == True{} : Bool}:
  months = List.sort(~String, ~String.is_le, P.source_months(sources, P.event_months(events, [current])))
  dirty = P.relocation_sources(sources, P.event_months(pending, Nil{}))
  +groups = P.groups_for(months, events, sources, migration, dirty)
  finish_safe(events, groups, schemas, sources, pending, migration, Bool.and(P.checks(schemas, sources, pending, events, groups, migration), P.events_covered(pending, groups, True{})), {==})

def replayed_safe(+result: T.ReplayResult, +schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +events: List<&2, T.DomainEvent>, +current: String, +migration: Bool) -> {safe(P.replayed(result, schemas, sources, pending, events, current, migration), schemas, sources, pending, migration) == True{} : Bool}:
  match result:
    case T.ReplayConflict{id}:
      {==}
    case T.Replayed{state}:
      match state:
        case T.State{tasks, summaries, reports, issues, complete}:
          match complete:
            case False{}:
              {==}
            case True{}:
              grouped_safe(schemas, sources, pending, events, current, migration)

def merged_safe(+result: T.MergeResult, +schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +current: String, +migration: Bool) -> {safe(P.merged(result, schemas, sources, pending, current, migration), schemas, sources, pending, migration) == True{} : Bool}:
  match result:
    case T.EventConflict{id}:
      {==}
    case T.Merged{+events}:
      replayed_safe(C.replay(events), schemas, sources, pending, events, current, migration)

def gate_safe(+allowed: Bool, +schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +current: String, +migration: Bool) -> {safe(P.schema_gate(allowed, schemas, sources, pending, current, migration), schemas, sources, pending, migration) == True{} : Bool}:
  match allowed:
    case False{}:
      {==}
    case True{}:
      merged_safe(C.merge(P.source_events(sources), pending), schemas, sources, pending, current, migration)

def plan_safe(+schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +current: String, +migration: Bool) -> {safe(P.plan(schemas, sources, pending, current, migration), schemas, sources, pending, migration) == True{} : Bool}:
  gate_safe(Pub.schemas_compatible(schemas), schemas, sources, pending, current, migration)

def unsupported_no_writes(schemas: List<&2, U32>, sources: List<&2, P.SourceMonth>, pending: List<&2, T.DomainEvent>, current: String, migration: Bool) -> {P.writes(P.schema_gate(False{}, schemas, sources, pending, current, migration)) == Nil{} : List<&2, P.MonthGroup>}:
  {==}

def incompatible_no_writes(+schemas: List<&2, U32>, +sources: List<&2, P.SourceMonth>, +pending: List<&2, T.DomainEvent>, +current: String, +migration: Bool, incompatible: {Pub.schemas_compatible(schemas) == False{} : Bool}) -> {P.writes(P.plan(schemas, sources, pending, current, migration)) == Nil{} : List<&2, P.MonthGroup>}:
  Equal.trans(List<&2, P.MonthGroup>, P.writes(P.plan(schemas, sources, pending, current, migration)), P.writes(P.schema_gate(False{}, schemas, sources, pending, current, migration)), Nil{}, Equal.cong(Bool, List<&2, P.MonthGroup>, allowed => P.writes(P.schema_gate(allowed, schemas, sources, pending, current, migration)), Pub.schemas_compatible(schemas), False{}, incompatible), unsupported_no_writes(schemas, sources, pending, current, migration))

# A structurally recursive partition fact, separate from the postflight guard.
def filter_step(+head: T.DomainEvent, +tail: List<&2, T.DomainEvent>, +month: String, keep: Bool, eq: {String.eq(P.event_month(head), month) == keep : Bool}, rest: {P.matching_events(tail, month) == True{} : Bool}) -> {P.matching_events(List.filter.put(T.DomainEvent, head, tail, keep), month) == True{} : Bool}:
  match keep:
    case False{}:
      rest
    case True{}:
      Equal.trans(Bool, Bool.and(String.eq(P.event_month(head), month), P.matching_events(tail, month)), P.matching_events(tail, month), True{}, Equal.cong(Bool, Bool, value => Bool.and(value, P.matching_events(tail, month)), String.eq(P.event_month(head), month), True{}, eq), rest)

def partition_matches(+events: List<&2, T.DomainEvent>, +month: String) -> {P.matching_events(P.events_for_month(events, month), month) == True{} : Bool}:
  match events:
    case Nil{}:
      {==}
    case +head <> +tail:
      filter_step(head, P.events_for_month(tail, month), month, String.eq(P.event_month(head), month), {==}, partition_matches(tail, month))

def is_planned(result: P.PlanResult) -> Bool:
  match result:
    case P.PlanningRefused{reason}:
      False{}
    case P.Planned{events, groups}:
      True{}

def witness_event() -> T.DomainEvent:
  T.Ev{"e", "2026-11-01T00:15:00.000Z", "2026-10-31", T.Created{"t", "synthetic", T.STodo{}, T.PNormal{}, Nil{}, False{}}, "full synthetic canonical envelope"}

# Nonempty accepted migration across a physical/local-month boundary. This
# rules out an always-refuse implementation satisfying safety vacuously.
def nonempty_migration_witness() -> {is_planned(P.plan([1], [P.SourceMonth{"2026-11", False{}, True{}, [witness_event()]}], Nil{}, "2026-11", True{})) == True{} : Bool}:
  {==}

# Even a matching event ID cannot authorize deleting a legacy source after its
# destination content is lost. No property of the desired output is assumed.
def lost_legacy_rejected_witness() -> {P.deletion_safe(P.MonthGroup{"2026-11", Nil{}, 0n, 0n, False{}, True{}, True{}, True{}}, [P.MonthGroup{"2026-10", Nil{}, 0n, 0n, False{}, False{}, True{}, False{}}], [P.SourceMonth{"2026-11", False{}, True{}, [witness_event()]}], True{}) == False{} : Bool}:
  {==}
