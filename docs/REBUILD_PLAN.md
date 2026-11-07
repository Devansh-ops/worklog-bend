# Worklog Bend rebuild plan

Updated: 2026-11-08. Restoration is complete, the verified toolchain is established, and the Bend-backed application is runnable. Local acceptance is complete for the implemented application and important modeled invariants; final hosted confirmation is recorded in STATUS.md. See docs/STATUS.md, docs/FEATURE_MATRIX.md and docs/LAW_REVIEW.md for actual results and exclusions.

Read `AGENTS.md`, `docs/STATUS.md`, and `docs/SPEC.md` first. The original Worklog
application is the feature reference, not an infallible behavioral oracle. The
goal is the full feature inventory F01 through F24 in the specification.

## Runtime boundary

| Layer | Ownership and contract |
| --- | --- |
| Bend domain core | Validated domain values and commands; event reconciliation/fold; checkpoint rules; deterministic board/wiki/report projections; privacy/request selection; proposal sanitization; reminder decisions; serialization model; publish/migration plans. Pure functions receive clock/calendar/randomness results as explicit values. |
| JavaScript codec bridge | Validate untrusted JSON, preserve compatible unknown data, translate to/from the compiler's actual generated ABI, copy mutable host arrays when needed, and return typed errors. No duplicate independent implementation of domain decisions. |
| JavaScript effect adapters | DOM and CSS rendering; event listeners, drag/drop, dialogs, focus and clipboard; localStorage; Date/timezone conversion; crypto randomness and WebCrypto vault; fetch/GitHub HTTP; WebLLM worker, CDN loading, cache and WebGPU. These are tested boundaries outside proof guarantees. |
| Effect coordinator | Execute plans only after the appropriate user action, track approved destination/content, preserve pending events on failure, and re-preview materially changed plans. Handle cancellation, stale results, and edits made during requests. |
| Build and delivery | Pinned Bend2 compiles the core into static ES modules, or another browser route verified in Phase 1. Node CLI and static hosting serve the shipped assets without a compiler, backend, or database in the deployed app. |

The guide reviewed at Bend commit
`be236f324ed0338fe907fe50474468e4d3b94157` describes emitted `.mjs` modules and
`--verdict`. That reference is not a compiler pin or validation result. Consult
`bend guide`, `bend base`, and compiler help from the installed pin before writing
production syntax. Do not paste speculative Bend code into a purported runnable
handoff.

## Parallel work and integration

The integration agent owns the main worktree, shared contracts, acceptance gates,
and final review. Use a separate branch and worktree for each independent agent.
Start branches from the most recent accepted integration commit. Use unique
sibling worktree directories rather than nesting one checkout inside another.

Proposed ownership after Phase 1 validates paths and tooling:

| Branch and worktree suffix | Agent ownership | Dependency |
| --- | --- | --- |
| `build/bend-toolchain`, `worklog-bend-toolchain` | Toolchain lock, build scripts, generated-ABI smoke test, compiler CI job. | Start Phase 1. |
| `feat/bend-core`, `worklog-bend-core` | Bend domain types, merge/fold, checkpoint and compatibility logic, core behavior fixtures. | Accepted Phase 1 ABI and Phase 2 contract. |
| `proof/domain-laws`, `worklog-bend-laws` | `LAWS.bend`, `PROOF.bend`, law review notes, proof-negative checks. | Shared types; pair with core agent. |
| `feat/bend-store`, `worklog-bend-store` | JSON/storage/repository adapters and publish coordination, store integration tests. | Accepted core interface and write-plan schema. |
| `feat/bend-ai`, `worklog-bend-ai` | Providers, request/consent adapter, model response integration, WebLLM worker boundary, AI tests. | Accepted privacy/request and proposal contracts. |
| `feat/bend-ui`, `worklog-bend-ui` | Browser shell, board/wiki/summary/standup/setup/settings views, HTML/CSS and browser tests. | Accepted projection and command interface. |
| `test/release-parity`, `worklog-bend-release` | End-to-end coverage, CLI/setup packaging, deployment docs and final parity matrix. | Accepted integrated vertical slices. |

The integration agent alone owns `docs/STATUS.md`, shared package/test-runner
configuration, and contract changes after agreement. Assign non-overlapping test
files along with source files. A feature agent can request a law change, but law
changes must receive separate requirements review before the proof agent applies
them. Review laws for missing preconditions, vacuity, and weakened claims as well
as checking proofs. Do not silently redefine a law to fit an implementation.

Each handoff includes commit hash, owned files, actual commands and results,
assumptions, known gaps, and feature/law IDs. Review the diff, integrate the
coherent commit, then run the phase gate in the integration worktree. Do not
force-push, rewrite upstream history, or include real credentials or work notes.
Use repository-local identity `Devansh Sehgal <devanshsehgal02@gmail.com>`.

## Phase 1: establish a verified compiler and runnable bridge

Status: tooling gate completed with exact pin, real verdict/negative fixtures, generated ABI and static browser execution. See BEND_TOOLCHAIN.md. Hosted CI remains separately recorded in STATUS.

1. Record OS/architecture and required Node/runtime versions. Choose an exact
   Bend2 commit or release, lock installation source and integrity information,
   and make installation reproducible. A moving branch is insufficient.
2. Run the installed compiler's help, guide, and Base inspection. Confirm actual
   syntax, module imports, constructors, error types, termination behavior, and
   ES-module export behavior against that pin.
3. Compile and execute a tiny pure-domain smoke fixture through JavaScript and a
   browser. Verify strings, booleans, constructors, lists, numeric bounds, errors,
   and input mutation/array ownership. Inspect generated exports rather than
   assuming an ABI from documentation.
4. Check a small true law and a deliberately false/open law. Confirm the false
   case causes a machine-detectable failure. Run `bend PROOF.bend --verdict` when
   the pin supports it; capture the exact result and its scope. Validate the
   verdict route early, before committing to a large proof architecture.
5. Establish a reproducible browser build, static asset manifest, test commands,
   and CI toolchain/proof checks. Preserve the original runnable app while this
   bridge is being validated.

Acceptance gate: exact compiler pin and fresh-install instructions; recorded
smoke outputs; positive and negative proof checks; generated code runs via static
HTTP; adapter ABI documented; no proof placeholders presented as success. If the
required pin cannot support the proof/browser route, record the blocker and keep
the phase pending instead of substituting unverified claims.

## Phase 2: freeze behavior, compatibility, and law contracts

Status: contracts and witnesses reviewed; source/evidence inventory recorded in FEATURE_MATRIX.md and DOMAIN_CONTRACTS.md.

Inventory F01 through F24 against source and meaningful upstream tests. Run the
existing suite and record baseline results, including any environment-specific
limitations. Inspect `scripts/test.sh` before adapting its execution environment;
do not describe a stubbed check as a real browser or Node integration test.
Include `--loglevel verbose` in npm commands, for example
`npm --loglevel verbose test`.

Define typed events, tasks, commands, errors, snapshots, privacy provenance,
calendar inputs, request payloads, and immutable write plans. Specify legacy
defaults and preservation of unknown supported data. Decide how a checkpoint
proves coverage of older events and how privacy/deletion metadata survives
snapshot trimming. Reconcile status and completion metadata consistently across
create, edit, move, and reopen. Decide branch-scoped pending-storage migration.

Turn the candidate laws in `docs/SPEC.md` into independently reviewable laws with
explicit preconditions and concrete valid-state witnesses. Add synthetic
counterexamples for ID collisions, backdated events, future schemas, private
historical events, and free-text secondary paths. Keep test oracle expectations
separate from the implementation under test.

Acceptance gate: approved contracts and fixture formats, feature coverage matrix,
law review, code-review observations reproduced or corrected by evidence, and an
explicit decision on any data-format change. No implementation may silently
downgrade unknown schemas or copy an identified reference defect for parity.

## Phase 3: implement and prove the event core

Status: accepted modeled core gate. Real verdict covers canonical uniqueness/order/algebra, conflicts, accepted-command closure, reconciliation and privacy; runtime behavior is checked independently. LAW_REVIEW.md states exact proof limits.

Implement event validation, commands, collision-aware canonical merge, replay,
notes, deletion, status/completion metadata, summaries/reports, and checkpoint
reconciliation in Bend. Keep the old UI runnable against a compatibility bridge
while replacing domain decisions. Prove accepted core laws in `PROOF.bend`
against `LAWS.bend` and run the pinned checker/verdict gate.

Acceptance gate: canonical merge laws and independent behavior tests agree;
concurrent updates and same-timestamp ties retain all events; malformed data and
conflicting IDs are explicit failures; snapshot/full replay equivalence is checked
under real coverage assumptions; late events are preserved; recovered notes do
not rewind state; published summaries and standups survive reload. No law relies
on `@unsafe`, foreign effects, or an uninhabited valid-state assumption.

## Phase 4: storage, readable ledger, migration, and publish

Status: implemented and accepted locally with checked month planning, exact immutable plans, verified source caching, append-only pending recovery and independent adapter/browser gates.

Implement schema guards and codecs, local staging/restore/discard, lazy history,
snapshot trimming/recovery, month/year/Markdown rendering, manifest statistics,
setup/scaffold plans, migration plans, and GitHub effects. Preserve unrelated
files with atomic Git tree commits. Bind previews to destination, branch, base
revision, exact content, deletions, and acknowledged pending IDs.

On ref conflict, reload and reconcile needed history, rebuild the plan, and show
a new preview when approval no longer covers the changed result. Preserve new
edits made while an earlier plan is publishing. Check future schemas again on
conflict reload and before migration or publishing.

Acceptance gate: synthetic legacy and current repositories round-trip without
lost events; future manifest/snapshot/month data produce no destructive plan;
boundary-month migration is lossless; full-history migration deletes only
relocated files; retries are bounded; pending events survive failure; bootstrap
handles missing/empty/unseeded/ready states. Link checks cover generated Markdown.
Large synthetic history verifies bounded recent-month reads, with lazy history
recovery and explicit fallback when checkpoint validity is insufficient.

## Phase 5: privacy and all AI paths

Status: implemented and accepted within the tested provider boundary: synthetic bytes for every HTTP preset, real browser consent and stale-session/draft protection. Live provider/GPU checks remain explicit limits.

Implement the eligible-task projection, note policy, actual-destination locality,
immutable request/disclosure object, endpoint-specific consent, model-response
validation, operation revalidation, and bounded output formatting. Integrate all
provider families, structured-output fallback, model discovery, WebGPU load/
unload/progress, demo rules, and provider-specific errors. Keep API details
outside Bend unless they represent domain policy.

Acceptance gate: intercept actual outgoing request bytes using fake credentials.
Canary private titles/notes must be absent from board, historical event, previous
summary, standup-derived, retry, and endpoint-override paths. Notes-off must omit
automatic note-derived context. Separately test verbatim disclosed free text so
tests do not falsely promise semantic redaction. Cancelled consent causes no
request; changing destination requires consent; AI off causes no model calls.
Malformed or stale proposals do not change state; only selected valid proposals
are staged. Every provider branch gets deterministic transport-contract tests;
real service smoke checks, if run, use synthetic content and record limitations.

## Phase 6: full browser feature parity

Status: implemented and accepted locally through six real Chromium gates, including native vault operations, concurrent pending recovery and complete workflows. See BROWSER_ACCEPTANCE.md and STATUS.md.

Complete board, details, wiki, summaries, standup, brain dump, setup, settings,
reminders, pane layouts, search, themes, loading/error recovery, and demo. Use
generated Bend projections and commands throughout. Verify the deterministic
standup path with AI disabled, latest copied report persistence, exact clipboard
recording, edited AI write-ups, stale/update behavior, and once-per-day reminders.

Acceptance gate: browser tests exercise setup, manual edits, selected proposals,
publish preview/cancel/success/conflict, reload, wiki history, summaries, report
copy/failure, and reminders. Test 400px and wide pane layouts, keyboard actions,
dialog focus, safe text rendering, storage failure, unavailable WebGPU, and
unsupported network/provider responses. Test WebCrypto save/unlock/wrong
passphrase/tampered ciphertext with the actual browser implementation. No test
posts a report to a team channel or sends real credentials to providers.

## Phase 7: packaging, deployment, and final acceptance

Status: all local gates passed. Clean GitHub checkout/build and hosted Ubuntu checks already passed earlier integrations; final-source hosted confirmation and remote equality are recorded in STATUS.md.

Verify CLI flags, static path confinement and GET/HEAD behavior, browser launch,
port conflicts, clean shutdown, setup/scaffold output, and distribution contents.
Create a clean build that runs under a repository subpath without development
tools. Include generated assets by a reproducible documented policy and ensure
package/deployment includes them. Preserve MIT license and upstream provenance.

Run the pinned proof/verdict gate, core and codec tests, adapter tests, relevant
upstream regressions, integration tests, and browser acceptance suite. Compare
against every F01 through F24 requirement and approved defect regression. Inspect
emitted JavaScript for the bridge contract and test runtime behavior independently
of normalization/typechecking.

Acceptance gate: every feature has recorded evidence; no stubs, missing proof
obligations, silent schema conversion, or untested privacy path; fresh clone/build
instructions work on the supported host; deployed static artifacts are reviewed;
`docs/STATUS.md` records actual commands, results, version pins, and remaining
limits. Push only reviewed commits to the authorized `worklog-bend` destination
using the user's authenticated local GitHub CLI and preserve private visibility
by default. Do not publish a BendHub package as part of this rebuild.

## Accepted implementation decisions

- Full verified-source replay replaces the unsafe timestamp-watermark snapshot
+  shortcut. Warm raw-body caching bounds network reads while preserving complete
+  deletion/late-event provenance. Cold loads must verify all sources.
+- Same-ID content conflicts are errors; peer Git changes require new explicit
+  approval rather than an automatic materially changed retry.
+- Copied reports record exact clipboard text, not delivery to a team channel.
+- Local pending operation journals prevent cross-tab stale-snapshot loss. They
+  retain content and grow until an explicit future safe compaction design.
+- Proof acceptance concerns the stated important pure-domain invariants. Host
+  effects and representation boundaries have executed independent tests; live
+  provider/GPU/OS integration limits remain visible in STATUS.md.
+
+## Handoff checkpoint

Restoration and the runnable rebuild are implemented. All local proof, runtime
+and browser gates passed. Keep STATUS.md and LAW_REVIEW.md current when behavior
+changes, preserve private source visibility and upstream history, and rerun the
+appropriate gates before integrating future work.
