# Windows recovery evidence

Recovered on 2026-11-07 from the extracted Downloads handoff.

## Local restoration

- Windows `Environment.GetFolderPath('MyDocuments')` and the `User Shell Folders` registry both resolved to `C:\Users\desehgal\Documents`. No OneDrive redirection was active.
- Destination: `C:\Users\desehgal\Documents\personal\tanmay\worklog-test`.
- The destination was absent before recovery. The original failure occurred during `gh api user`, before the script's clone step. Its preceding temporary bundle verification does not create the checkout.
- The bundle SHA-256 matched `3b93809b3e1cdabf68870fc31e491e7e389c4c2b5b28ca057edb933a2fa162b0`.
- Executing the reviewed restore script with `-SkipPush` succeeded. The script verified the self-contained bundle, restored preserved history, and configured local identity `Devansh Sehgal <devanshsehgal02@gmail.com>`.

## Network diagnosis

The agent's restricted sandbox runs as a separate Windows account. Its authentication results did not establish the state of the user's keyring. GitHub checks were repeated under the actual Windows account before drawing conclusions or changing credentials.

The inherited process had HTTP_PROXY and HTTPS_PROXY pointing at a corporate proxy; NO_PROXY contained github.com. In the user's Windows context the corporate proxy hostname did not resolve. An earlier direct gh connection timed out, but a later direct Node HTTPS probe returned HTTP 200. Clearing proxy variables for one PowerShell process and setting NO_PROXY to `*` allowed installed gh 2.96.0 to authenticate as `Devansh-ops` with the existing keyring. No reauthentication was necessary. No global proxy, credential, or Git safe-directory configuration was changed.

For a future retry from an ordinary PowerShell window, process-only settings can be applied as follows, after confirming direct access remains appropriate for the network:

```powershell
Remove-Item Env:HTTP_PROXY,Env:HTTPS_PROXY,Env:ALL_PROXY -ErrorAction SilentlyContinue
$env:NO_PROXY = '*'
gh api --hostname github.com user --jq '{login: .login, type: .type}'
```

These settings end with that shell. Do not print tokens, run token-display commands, or put credentials in repository files.

## GitHub verification

The personal destination returned HTTP 404 before creation. Rerunning the reviewed restore script using the working direct connection created the private repository and pushed without force. GitHub API confirmed `isPrivate: true` and URL https://github.com/Devansh-ops/worklog-bend.

Immediately after restoration, local main and `repos/Devansh-ops/worklog-bend/git/ref/heads/main` both resolved to `2dc1e0849482d1fa821e1143545ef4a286523c0c`. Subsequent rebuild commits are recorded in Git history and the current status document.

Origin points to the new private repository. Upstream remains the original feature-reference repository with pushes disabled using `worklog-disabled://upstream`. Creation records remain in repository-local Git configuration so the restore script can safely identify its own destination.

Independent rebuild work uses sibling worktrees under `C:\Users\desehgal\Documents\temp`, with separate branches and explicit ownership. No unrelated local files were overwritten.
