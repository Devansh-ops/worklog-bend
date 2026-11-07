# Acceptance fixtures and exact setup approval

Updated 2026-11-08. This records executed host checks, not completion of the full rebuild or additional proof guarantees.

The upstream Node baseline now awaits every asynchronous store test. Several original tests used a synchronous check helper with an async callback, which could report success before the assertion ran. Store fixtures load actual synthetic source files before commands; the tests do not bypass the authoritative-history guard by setting its flag.

Changed expectations follow the reviewed requirements. Schema 1/2 snapshots without verified coverage are display caches, not authoritative history. Tests require full replay, reject snapshot-only seeding, preserve distinct note event IDs, retain unsupported edit semantics as diagnostics, and pass the exact immutable migration plan to execution. Readable snapshot metadata still round-trips, but cannot establish coverage by naming its own watermark. The pending-description test deliberately removes a loaded-month marker after loading a valid source to exercise its defensive preview gate.

Standup-view fixtures include complete synthetic task creation history and event IDs. The standalone report fixture builder likewise constructs authoritative history, including private flags and deletion events. Separate task rows are no longer treated as evidence of model eligibility. GitHub creation fixtures answer the authenticated-account preflight before accepting a repository POST.

`js/bootstrap.js` now separates preparation from effects. `prepareScaffold` produces frozen exact files, message, destination, branch, visibility, and expected base. Existing unseeded repositories are read at that base. An existing README is retained; partial worklog files cause a safe refusal rather than replacement. `scaffold` accepts only the prepared plan owned by that repository instance and verifies destination equality through the generated Bend approval gate. Empty repositories use one atomic root commit without an individual-file fallback. Unseeded repositories pass the approved expected parent to the GitHub adapter.

The setup UI shows the actual message and expandable full file contents. Changing examples or visibility creates and displays a new prepared plan. A generation guard discards stale asynchronous previews. Confirmation returns the displayed frozen object; execution does not regenerate timestamps, random example IDs, or file contents. Cancel performs no write.

Executed in this worktree against the integration dependency commit `6824b2b`:

- `node test/run-node-baseline.mjs`: 48 executions across Asia/Kolkata, Pacific/Kiritimati, Pacific/Niue, and UTC; 1,004 assertions; zero failed executions. This uses browser API shims and is not browser evidence.
- `node test/bootstrap-plan.mjs`: seven setup/effect checks passed. They cover exact immutable preparation, changed options/destination, preserving README, partial-data refusal, base conflict, pinned inspection, atomic root-ref collision, and wrong-owner refusal. HTTP is intercepted with synthetic values and fake credentials.
- `node --check js/bootstrap.js`, `node --check js/ui/setup.js`, and `git diff --check`: passed.

The integration agent must rerun these checks after later source changes and run the actual browser setup flow. These tests do not prove GitHub or browser correctness, execute real service writes, or close the outstanding universal merge/checkpoint/migration obligations in `LAW_REVIEW.md`.
