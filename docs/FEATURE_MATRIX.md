# Feature implementation and evidence

Updated 2026-11-08. This is an implementation/evidence inventory, not a claim that the remaining universal proof gate is complete. Browser transport tests use synthetic repositories and credentials; actual service availability is separate.

| ID | Implementation | Executed evidence |
| --- | --- | --- |
| F01 Repository access | `js/github.js`, settings and vault adapters | GitHub host suites, pinned-source/store tests, synthetic browser repository load. |
| F02 Setup | `js/bootstrap.js`, `js/ui/setup.js`, publication gate | Eight setup/atomic-effect checks; actual dialog Cancel/options/exact Send. |
| F03 Board commands | `bend/Core.bend`, task dialogs | Generated core tests, host command validation, rapid keyboard/edit/delete browser flow. |
| F04 Details/search | Core/Views, `js/domain.js`, board/wiki DOM | Completion/reopen, tags/notes, 13 view checks including Unicode; browser search and edits. |
| F05 Local staging | Core stage policy, branch-scoped Store | Pending reload/recovery/quota checks; actual browser staging makes no HTTP mutations. |
| F06 Publish | `bend/Publication.bend`, Store/GitHub/UI | Kernel plan-equality laws; exact immutable bytes; Cancel, success, in-flight edits and failure tests. |
| F07 Concurrent edits | Core merge and revision-bound Git refs | General successful-merge ID membership law; generated merge examples; stale-parent browser conflict/new approval. Full universal algebra remains pending. |
| F08 Ledger/rendering | Bend state plus store text serializers | Inherited readable-file/link checks; unknown/prototype-key extensions and exact atomic file payload checks. |
| F09 Long history | Complete source index and verified raw-body cache | 1,000-month cold/warm/changed-source test, tamper/quota tests, unlisted-source store replay. Cold history needs first verification. |
| F10 Compatibility/migration | Strict codecs, domain version policy, immutable migration | Future manifest/board/month refusal, old/current reconciliation, metadata retention, relocated-source deletion and setup refusal. |
| F11 Wiki | `bend/Views.bend`, wiki DOM | Task/tag/day/history projections, retained records, mobile task/tag/history browser checks. |
| F12 Brain dump | Prepared request, rules/provider adapter, Bend proposal gate | Malformed/stale/private proposal tests and actual deselected/selected rules UI application. |
| F13 Summary | Bend eligible activity, explicit host calendar, summary UI | Four-zone inherited checks; no old-summary/report canaries in outgoing bytes; actual rules summary staging. |
| F14 Standup | `bend/Reports.bend`, text renderer and editable pane | Nine report/reminder runtime checks; 160 reminder cases; notes-off/model-ID structure; browser edited draft. |
| F15 Copy recording | Clipboard adapter, Core retained reports, current-day details/wiki | Actual failed copy records nothing; success stores exact copied bytes; publish/reload and retrieval. |
| F16 Providers | Prepared HTTP/WebLLM/rules adapters | Nine HTTP presets with exact synthetic routes/headers; actual unavailable-WebGPU handling. No live provider/GPU run. |
| F17 Transport fallback | Frozen request transport and strict output codec | Bounded schema/parameter/token-option fallback, errors, malformed/duplicate/oversized output tests. |
| F18 Privacy/consent | Core eligibility/context plus request coordinator | Kernel private/deleted/notes laws; intercepted canaries; real browser Cancel/Send/stale guard and exact disclosure. |
| F19 Credentials | Existing PBKDF2/AES-GCM browser vault | Real browser wrong-pass/tamper/fresh salt/IV, 120k legacy and plain token compatibility, forget. |
| F20 Reminder | Bend decision and browser clock adapter | Kernel disabled/already-fired/complete-day/time guards; generated decision table; real scheduled once-per-day UI. |
| F21 Shell/layout | App pane shell and safe DOM | Actual 400px/wide layouts, panes, settings, focus restoration and subpath loading. |
| F22 Demo | In-memory repo and rules provider | Actual ephemeral task reload, no external requests, synthetic content; no demo publication route. |
| F23 CLI/distribution | Node CLI and reproducible generated assets | GET/HEAD/method/flags/port/junction/shutdown tests; npm pack dry run; subpath browser execution. |
| F24 Accessibility/safe text | Named controls, native dialogs and focus adapter | Real dialog/navigation/settings focus checks, keyboard edits, malicious title rendered as text, copy failure recovery. Not a full conformance audit. |

Proof scope remains the modeled Bend values and actual statements in `LAWS.bend`. JSON, Git blob hashing, generated JavaScript, DOM, browser APIs, GitHub and provider effects receive separate tests. User-authored free text is disclosed verbatim; no semantic-redaction promise is made.
