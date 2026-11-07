# Reference baseline and defect evidence

This is a historical record of the original source before the rebuild. Current
acceptance results are in STATUS.md. The runtime gate now runs the corrected
calendar oracle and all 48 suite executions pass. The fault-observation fixture
is retained for reference and is not a current release gate.

Checked 2026-11-07 against restored handoff `2dc1e08`, containing upstream
`53bff74016df38a9c88f6cf94c7b556225dd79fb`. Production source was unchanged at that baseline.
Host: Windows 11 build 26200, Node v25.8.1, npm 11.11.0; Windows zone
India Standard Time.

## Reproducible commands and actual results

| Command | Result |
| --- | --- |
| `npm --loglevel verbose test` | Exit 1: default Windows command shell cannot execute `./scripts/test.sh`. |
| Git Bash `bash scripts/test.sh` | Exit 1: configured default macOS JavaScriptCore executable is unavailable. |
| `node test/run-node-baseline.mjs` | Exit 1: 48 suite executions, 1004 assertions, 1002 passed and 2 failed. |
| `node test/reference-defects.mjs` | Exit 0: eight existing fault observations reproduced with synthetic data and intercepted fetch bodies. This is evidence of faults, not correctness. |
| `node test/cli-real-smoke.mjs` | Exit 0: shipped CLI executed using real Node filesystem and loopback HTTP. |

The Node baseline runner starts each of the twelve unchanged `*.test.js` suites
in its own process in Asia/Kolkata, Pacific/Kiritimati, Pacific/Niue, and UTC.
It supplies JSC's `print`/`quit` and makes Node's configurable `crypto` and
`navigator` properties writable for the existing shims. Assertions and suite
expectations are unchanged. It propagates failed exits and missing reports.

All suites passed in Pacific/Niue and UTC. Only the demo suite failed in the two
positive-offset zones: its assertion compares UTC `e.ts.slice(0, 7)` with the
local current month. The first generated event was locally in November but
UTC-dated October 31. This reproduces a mismatch between the test oracle and
the documented local-month filing policy. It does not establish lost demo data;
the same demo suite's Store-loading assertion passed. Resolve this explicitly
against the calendar contract rather than preserving the failing oracle.

These upstream suites replace browser APIs using `test/shim.js` and
`test/fake-dom.js`; they provide no real DOM, WebCrypto, clipboard, WebGPU, or
provider-service evidence. Network calls use fakes. The JSC runner additionally
rewrites the CLI's `node:*` imports to fake modules for `test/cli.check.js`.
That stub CLI check is excluded from the Node baseline count and was not run.

The separate real CLI smoke checks help, version, invalid-port exit status,
actual static GET and HEAD, content type, missing and malformed paths, encoded
traversal rejection, POST rejection, and the demo URL on an ephemeral loopback
port with `--no-open`. The test terminates its child process. This does not
verify interactive browser opening, graceful signal handling on Windows, port
conflict retry, or all distribution/setup workflows.

## Reproduced reference faults

`test/reference-defects.mjs` intentionally asserts observable faults in this
unchanged reference. It fails if those observations change. When the rebuild
replaces a path, replace the corresponding observation with an independent
intended-behavior regression; do not use these observations as release gates.

| Feature | Observation | Required intended behavior |
| --- | --- | --- |
| F07 | Same ID/different title silently keeps the first event; reversing inputs changes the result. | Return an explicit collision error. |
| F09 | A previously unseen status predating checkpoint `through` is dropped. | Establish actual event coverage and reconcile uncovered history. |
| F15 | `standup.set` at the checkpoint folds correctly directly, but disappears from `Store.state`. | Preserve reports through checkpoint reload. |
| F10 | Schema 999 manifest and board load, then preview emits a schema 2 manifest. | Reject unsupported future schemas before write plans. |
| F18 | Ollama with a remote HTTPS override retains `local: true`. | Classify the resolved destination. |
| F18 | Operation sanitizer accepts a known private task as a note target. | Restrict targets to request eligibility and revalidate on apply. |
| F18 | Actual intercepted summary request includes deleted-private task history, stored report text, and a previous headline. | Use an eligibility allowlist and policy-checked provenance for derived context. |
| F18 | `includeNotes: false` still sends an earlier potentially note-derived headline. | Withhold automatic note-derived context across secondary paths. |

The canary strings and repository objects are synthetic. Fetch is intercepted
before transport; no credential, work note, or request reaches a real service.
The privacy probe models the app's task list after deletion by passing no live
tasks while retaining task-linked historical events.

These checks inform Phase 2 contracts. They do not complete Phase 1, prove any
Bend law, or establish F01 through F24 acceptance.
