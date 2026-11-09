# Restore Worklog Bend on Windows

Historical handoff instructions. Restoration and the rebuild have since completed;
see STATUS.md for current results and WINDOWS_RECOVERY.md for the recovery record.
The statements below describe the original handoff, before the Bend work.

The handoff contains the original Worklog source, preserved Git history, and
instructions for a full Bend rebuild. The Bend implementation and proofs have
not been written or checked. Start with `docs/STATUS.md` after restoration.

The remote session cannot write to your Windows Documents folder or use your
machine's GitHub login. Run this handoff on your Windows machine to complete
those steps.

## Restore and push

1. Extract the handoff ZIP into a temporary folder. Keep
   `Restore-WorklogBend.ps1` and `worklog-bend.bundle` beside each other.
2. Open PowerShell in that folder. Windows PowerShell 5.1 and PowerShell 7 are
   supported by the script's syntax. Git and GitHub CLI (`gh`) must be installed
   and available on `PATH`.
3. Check your existing GitHub login, or sign in through the local CLI:

   ```powershell
   gh auth status --hostname github.com
   # Only if sign-in is needed:
   gh auth login --hostname github.com
   ```

4. Run:

   ```powershell
   .\Restore-WorklogBend.ps1
   ```

The default destination is your Windows Documents folder plus
`personal\tanmay\worklog-test`. A redirected Documents folder is respected.
The script reads the authenticated personal GitHub account from `gh api user`,
creates a private `worklog-bend` repository under that account, and pushes `main`.
It keeps the original commits and MIT license. The new checkout uses this
repository-local commit identity:

```text
Devansh Sehgal <devanshsehgal02@gmail.com>
```

The bundle path is removed from `origin`. The GitHub destination becomes
`origin`, and `upstream` points to
`https://github.com/tanmayagrawal21/worklog.git`. Upstream pushes are disabled
with a blocked Git transport. The script uses the local `gh` credential helper
for its push without changing global Git configuration or displaying tokens.

If Windows marks the downloaded script as blocked, review it and use
`Unblock-File -LiteralPath .\Restore-WorklogBend.ps1`. If your execution policy
still blocks it, this command requests an exception for that PowerShell process
only, subject to your organization's policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Restore-WorklogBend.ps1
```

No persistent execution-policy change is required. Do not paste GitHub tokens
into chat or source files.

## Restore without GitHub access

```powershell
.\Restore-WorklogBend.ps1 -SkipPush
```

This verifies and clones the bundle, configures the local identity and upstream,
and leaves GitHub untouched. It requires Git but does not require `gh` or a
network connection. Rerun the same script without `-SkipPush` to create the
private repository and push.

For explicit paths, including paths with spaces:

```powershell
.\Restore-WorklogBend.ps1 -BundlePath 'C:\Downloads\worklog-bend.bundle' -Destination 'C:\Users\YourName\Documents\personal\tanmay\worklog-test'
```

When running the copy under `scripts` inside the project, the script also checks
for `worklog-bend.bundle` in the project root if no explicit `-BundlePath` is
provided.

## Safe stops and retrying

- An existing nonempty destination is accepted only when this script previously
  restored it from the same bundle. Other folders, junctions, and symbolic links
  are rejected. Nothing in an unrelated destination is overwritten.
- An existing GitHub `worklog-bend` repository is accepted only when this checkout
  records that the script created that exact private repository. A matching name
  alone is insufficient. Review an existing repository before deciding how to
  proceed; the script does not delete it or force-push.
- A marked checkout on `main` can be reused after an ordinary network or push
  failure. Existing commits and uncommitted edits are preserved. A push rejected
  because GitHub has newer commits requires normal Git reconciliation.
- An interrupted clone, or an interruption between GitHub creation and saving
  its local creation record, may require manual review. The script stops rather
  than guessing. Keep the partial checkout and inspect its state before moving
  it aside or choosing another empty destination.

After a successful push, open Codex in the restored folder, read `AGENTS.md`,
`docs/STATUS.md`, and `docs/REBUILD_PLAN.md`, then continue Phase 1 and the full
rebuild. This handoff does not install Bend or claim any law has been checked.

The handoff script was reviewed statically in the remote Linux session. A
Windows PowerShell runtime and authenticated GitHub push were unavailable
there, so the complete Windows restore and push have not been executed.
