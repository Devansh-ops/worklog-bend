# Worklog Bend

A personal Kanban board, work journal and readable Git ledger, rebuilt with
Bend 2.0.40 for pure domain logic and mechanically checked laws.

An independent derivative of [Worklog](https://github.com/tanmayagrawal21/worklog)
by Tanmay Agrawal. The original Git history and MIT notice are preserved.

## Run the demo

```powershell
git clone https://github.com/Devansh-ops/worklog-bend.git
cd worklog-bend
npm --loglevel verbose start -- --demo
```

Open the local URL printed by the server. Demo tasks and edits are temporary.
Add `--no-open` to print the URL without launching a browser.

**A public hosted demo has not been deployed.** The upstream project's hosted
app runs its own implementation. This README will link to a hosted Worklog Bend
demo after that deployment has been verified.

To use your own data repository, run `npm --loglevel verbose start` without
`--demo` and follow [SETUP.md](SETUP.md). Terminal setup is also available with
`npm --loglevel verbose run setup:data` using an authenticated GitHub CLI.

## Features

- Six-column board with keyboard and drag/drop status changes, priorities, tags,
  private tasks, notes, search and task history.
- Local unpublished edits, branch-scoped recovery and concurrent-tab draft
  preservation. Every publication requires approval of the exact commit plan.
- JSON event history, readable Markdown ledgers, board snapshots and year indexes
  in a separate data repository that you control.
- Task/tag/day wiki, summaries, editable morning/evening reports and exact
  clipboard-copy records. AI is optional; deterministic reports work with it off.
- Explicit request disclosure for optional AI, current privacy filtering, selected
  proposal validation and protection against stale requests or edited drafts.
- Optional encrypted credential storage, reminders, responsive panes and themes.

## What Bend owns

`bend/` implements event merge and replay, validated commands, completion and
deletion semantics, privacy projections, reports/reminders, board/wiki/search
decisions, schema compatibility, month migration/publication planning and exact
approval checks. JavaScript handles JSON/Unicode/calendar conversion, rendering,
storage, WebCrypto, clipboard, GitHub and provider effects.

The five generated ES modules in `js/generated/` are committed with an integrity
manifest. Running the application needs Node 18+ and a browser; it downloads no
compiler and needs no application backend. Rebuilding the domain assets requires
the pinned developer toolchain.

The independent checker accepts important laws in [LAWS.bend](LAWS.bend) and
[PROOF.bend](PROOF.bend), including canonical merge algebra, full event
preservation, ID uniqueness, conflict detection, current/historical privacy,
schema/planning coverage and exact acknowledgement. See
[LAW_REVIEW.md](docs/LAW_REVIEW.md) for quantifiers, preconditions and witnesses.
The proofs cover the stated Bend model; browser APIs, codecs, generated execution
and network effects have separate tests.

## Data and privacy

Keep the application source repository separate from your work-data repository.
Making this source public does not require publishing your task data.

Deleted tasks retain history and tombstones but are excluded from automatic AI
context. Private task history is also excluded. Notes-off suppresses automatic
note context; explicitly selected free text is disclosed verbatim. Credentials
are excluded from event files and model disclosures.

The local pending recovery journal is append-only and retains old event content
after discard or publication. It consumes browser storage over time. See
[PENDING_RECOVERY.md](docs/PENDING_RECOVERY.md) for quota and recovery behavior.
Git history also retains previously published task data.

## Verification and development

```powershell
npm --loglevel verbose test
npm --loglevel verbose run check:build
npm --loglevel verbose run test:proof
npm --loglevel verbose run test:browser:all
```

Install the pinned compiler, proof tools and Playwright before the corresponding
developer gates, following [BEND_TOOLCHAIN.md](docs/BEND_TOOLCHAIN.md).
Full compiler imports and Lean-backed verdicts use Linux or WSL Ubuntu on Windows.

Recorded acceptance includes 16 runtime/adapter suites, four-zone inherited
regressions, 13 deliberate proof mutations and six real Chromium gates. The
workflow runs in [GitHub Actions](https://github.com/Devansh-ops/worklog-bend/actions).
[STATUS.md](docs/STATUS.md) and [FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md) record
actual results and limits.

This is an experimental release. Live provider authentication/CORS, real GPU
inference and OS browser launching have not been exercised. The rebuild has not
been published to npm; `npx work-log` is not an installation command for this fork.

## Hosting and contributing

The app is static and supports repository subpaths. Deploy the reviewed HTML,
CSS, JavaScript and generated modules together, preserving their directory
layout. GitHub Pages is not currently enabled for this repository.

For bugs, include a minimal synthetic reproduction and the relevant test command.
Keep changes to pure domain logic and their laws together; test effect adapters
separately. See the [rebuild plan](docs/REBUILD_PLAN.md) for architecture and the
[public-release notes](docs/PUBLIC_RELEASE.md) for remaining publication choices.

## License and attribution

Worklog and the application modifications retain the [MIT license](LICENSE).
Generated assets also contain translated Bend Base/runtime code from the pinned
compiler revision, whose Apache-2.0 license is included under `licenses/`.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source revision and notices.
