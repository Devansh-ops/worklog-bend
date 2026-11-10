# Verified Bend toolchain and bridge

## Exact source and host

The project compiler is Bend 2.0.40 at commit
`70607d7f740e3b3f4a1edc61069df8ab88491696` from
https://github.com/bendlang/bend. `toolchain/bend.lock.json` locks every compiler
source dependency and the guide by SHA-256. The installer retrieves only the listed files from that
immutable commit and checks bytes before writing. The wrapper checks them again
before every invocation.

Executed hosts: Windows x64, Node 25.8.1, Bun 1.3.10; Ubuntu WSL2 x86_64 with
Bun 1.3.10 and Lean 4.34.0. The single-file standard checker runs natively on
Windows. **Full multi-module builds must use WSL**: this pin incorrectly resolves
relative imports on native Windows, losing the drive and importing subdirectory.
This was reproduced after the single-file smoke. Compiler source is unpatched.
The current upstream kernel builder expects Unix executable names and is
validated in WSL rather than assumed to support native Windows.

## Install and run

Run all commands from the repository root. Prerequisites are Node.js and, for
full compiler/proof checks, Linux or WSL Ubuntu with Python 3.11+, libzstd and tar.
The installers download the exact locked compiler and proof-tool archives.

Windows PowerShell:

```powershell
node scripts/install-bend.mjs
node scripts/install-proof-tools.mjs
wsl --distribution Ubuntu --exec sh scripts/test-bend-verdict.sh
npm --loglevel verbose run check:build
npm --loglevel verbose run test:proof
```

WSL inherits the current checkout directory; no drive or user path is embedded.
On Linux, run the same installers and replace the WSL invocation with:

```sh
sh scripts/test-bend-verdict.sh
```

Optional native single-file smoke checks require Bun 1.3.10 on PATH, or the BUN
environment variable pointing to that version's executable:

```sh
node scripts/bend.mjs version
node scripts/bend.mjs guide
node scripts/bend.mjs base --types
node scripts/test-bend-toolchain.mjs
```

Full imported modules and verdicts still use Linux/WSL. No sibling checkout,
global compiler installation, package publication or credentials are required.
Compiler sources, generated output and wrapper metadata stay in ignored
`.toolchain/`. Downloads use Node HTTPS and fail explicitly if unavailable.
Compilation disables automatic `.env` loading, uses an empty Bun configuration
and sets the compiler's telemetry opt-out without changing proof semantics.

## Actual checks and scope

The compiler's help, full guide and Base type listing were executed and read.
`scripts/test-bend-toolchain.mjs` runs a small true law, a false equality law,
an unfinished law and an unguarded recursive function. Expected exits are
respectively 0, 1, 1, 1. Rejection must contain a checker diagnostic, so missing
executables or crashes do not count as negative-test success. The true law is
identity of any U32, with a real witness and no unsafe assumptions.

Standard checks and actual generated module execution passed on Windows.
The real `--verdict` path was also executed in WSL with Lean 4.34.0 and accepted
the true fixture using the compiled BendTT kernel. It is a separate check;
standard checker success alone does not establish a kernel verdict. An initial
native Windows verdict attempt failed explicitly because Lean was missing.
The complete standard and verdict harness subsequently passed with the same
expected exits, followed by the emitted JavaScript ABI checks. Exact generated
bridge SHA-256 was `4e6491828542d86e07075ff8b43c2daa91f6bfdcbe92d6a3e710602aba575e41`.
CI is configured in `.github/workflows/bend-toolchain.yml`; a local execution
does not imply that a hosted CI run has completed.

The bridge smoke compiles `toolchain/smoke/bridge.bend` into
`.toolchain/bridge.mjs` and imports that exact output. It verifies Unicode,
booleans, nested constructors, lists, wraparound, typed error alternatives and
mutation ownership. Its evidence JSON records the generated module's SHA-256.
The repository includes the real static-HTTP Chromium browser harness.

## Inspected generated ABI

The `.mjs` module has one **default export**, an object of curried-or-multiargument
functions. No compiler or Bun dependency is required by its pure runtime output.

| Bend value | Actual JavaScript representation |
| --- | --- |
| `Bool` | Native `true` or `false`. |
| `U32` | Number; arithmetic wraps modulo 2^32. `wrap(4294967295)` is 0. |
| `String` | Native string, including nested record fields. Export wrappers normalize unpaired UTF-16 surrogates to U+FFFD. |
| `Task{id, private, count}` | `{ $: 'Task', id, private, count }`. |
| `List<U32>` | `{ $: 'Con', head, tail }` ending in `{ $: 'Nil' }`. |
| Typed domain error | A tagged alternative, e.g. `{ $: 'Rejected', reason: 'invalid input' }`; no host exception is implied. |
| `Array<U32>` | Mutable host Array. `overwrite(array)` returns the same object and mutates it. |

The generated module does not validate untrusted host values. For example,
`wrap(-1)` also returns 0. Codecs must reject wrong types, out-of-range numbers,
invalid constructor shapes and cyclic lists before passing them to Bend. A codec
must copy mutable arrays it owns before transferring them to a linear Bend
function; the smoke confirms a copied input protects the original array.
Do not assume Bend's internal validity proofs validate arbitrary JSON.

## Syntax and proof constraints verified for this pin

Import the built-in library with `import Base`. Reusable records and variants
use `type Name is Data:` with constructors underneath. Strings, Bool and U32 are
Base types. There is no `if` syntax; match `True{}` and `False{}`. A match examines
a parameter or pattern-bound variable; to inspect a computed value, pass it to
a helper. Definitions are ordered, with no mutual recursion. Recursive calls
must structurally decrease an input, and a repeated Data input requires `+` on
its binder. Arithmetic needs explicit type annotation, e.g. `(x + 1 : U32)`.

`law identity:` followed by `for x: U32` and `{x == x : U32}` is discharged by
`def identity(x):` with `{==}`. App laws still belong in `LAWS.bend` with proofs
in `PROOF.bend`; these small fixtures validate tooling only. No application
privacy, merge, checkpoint, publication or compatibility law has been proved by
these smoke checks.

## Reproduce the independent kernel check

The pinned Linux x64 proof-tool archives total approximately 620 MB compressed.
The installer verifies both SHA-256 values, including before extraction. It
needs Ubuntu's Python 3.11 or later, system libzstd, and tar. It installs into
`$HOME/.cache/worklog-bend-proof` in Ubuntu; set `WORKLOG_PROOF_CACHE` to choose
another persistent dedicated cache. No apt, pip, elan, or global PATH edit is
required. The persistent cache avoids re-extracting the tools on every run.

From the Windows checkout:

```powershell
node scripts/install-proof-tools.mjs
wsl --distribution Ubuntu --exec sh scripts/test-bend-verdict.sh
```

On a Linux checkout, execute
`node scripts/install-bend.mjs`, `node scripts/install-proof-tools.mjs`, then
`sh scripts/test-bend-verdict.sh`. The helper uses the locked Linux Bun binary to
run the JavaScript harness, including compilation, so no separate Linux Node
installation is needed for the proof invocation. The wrapper still validates
the Bun version and every compiler source byte. The exact Lean version is
checked by both bootstrap and the upstream kernel builder.

The compiler wrapper resolves input files from the caller's working directory.
Run from the repository root and use this checkout's `scripts/bend-linux.sh`.
Its compiler metadata is resolved relative to its own script location. The
optional environment overrides do not require another checkout.

The real multi-module `toolchain/smoke/imported.bend` fixture both passes
`--verdict` and compiles to a callable JavaScript export under WSL. The native
smoke explicitly skips this unsupported route and records that limitation.
For full project checks from a Linux/WSL checkout directory, use:

```sh
sh scripts/bend-linux.sh PROOF.bend --verdict
sh scripts/bend-linux.sh bend/Core.bend -o .toolchain/core.mjs
```


For an individual module from Windows PowerShell, use the same repository-relative
paths:

```powershell
wsl --distribution Ubuntu --exec sh scripts/bend-linux.sh proof/Order.bend --verdict
```

## Browser test dependencies

After the compiler smoke above has generated `.toolchain/bridge.mjs`, install
the locked Playwright version into this checkout and its browser:

```powershell
npm --loglevel verbose install --no-save --package-lock=false playwright@1.61.0
npm --loglevel verbose exec -- playwright install chromium
npm --loglevel verbose run test:browser:all
```

On Linux, use `npm --loglevel verbose exec -- playwright install --with-deps chromium`
when system browser libraries also need installation. CI includes that route.
Tests use this checkout and its local Playwright installation by default.
`PLAYWRIGHT_MODULE`, `PLAYWRIGHT_CHROMIUM_EXECUTABLE` and `WORKLOG_APP_ROOT` are
optional overrides for explicitly selected installations or checkouts.
