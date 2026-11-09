# Public release preparation

Reviewed 2026-11-09, starting from `b414524`.

## Source release

The application is runnable and has passed the recorded domain, adapter,
browser, clean-checkout and hosted CI gates. An experimental public source
release is a reasonable next step within the limits in STATUS.md.

The README now describes this implementation and its real commands. No hosted
demo is claimed: GitHub reported `has_pages: false`, with no homepage configured.
Deploy and verify the actual site before adding its public app/demo links.

Gitleaks 8.30.1 scanned all 102 commits reachable from the starting main branch
with fully redacted output and reported zero findings. No tracked work-data
directory or credential files were found. This is a targeted credential check,
not an exhaustive security audit or a guarantee that no sensitive information
exists anywhere.

Preserved history does contain personal details: author email, local Windows
username/paths and recovery/network context. These appear in STATUS.md,
WINDOWS_RECOVERY.md, Windows handoff material and proof/toolchain instructions.
Decide whether that disclosure is acceptable before changing visibility. Editing
only current files does not remove their earlier versions or commit metadata.
No history was rewritten or repository visibility changed during this review.

Upstream MIT attribution remains in LICENSE. The exact pinned Bend source uses
Apache-2.0; THIRD_PARTY_NOTICES.md and licenses/Bend-Apache-2.0.txt retain that
notice for translated Base/runtime portions of generated assets. Package contents
include both notices and the license copy.

## Contacting upstream

The upstream repository currently has issues enabled and Discussions disabled.
The account Devansh-ops already has issues #2, #4, #5, #6, #7, #8, #9 and #10
covering privacy, test and replay/concurrency defects. Check and reuse those
threads rather than filing duplicates.

For announcing this separate Bend-based implementation, a short issue asking
whether the maintainer is interested in a link or small backports is preferable
to a pull request replacing their architecture. Keep the full port in this repo.
Offer individual upstream-compatible JavaScript fixes with focused regression
tests as separate PRs when useful. This is a standalone repository, so create
a fork of upstream for those backport PRs. Reconfirm current issue state before posting.
No issue, comment or PR was sent by this review.

Suggested announcement, after the source is public:

> I built an independent Bend2-based derivative of Worklog and preserved your
> attribution and MIT license. It keeps browser/effect code in JavaScript and
> adds checked domain laws plus adapter/browser tests. Source and proof scope:
> https://github.com/Devansh-ops/worklog-bend. Would you be interested in a link
> to the port or small, separately reviewed JavaScript backports for the existing
> issues? I can keep the Bend migration in the derivative repository.

## Further work

- Verify a real static deployment before presenting a hosted demo.
- Treat initial public release as experimental. Live provider authentication/CORS,
  GPU inference and OS browser launching remain unexecuted integration checks.
- A safe explicit journal-compaction design would address ongoing local storage
  growth. Existing append-only history retention is documented.
- Consider contributor/security-reporting guidance and a preview release tag
  when ready to maintain an external release. No package has been published.
