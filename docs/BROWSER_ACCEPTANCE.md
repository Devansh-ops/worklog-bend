# Browser workflow acceptance

Executed on 2026-11-08 with Chromium 149.0.7827.55 and Playwright 1.61.0 against the integration app. `test/browser-workflow.mjs` is an actual browser test. It starts the shipped Node CLI, loads the real app and generated Bend modules over loopback HTTP, and drives named controls and dialogs at 1440px and 400px.

Every browser context is new. Tokens, repository contents, source trees and writes are synthetic. The test intercepts every non-loopback request. GitHub API responses contain correctly framed UTF-8 Git blob hashes so the actual source index and verified cache run. No request reaches GitHub, an AI provider, or a team channel. No real browser profile or user notes are read.

## Executed scenarios

| Scenario | Actual checks |
| --- | --- |
| Setup dialog | Cancel causes no effects; changing the example option regenerates the complete preview; private is the default; Send passes exactly the displayed file contents. This setup scenario injects a synthetic repository object into the real dialog. It is separate from the GitHub transport scenarios below. |
| Manual task work | Keyboard Enter creates a task; named status, priority, tags and note controls edit it; note search narrows the board; all staging performs zero HTTP requests. |
| Publication | Cancel performs no mutations. Advancing the synthetic branch after preview causes pre-write refusal, retains pending work and asks for a new preview. Fresh approval performs the Git tree/commit/ref route, writes exactly displayed contents and preserves an unrelated README. Reload restores the committed task. |
| Proposals | The in-page rules interpreter proposes two unrelated tasks. Interpretation alone stages nothing; deselecting one and applying the other stages exactly one create. |
| Summary and copy | The rules summary stages a summary event. A simulated failure of both Clipboard API and fallback records nothing. Successful copy records exactly the browser's copied bytes from the manually edited draft. |
| Wiki and deletion | At 400px the task and tag pages show task history and notes. Private selection and confirmed deletion remove the task from the board. The actual browser-loaded Bend context excludes its title and note afterward. |
| Durable report | A second explicit publication includes the report and summary. The copied report bytes remain in the remote synthetic ledger; reload retains the current-day Recorded acknowledgement and exposes the exact text under Last copied today. |
| Reminder | The real scheduled reminder fires for pending work, records the local date before dismissal, and does not repeat after another reload that day. Playwright controls the browser clock for this scenario. |

The successful run ended with no page errors, unexpected API routes or external requests. Tests throw or exit nonzero on failed expectations. Browser testing exposed a real delayed-focus race: the task dialog could steal focus during note entry and append note text to the title. Integration removed the delayed focus handoff; the task-edit scenario deliberately performs rapid named-control edits to retain this regression check.

## Reproduction

Install the exact Playwright version recorded in `toolchain/bend.lock.json` and its Chromium browser, or set `PLAYWRIGHT_MODULE` and `PLAYWRIGHT_CHROMIUM_EXECUTABLE` to an existing matching installation. Then run:

```powershell
node test/browser-workflow.mjs
```

The default source is this test's repository root. The optional WORKLOG_APP_ROOT override changes only the CLI source directory; no other checkout is required.

These checks cover one Chromium build and synthetic service responses. They do not establish live provider availability, authenticated GitHub API behavior, actual message delivery, WebGPU execution, all assistive technologies, or universal Bend laws. Separate vault, CLI, transport, source-cache, domain and proof checks remain necessary.

## Concurrent pending recovery

`node test/browser-pending.mjs` runs actual independent pages in one isolated
Chromium context sharing native localStorage. It first reproduced the original
stale-snapshot loss: simultaneous A/B staging restored only one event. After the
append-only journal fix, both restore. Separate deterministic scenarios verify
that discard removes only the draft actually observed by that tab, and that a
plan containing exactly B acknowledges B while unseen C remains recoverable
after both original tabs close and a new page reloads. Another branch sees none
of those events. Requests outside the loopback origin fail the test.

The aggregate `npm --loglevel verbose run test:browser:all` now has six actual
browser gates. It passed locally on Chromium 149.0.7827.55/Playwright 1.61.0 and
in the final production-source hosted Ubuntu workflow linked from STATUS.md.
This is real browser durability evidence, not a proof of arbitrary storage
interleavings. Journal retention and quota/recovery limits are documented in
PENDING_RECOVERY.md.
