# Public release guide

## Verify the checkout

Install the pinned developer tools using BEND_TOOLCHAIN.md, then run these
commands from the repository root:

```sh
npm --loglevel verbose run check:build
npm --loglevel verbose run test:proof
npm --loglevel verbose test
npm --loglevel verbose run test:browser:all
```

Review STATUS.md, FEATURE_MATRIX.md and LAW_REVIEW.md for the actual tested scope.
Keep the application source separate from work-data repositories. Check tracked
files, Git history and build logs for information intended to remain private
before publishing. Current-file edits do not alter earlier commits.

Retain LICENSE, THIRD_PARTY_NOTICES.md and licenses/Bend-Apache-2.0.txt in source
and packaged distributions. Generated asset notices are maintained by the build.

## Hosted demo

The public app is https://devansh-ops.github.io/worklog-bend/ and the temporary
demo is https://devansh-ops.github.io/worklog-bend/?demo=1.

GitHub Pages publishes `main` at the repository root, matching upstream's branch
deployment layout. `.nojekyll` keeps the reviewed static files unchanged. HTML,
CSS, JavaScript, generated modules and license notices deploy together.

After a deployment completes, verify its HTTPS assets and browser routes from
the corresponding checkout (with Playwright installed):

```sh
node scripts/test-hosted-site.mjs
```

An optional first argument selects another project-root HTTPS URL. The check
compares all generated hashes to the local manifest, then exercises the normal
welcome page and ephemeral demo in fresh wide/narrow browser contexts. No tokens
or work-data repository are required. Run this separately from pre-deployment
CI so a previous site version cannot create a deployment-order race.

## Contacting upstream

For announcing the independent Bend-based implementation, first check upstream's
contribution guidance and existing issues. A concise announcement asking about
interest in a link or backports is preferable to a wholesale architecture PR.
Offer focused upstream-compatible fixes with regression tests separately. This
repository is standalone; use a fork of upstream for cross-repository backport PRs.

## Further work

- Keep initial releases experimental within the documented integration limits.
  Live provider authentication/CORS, GPU inference and OS browser launching have
  not been exercised.
- Design safe explicit journal compaction to address local storage growth.
  Append-only event retention is documented in PENDING_RECOVERY.md.
- Add contributor/security-reporting guidance and a preview release tag when
  maintaining an external release. No npm package has been published.
