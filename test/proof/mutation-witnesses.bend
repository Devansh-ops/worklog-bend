import Base
import ../../bend/Types.bend as T
import ../../bend/Core.bend as Core
import ../../bend/Publication.bend as Publication
import ../../bend/Reports.bend as Reports

# Runtime-only finite counterexamples. No other proof modules are imported,
# so a changed definition cannot fail at a still-true proof's script shape
# before the actual false property is checked.
def private_task() -> T.Task:
  T.Task{"T-aaa111", "Synthetic secret", T.SProgress{}, T.PNormal{}, Nil{}, True{}, False{}, "2026-11-08T00:00:00.000Z", "2026-11-08T00:00:00.000Z", None{}, [T.Note{"n-a", "2026-11-08T00:00:00.000Z", "CANARY_NOTE"}]}

def a() -> T.DomainEvent:
  T.Ev{"e-a", "2026-11-08T00:00:00.000Z", "2026-11-08", T.Noted{"T-aaa111", "A"}, "{\"id\":\"e-a\",\"taskId\":\"T-aaa111\",\"text\":\"A\",\"ts\":\"2026-11-08T00:00:00.000Z\",\"type\":\"task.note\"}"}

def b() -> T.DomainEvent:
  T.Ev{"e-b", "2026-11-08T00:00:00.000Z", "2026-11-08", T.Noted{"T-aaa111", "B"}, "{\"id\":\"e-b\",\"taskId\":\"T-aaa111\",\"text\":\"B\",\"ts\":\"2026-11-08T00:00:00.000Z\",\"type\":\"task.note\"}"}

def conflicting_a() -> T.DomainEvent:
  T.Ev{"e-collision", "2026-11-08T00:00:00.000Z", "2026-11-08", T.Noted{"T-aaa111", "A"}, "{\"id\":\"e-collision\",\"taskId\":\"T-aaa111\",\"text\":\"A\",\"ts\":\"2026-11-08T00:00:00.000Z\",\"type\":\"task.note\"}"}

def conflicting_b() -> T.DomainEvent:
  T.Ev{"e-collision", "2026-11-08T00:00:00.000Z", "2026-11-08", T.Noted{"T-aaa111", "B"}, "{\"id\":\"e-collision\",\"taskId\":\"T-aaa111\",\"text\":\"B\",\"ts\":\"2026-11-08T00:00:00.000Z\",\"type\":\"task.note\"}"}

law notes_off_omits_all_direct_notes:
  {Core.context_notes(Core.project(private_task(), False{})) == Nil{} : List<&2, T.Note>}
def notes_off_omits_all_direct_notes():
  {==}

law private_is_ineligible:
  {Core.eligible(private_task()) == False{} : Bool}
def private_is_ineligible():
  {==}

law future_schema_refused_witness:
  {Publication.approved([1, 999, 2], "same plan", "same plan") == False{} : Bool}
def future_schema_refused_witness():
  {==}

law changed_plan_refused_witness:
  {Publication.approved([1, 2], "approved plan", "substituted plan") == False{} : Bool}
def changed_plan_refused_witness():
  {==}

law complete_content_merge_witness:
  {Core.merge([a()], [b()]) == T.Merged{[a(), b()]} : T.MergeResult}
def complete_content_merge_witness():
  {==}

law reminder_disabled_witness:
  {Reports.reminder_decision(False{}, False{}, 1050, 1050, True{}, True{}, True{}) == Reports.ReminderOff{} : Reports.ReminderDecision}
def reminder_disabled_witness():
  {==}

law reminder_complete_day_witness:
  {Reports.reminder_decision(True{}, False{}, 1050, 1050, False{}, True{}, True{}) == Reports.ReminderOff{} : Reports.ReminderDecision}
def reminder_complete_day_witness():
  {==}

law reports_omit_private_head:
  {Reports.report_tasks([private_task()], Nil{}, False{}, True{}, True{}) == Nil{} : List<&2, Reports.ReportItem>}
def reports_omit_private_head():
  {==}

law collision_refusal_witness:
  {Core.scan_ids([conflicting_b()], [conflicting_a()], Some{conflicting_a()}) == T.EventConflict{"e-collision"} : T.MergeResult}
def collision_refusal_witness():
  {==}

law duplicate_delivery_single_event:
  {Core.merge([a()], [a()]) == T.Merged{[a()]} : T.MergeResult}
def duplicate_delivery_single_event():
  {==}
