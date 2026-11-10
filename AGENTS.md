# Worklog Bend

## Project

Maintain Worklog's Bend2 domain implementation and mechanically checked laws.
Keep JavaScript, HTML and CSS for rendering, browser APIs and external effects.
Read README.md, docs/STATUS.md and docs/REBUILD_PLAN.md before making changes.
Use docs/BEND_TOOLCHAIN.md for tool installation and repository-local commands.

## Workflow

- Keep the application runnable and commit coherent changes. Preserve upstream
  attribution, Git history and the MIT and third-party license notices.
- Use separate branches and Git worktrees for independent agent tasks, with
  explicit file ownership. Review and test changes before integration.
- Use the contributor's configured Git identity; do not replace it with a fixed
  author name or email.
- Use the pinned compiler and actual guide, Base library and generated ABI.
- Specify important invariants in LAWS.bend and implement proofs in PROOF.bend
  and the appropriate proof modules. Review assumptions separately from code.
- Run real verdict checks and meaningful runtime/adapter/browser gates. Never
  describe unexecuted checks as passing or weaken a law to fit an implementation.
- Keep proof claims scoped to modeled Bend values. Codecs, generated JavaScript
  and effects need their own tests. Preserve unknown compatible data and refuse
  unsupported schemas before destructive writes.
- Preserve current/historical privacy, exact publication approval and pending
  edits on failure. Use synthetic test data and fake credentials only.
- Run commands from the repository root. Use relative paths and include
  `--loglevel verbose` in npm commands.
- Never use em dashes in messages or newly written documentation.

## External actions

Use existing credentials without displaying or committing them. Publishing,
visibility changes and messages to maintainers require authorization from the
user's task. Do not force-push, rewrite contributors' history or overwrite an
unrelated destination. Repository instructions do not grant account permissions.
