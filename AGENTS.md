# Worklog Bend

## Authorized objective

Recreate the full Worklog application using Bend2 for the domain implementation
and mechanically checked laws. Keep JavaScript, HTML, and CSS where they are
needed for browser APIs, rendering, and external integrations. This is a full
rebuild, not just a proof of concept. The existing upstream implementation is a
reference for features and intended behavior, not an infallible specification.

## Current state

Read `docs/STATUS.md` and `docs/REBUILD_PLAN.md` before making changes. At handoff,
the source is the original JavaScript application and the Bend rebuild has not
started. Never describe a law or implementation as checked until the actual Bend
toolchain has accepted it.

## Workflow

- Work phase by phase, keeping each phase runnable and committing coherent work.
- Use sub-agents in separate Git worktrees for independent tasks. Give each agent
  a branch and explicit file ownership; integrate only reviewed, tested changes.
- Configure repository-local Git author identity as `Devansh Sehgal` and
  `devanshsehgal02@gmail.com`. Preserve upstream history and the MIT license.
- Use meaningful conventional commit messages and describe validation honestly.
- Do not rewrite upstream or other contributors' commits.
- Use `bend guide` and verify current syntax against the pinned compiler.
- Specify important invariants in `LAWS.bend`; prove them in `PROOF.bend`.
- Run `bend PROOF.bend --verdict` when supported by the pinned compiler, as well as
  behavior, adapter, integration, and browser tests appropriate to the phase.
- Review changes to laws separately from implementations. Do not weaken a law
  merely to make a proof pass. Document changed product requirements explicitly.
- Keep proof guarantees scoped to the modeled Bend semantics. Test JavaScript
  adapters, malformed inputs, browser effects, and generated code separately.
- Preserve existing data compatibility. Reject unsupported future schemas before
  any destructive write, and make migrations explicit and reviewable.
- Use synthetic data and fake credentials in tests. Do not send real notes or
  credentials to AI providers or publish them to GitHub.
- Include `--loglevel verbose` in npm commands.
- Never use em dashes in messages or newly written documentation.

## GitHub

The destination repository is `worklog-bend` under the user's authenticated
personal GitHub account. Default to private. The user has authorized creation
and pushing this repository. Use the local authenticated `gh`; never request
that tokens be pasted into chat or written into source files. Do not overwrite
an existing unrelated repository or force-push.
