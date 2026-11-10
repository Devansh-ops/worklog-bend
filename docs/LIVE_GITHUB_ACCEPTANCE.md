# Live GitHub persistence acceptance

Executed on 2026-11-10 against deployed source
`7b27e21e14362638a3b6b3e3595c33830a06936f`, using Chromium 149.0.7827.55.
The hosted adapter sources were compared with the checkout before any writes.

The opt-in `scripts/test-live-github.mjs` created a fresh private repository
containing synthetic data. Independent browser contexts used the hosted app.
The actual GitHub API and Git objects established these results:

- Bootstrap preserved the unrelated README.
- Local staging and Cancel left the remote branch unchanged.
- Five approved commits matched the exact previewed message, parent and file
  bytes. Comparing complete parent/result leaf trees found no unapproved change.
- A peer publication invalidated an older approval. The stale attempt performed
  no remote mutation and retained its pending edit for a new preview.
- A sibling tab edited while a branch update was in flight. Only approved events
  were acknowledged; the new edit remained pending after reload and was published
  through a subsequent explicit approval.
- A fresh browser reconstructed the completed task and all three distinct notes.
  Independent raw event inspection found exactly five events with unique IDs.

The successful repository and the earlier failed synthetic test repositories were
deleted. Local reports stay under ignored `tmp/`; they are not release artifacts.

The first live publication exposed GitHub's canonical commit-message readback:
terminal newlines are omitted. Messages are now canonicalized before the preview
is sealed. A regression test checks exact approved text and canonical readback.

## Scope

This is live persistence, conflict and reload evidence using an in-memory
credential relay. The existing GitHub CLI credential remained in Node memory;
the browser held a synthetic sentinel. Requests were restricted to the newly
created private repository, safe Git API paths and non-force branch updates.
No direct browser credential/CORS claim follows from this test. Live AI provider
authentication, real GPU inference and OS browser launching remain unexecuted.

## Reproduce deliberately

Install Playwright Chromium and make Playwright available to Node, or configure
`PLAYWRIGHT_MODULE` and `PLAYWRIGHT_CHROMIUM_EXECUTABLE` for your installation.
Authenticate the GitHub CLI with your own account, then run from the checkout:

```powershell
node scripts/test-live-github.mjs --help
node scripts/test-live-github.mjs --allow-github-writes --cleanup
```

This creates real private repositories and commits. It never targets an existing
data repository. Cleanup requires the existing credential's deletion permission;
otherwise the report identifies the retained private synthetic repository.
Failed runs also retain their repository for inspection. The gate is opt-in and
does not run as part of ordinary CI.
