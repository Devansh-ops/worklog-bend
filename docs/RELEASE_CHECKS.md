# Release boundary evidence

Checked 2026-11-08 on Windows x64 with Node 25.8.1 and Chromium 149.0.7827.55 through Playwright 1.61.0. All test content and credentials are synthetic. These are host and browser checks, not Bend proof guarantees.

## Credential vault and static subpaths

`node test/browser-vault.mjs` serves actual application files at `/project/` and uses a new browser context. It executes real browser WebCrypto rather than a crypto stub. Checked behavior:

- Locked save uses AES-GCM with a 256-bit key derived by PBKDF2-SHA256 at 600,000 iterations, a random 16-byte salt and a random 12-byte IV. Plaintext synthetic tokens are absent from the stored ciphertext record.
- Correct passphrase unlocks; missing or wrong passphrase returns no credentials. Changed ciphertext fails authentication. Wrong-passphrase attempts preserve the saved record.
- A second save produces a fresh salt and IV. A compatible older encrypted record using its stored 120,000-iteration count unlocks correctly. Encrypted and plain legacy `hfToken` records migrate to the provider-specific shape.
- Forget removes the local record, revokes the active adapter token and prepared-request session, clears unsaved credential inputs, and cannot resurrect typed keys on a later Save. No real user credentials are used.
- With WebGPU deliberately unavailable, provider validation and explicit model preload return a clear error before runtime or model downloads. No loaded model is reported.
- The actual app renders at 1440px and 400px beneath `/project/`; all five generated Bend modules load and execute as browser ES modules under that subpath. No compiler or backend is involved. Page errors and requests outside the loopback origin cause test failure.

The test can target another checkout with `WORKLOG_APP_ROOT`. During independent development it passed against the parent's current integration checkout as well as the local artifact set. The test does not claim a real GPU model ran, an authenticated provider accepted a request, or a browser-specific operating-system credential store was tested. Per-load unlock dialogs and their read-only skip flow belong to broader UI acceptance.

## Local CLI and package

`node test/release-check.mjs` runs the actual Node CLI and loopback HTTP server. It checks invalid flags and missing host values, help/version, generated-module JavaScript MIME and HEAD behavior, malformed/encoded traversal paths, unsupported methods, port-conflict fallback, SIGTERM termination and closed listening port. It also runs `npm --loglevel verbose pack --dry-run --json` with a task-local npm cache, verifies the MIT license and generated modules are packaged, and excludes compiler caches, installed modules and token files. It publishes nothing.

The tests reproduced two reference faults before correction: `--porthole=123` started a server because parsing accepted flag prefixes, and a Windows directory junction inside the package exposed an outside-root synthetic file with HTTP 200. Exact flag matching and filesystem realpath confinement now reject those cases. An in-root path resolving outside the package returns 404. The optional JavaScriptCore virtual filesystem stub now models `realpath`; that stub is not evidence for the actual filesystem check.

The original `node test/cli-real-smoke.mjs` also passes after these changes. Default operating-system browser launching is not executed by the automated CLI checks; they deliberately use `--no-open`. The confinement check is about ordinary filesystem link resolution, not a claim of race-free serving against a hostile local process swapping files during a request.

To use an existing Playwright installation, set `PLAYWRIGHT_MODULE` to its `index.mjs`; `PLAYWRIGHT_CHROMIUM_EXECUTABLE` can name the matching installed browser. Otherwise install the exact Playwright version recorded in the toolchain lock and its Chromium browser, then run the scripts normally.

## Portable terminal setup

`node test/setup-cli.mjs` passes eight groups using fake gh and isolated real Git
repositories. It checks dry run/Cancel, exact approved bytes and message, private
default/public choice, empty and existing README repositories, unindexed partial
history refusal, peer advances and failed pushes. The Node entry point is
`scripts/setup.mjs`; `scripts/setup.sh` is a thin compatible wrapper. Both ship
in the package. No real repository is created by these tests.
