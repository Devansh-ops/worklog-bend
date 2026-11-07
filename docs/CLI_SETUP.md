# Exact terminal setup plans

`node scripts/setup.mjs` is the portable terminal route. `scripts/setup.sh` is a compatibility entry point that invokes the same Node program. It needs Node 18 or later, Git, and an existing authenticated GitHub CLI session. It does not display or export tokens, change global Git configuration, publish a package, or activate hosting.

```powershell
node scripts/setup.mjs --repo your-account/worklog-data --dry-run
node scripts/setup.mjs --repo your-account/worklog-data
```

New repositories default to private and must belong to the authenticated personal account. `--public` explicitly selects public creation; an existing repository keeps its inspected visibility. The app location defaults to the local CLI's `http://127.0.0.1:8765/`; supply `--app-url https://your-host/project/` for a hosted copy. `--no-examples` omits synthetic starter tasks. The independent scaffolder also works with ordinary Node invocation, with or without a leading argument separator.

The helper distinguishes GitHub's HTTP 404 from authentication, network, and other inspection failures. It clones an existing destination and pins its default branch before preparing the preview. Any existing manifest, board, or historical log source prevents setup, including unindexed old month files. Existing unrelated files and README are preserved. Scaffold path parents must be ordinary directories.

Effective fetch and push URLs must equal the inspected GitHub destination, including after approval. Unexpected Git URL rewrites or push URLs are refused without printing their potentially credential-bearing values. Child Git commands clear inherited repository/index/object-directory overrides so their plumbing stays in the owned checkout. Existing GitHub credentials remain with gh.

The complete immutable plan includes destination, branch, base revision, visibility, message, retained paths, and exact file contents. It is generated once and printed before approval. Cancel and `--dry-run` perform no remote writes. `--yes` is an explicit noninteractive approval of that printed plan. The shared generated Bend publication gate checks complete plan identity.

After approval the helper writes the exact bytes through Git's blob/index/tree/commit plumbing. Working-tree filters, line-ending attributes, and commit hooks cannot silently rewrite the approved payload or message. The new commit has exactly the inspected parent, or no parent for a root commit. Ordinary `git push` refuses a peer advance; the helper does not rebase or force-push to make it succeed.

If repository creation, local completion, or push fails after writing begins, the checkout and completed commit remain in the reported local directory. Inspect the remote result before retrying after an ambiguous network failure. No recovery command automatically overwrites an existing repository. Successful setup, Cancel and dry run remove only the helper's verified owned temporary directory. Unrelated paths are never cleanup targets.

## Executed checks

`node test/setup-cli.mjs` uses fake gh responses and actual isolated local bare Git repositories. No GitHub request or write occurs. Its eight groups check strict arguments, actual Node scaffolding and Bash compatibility, dry run/Cancel and immutable exact previews, private/public creation, exact committed bytes/message, new and existing-empty root commits, personal-owner enforcement, existing README/attributes, historical partial-log refusal, peer-conflict preservation, and network-failure recovery. The attribute fixture deliberately requests CRLF conversion; the committed blobs still equal the reviewed UTF-8 bytes.

The helper's real `--help` and Bash compatibility entry point were executed on Windows. Live data-repository creation was not performed as part of these tests. No claim is made against malicious concurrent local filesystem replacement or compromise of the installed Git/GitHub CLI. Those tools and effects are outside the Bend proof model.
