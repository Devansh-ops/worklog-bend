# Verified Bend toolchain and bridge

## Exact source and host

The project compiler is Bend 2.0.40 at commit
`70607d7f740e3b3f4a1edc61069df8ab88491696` from
https://github.com/bendlang/bend. `toolchain/bend.lock.json` locks every compiler
source dependency and the guide by SHA-256. This replaces the handoff's untested
documentation reference. The installer retrieves only the listed files from that
immutable commit and checks bytes before writing. The wrapper checks them again
before every invocation.

Executed hosts: Windows x64, Node 25.8.1, Bun 1.3.10; Ubuntu WSL2 x86_64 with
Bun 1.3.10 and Lean 4.34.0. The standard checker runs natively on Windows.
The current upstream kernel builder expects Unix executable names and is
validated in WSL rather than assumed to support native Windows.

## Install and run on Windows

Install Bun **1.3.10**, or use that existing executable. The wrapper rejects a
different version. In PowerShell from the checkout:

```powershell
$env:BUN = "$HOME\.bun\bin\bun.exe"
node scripts/install-bend.mjs
node scripts/bend.mjs version
node scripts/bend.mjs --help
node scripts/bend.mjs guide
node scripts/bend.mjs base --types
node scripts/test-bend-toolchain.mjs
```

No moving branch, global compiler installation, package publication, or credential
is needed. Source, output and caches stay in ignored `.toolchain/`. Compilation
disables automatic `.env` loading, uses an empty Bun configuration, and sets the
compiler's documented telemetry opt-out. The wrapper does not patch compiler
source or change proof semantics. Downloads use Node HTTPS; a blocked network
fails installation explicitly. See `WINDOWS_RECOVERY.md` for this machine's
process-only GitHub proxy workaround.

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
The complete reproducible verdict helper and CI gate are tracked separately;
the integration status decides Phase 1 acceptance.

The bridge smoke compiles `toolchain/smoke/bridge.bend` into
`.toolchain/bridge.mjs` and imports that exact output. It verifies Unicode,
booleans, nested constructors, lists, wraparound, typed error alternatives and
mutation ownership. Its evidence JSON records the generated module's SHA-256.
The main worktree separately owns the real static-HTTP Chromium browser harness.

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
