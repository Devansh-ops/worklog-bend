# Worklog Bend status

Updated: 2026-11-10. The Bend-backed application is implemented and runnable.
Local acceptance, clean-checkout reproduction and hosted Ubuntu CI passed for
production integration `cb8de30`. The concurrent-tab fixture was then strengthened
to assert its exact observed approval and passed again at `bc7bc35`.

## Implemented application

The full F01-F24 inventory is implemented with evidence in `FEATURE_MATRIX.md`.
Bend owns merge/replay, commands and selected-proposal validation, completion and
tombstones, current/historical privacy, report/reminder decisions, owner board,
search/wiki projections, schema policy, month publication/migration planning and
exact publication approval. JavaScript owns validated JSON/Unicode/calendar
boundaries, DOM/HTML/CSS, storage, WebCrypto, clipboard, providers and HTTP.
Five generated static ES modules and their integrity manifest ship with the app.

Unverified schema 1/2 snapshots remain display caches. A complete pinned Git tree
discovers unlisted physical sources; cached raw bodies must match remote Git
blob hashes. Canonical authoritative replay preserves late events, deletion
privacy provenance and latest reports. The synthetic 1,000-month check reads
1,002 bodies cold, zero unchanged, and three when three sources change. No
timestamp-watermark or unproved incremental-tail shortcut is used.

Setup, publication and migration execute exact immutable previews against their
approved parent. Conflicts preserve drafts and require a new preview. Only exact
approved events are acknowledged; edits arriving during effects survive. Copied
report text remains inspectable after reload. Copying does not establish delivery.

Pending recovery now uses an append-only branch-scoped operation journal before
the compatibility snapshot. Actual two-tab tests reproduce the old overwrite and
verify both drafts survive the fix, including observed-only discard and exact
acknowledgement. Malformed data stays intact and enters read-only recovery;
quota failures retain the available memory/journal evidence. See
`PENDING_RECOVERY.md` for storage growth, retention and recovery limits.

AI paths disclose one immutable request and send those exact values. Private and
deleted task history is excluded; notes-off withholds automatic note context.
Previous summaries/reports are not secondary context. Selected operations are
revalidated, changed credentials invalidate prepared requests, and stale report
responses cannot overwrite edited drafts. User-selected free text is disclosed
verbatim, with no semantic-redaction promise.

## Executed acceptance

| Gate | Actual result |
| --- | --- |
| Pinned toolchain | Bend 2.0.40 at `70607d7f740e3b3f4a1edc61069df8ab88491696`, SHA-256 checked; Bun 1.3.10 and Lean 4.34.0. Real true/false/open/nonterminating verdict outcomes checked. |
| `npm --loglevel verbose run check:build` | Real root and Planning verdicts accepted; all five generated assets and source/asset integrity manifest reproduced exactly. |
| `npm --loglevel verbose run test:proof` | Real root verdict accepted, with 168 declarations including supporting lemmas and witnesses. All 13 named finite mutation counterexamples and full production-source mutant gates rejected as expected. These are not 168 independent application guarantees. |
| `npm --loglevel verbose test` | All 16 runtime/adapter suites passed, including 48 inherited suite executions across four zones with 1,004 assertions, 30 store groups, strict codecs, generated domain, cache, provider contracts, portable setup and real CLI/package tests. |
| `npm --loglevel verbose run test:browser:all` | All six real Chromium gates passed: generated ABI, 400px/wide demo and focus, exact AI consent, full setup/task/publish/report/wiki/reminder workflows, native vault/subpath execution, and concurrent-tab pending recovery. |
| Hosted Ubuntu | [Full final-source workflow](https://github.com/Devansh-ops/worklog-bend/actions/runs/42411768245) passed for `cb8de30`, including all 13 mutations, 16 runtime suites and six browser gates. Earlier integrations also passed. |
| Fresh GitHub clone | Fresh GitHub checkout downloaded/hash-verified locked compiler/proof tools. Fast-forward to `cb8de30` accepted root/Planning verdicts, reproduced every asset and passed real CLI smoke. Checkout remained clean. |

Browser: Chromium 149.0.7827.55 through Playwright 1.61.0. Windows: Node 25.8.1,
npm 11.11.0. Full compiler imports and independent kernel checks use WSL Ubuntu
because the pinned native Windows compiler has an import-path defect. The
compiler was not patched. The deployed static app needs no compiler or backend.

## Scope and remaining limits

Important modeled invariants are accepted in `LAWS.bend` and `PROOF.bend`:
complete event preservation, unique IDs and canonical order, arbitrary-position
content conflicts, consistent-input success and merge algebra, accepted-command
replay closure, duplicate/order-independent reconciliation, retained records,
current/historical privacy, notes-off, schema/planning coverage, safe legacy
deletion, exact approval/acknowledgement, report exclusion and reminder guards.
`LAW_REVIEW.md` distinguishes universal statements, conditional coverage results,
support lemmas and nonempty witnesses. This is not universal verification of the
compiler, JSON, DOM, storage, transport or all rendering/calendar behavior.

Deterministic provider and repository fixtures use synthetic data and credentials.
Live GitHub persistence also passed with synthetic data and an in-memory
credential relay; see LIVE_GITHUB_ACCEPTANCE.md.
Live provider authentication/CORS, real GPU model inference and OS default-browser
launching were not executed. No npm/BendHub package was published. The public hosted site is verified below.
Source publication and hosted deployment are separate release actions.

Run locally from the checkout with `npm --loglevel verbose start -- --demo`.
Developer reproduction: `BEND_TOOLCHAIN.md`. Detailed boundary evidence:
`CORE_ABI.md`, `PLANNING_ABI.md`, `STORE_PROTOCOL.md`, `SOURCE_CACHE.md`,
`AI_TRANSPORT.md`, `BROWSER_ACCEPTANCE.md`, `RELEASE_CHECKS.md`.

## Hosted application

The source repository is public. GitHub Pages serves `main` from the repository
root with HTTPS enforcement and `.nojekyll`:

- App: https://devansh-ops.github.io/worklog-bend/
- Demo: https://devansh-ops.github.io/worklog-bend/?demo=1

Initial deployment `d939430` built successfully. `scripts/test-hosted-site.mjs`
verified the public HTML/CSS/worker and license paths, JavaScript MIME types,
and all five generated module byte counts/hashes against the local manifest.
Real Chromium verified the normal welcome link and the 1440px/400px demo:
synthetic edits appeared and disappeared on reload, with no page errors, failed
asset responses or requests outside the hosted project. No work data or tokens
were published by this deployment. Browser tests use isolated contexts.

## Preview acceptance

The complete hosted workflow passed for commit 7b27e21 (run 42759083059),
including reproducible assets, real verdicts, all mutations, runtime suites and
six browser gates. Live GitHub persistence then passed against that deployed
source: exact approved bytes/message/parent and complete tree changes, real peer
conflict rejection, in-flight edits and fresh-context replay. All temporary
synthetic repositories were removed. See LIVE_GITHUB_ACCEPTANCE.md and
releases/v0.1.0-preview.1.md for scope and reproduction.
