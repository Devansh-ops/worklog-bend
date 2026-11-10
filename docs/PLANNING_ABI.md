# Checked month planning ABI

`bend/Planning.bend` owns calendar-month grouping, publication touch selection,
counts, migration selection and legacy-deletion permission. It imports the real
Core merge/replay and Publication schema predicate. `js/generated/planning.mjs`
is compiler output, not a second implementation.

Call `plan(schemas, sources, pending, currentMonth, migration)` with Bend-native
values. `schemas` contains every decoded physical source's schema as U32.
`SourceMonth{month,currentExists,legacyExists,events}` describes each verified
physical month. Combine the physical current and legacy event arrays, preserving
their complete canonical envelopes. Repeated month facts are allowed and their
existence flags are combined. Never manufacture empty facts for unread files.
`pending` contains complete canonical domain events. Dates, month strings, U32
bounds and the supplied local current month must already pass the host codec's
validation. Bend uses the first seven characters of each explicit event day;
it does not consult a clock or reinterpret UTC timestamps as local dates.

The result is `PlanningRefused{reason}` or `Planned{events,groups}`. `events` is
the complete canonical merged history. Groups are sorted by scalar month string
and include every original physical month, every event month and currentMonth.
Each `MonthGroup{month,events,count,days,hadCurrent,hadLegacy,write,deleteLegacy}`
contains full events in Core canonical order, Nat event count, distinct-day Nat
count, combined source flags and effect intentions. Preserve all canonical
event envelopes when serializing. Source flags support host preservation of
unknown supported metadata, including empty old physical source months.

Normal publication writes pending-event months and both sides of every
physical-month/local-day relocation. It leaves other groups' write flag false;
the host must keep their existing bytes, paths and statistics unchanged. Full
migration writes all groups. It marks an original legacy month for deletion
only after every event in that source is represented with exact full content
in a written destination group. Current-month statistics can be derived from
the corresponding group even when that month is empty.

`writes(result)` returns only write-marked groups and returns an empty list on
refusal. Host effects must reject the whole refused plan; an empty list alone
does not distinguish refusal from a valid no-op. Host JSON/Markdown rendering,
extension metadata preservation, approval of the complete final publication
artifact, provider calls and atomic persistence remain outside this module.
No legacy deletion is authorized before the complete publication approval and
transaction succeeds.

Every accepted plan runs postflight checks for supported schemas, physically
covered sources, exact source/pending/canonical event membership, matching
group months, pending inclusion in written groups and safe legacy relocation.
Incomplete replay, unknown event semantics and full-content ID collisions
refuse a plan. Duplicate equivalent delivery is merged once by Core.

`proof/PlanningLaws.bend` provides universally quantified typed proofs checked
with Bend 2.0.40's `--verdict`: `plan_safe` establishes those postflight relations
for every public-plan result; `partition_matches` separately proves the month
filter's structural correctness; `incompatible_no_writes` establishes no writes
for every schema list whose compatibility predicate is false. These guard
safety proofs do not assert that arbitrary supplied plans pass, prove host
codecs, or prove that every well-formed input succeeds. The runtime checks also
reject mutated lost-event, wrong-month and unauthorized-delete plans.

Validation commands from the repository root in a compiler-equipped Linux or WSL shell:

```sh
sh scripts/bend-linux.sh bend/Planning.bend --verdict
sh scripts/bend-linux.sh proof/PlanningLaws.bend --verdict
sh scripts/bend-linux.sh bend/Planning.bend -o js/generated/planning.mjs
node test/bend-planning.mjs
```

The synthetic generated-runtime suite includes a cross-UTC/local-month source,
empty month metadata slots, mixed current/legacy duplicate history, unsafe
legacy relocation mutations, future schemas at different list positions,
unsupported semantics, collisions, distinct day counts, unchanged caller-owned
values and 1,001 events spread across 1,001 month groups. Finite runtime tests
supplement the typed proofs; they are not universal proofs of browser behavior.
