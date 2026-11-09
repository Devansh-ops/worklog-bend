# Third-party notices

## Worklog

Source: https://github.com/tanmayagrawal21/worklog

The preserved upstream application and its derivatives carry the MIT license in
LICENSE, including Copyright (c) 2026 Tanmay Agrawal. Worklog Bend adds domain
implementation, proofs, adapters, fixes and tests; its history records the changes.

## Bend compiler, Base library and emitted helpers

Source: https://github.com/bendlang/bend

Pinned revision: `70607d7f740e3b3f4a1edc61069df8ab88491696` (Bend 2.0.40).

Copyright 2026 HigherOrderCO.

The exact revision's LICENSE is Apache License 2.0. A complete copy is retained
in `licenses/Bend-Apache-2.0.txt`.

The generated files `js/generated/core.mjs`, `reports.mjs`, `views.mjs`,
`publication.mjs` and `planning.mjs` contain application code together with
translated Bend Base definitions and compiler-emitted runtime helpers.
These are generated translations of the pinned source and include this project's
application definitions; they are not verbatim upstream source files. Their
generated-file banners identify this origin and the retained license.

The compiler source and downloaded Bun/Lean executables are development tools
kept outside tracked release files under ignored `.toolchain/` directories.
They are not bundled in the application distribution.

These notices retain the respective upstream terms; the root MIT license does
not replace third-party license terms.
