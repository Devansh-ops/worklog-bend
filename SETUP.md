# Setup

Two things to decide: **where your log lives** (a git repo you own) and **how much AI you want**
(possibly none). The rebuilt app runs locally with Node, or from your own static host.

---

## 1. Get a GitHub token

The browser adapter calls GitHub's REST API using a personal access token.
The optional terminal setup uses your existing authenticated gh session.

**If your data repo already exists** — a [fine-grained token][fg] is the tighter option:

1. Open <https://github.com/settings/personal-access-tokens/new>
2. Resource owner: you. Repository access: **Only select repositories** → your log repo.
3. Permissions → Repository permissions → **Contents: Read and write**.
4. Set an expiry you're happy to renew. Generate, and copy the token.

**If you want the browser to create the data repository**, use a token with the
required creation permissions. GitHub documents fine-grained Administration or
Repository creation write permission, or classic `repo` scope for private creation.
See the [current GitHub endpoint documentation](https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user).
Creating it first with the terminal flow below lets you then restrict browser
access to that one repository.

Either token goes into Settings in the app. It is stored in `localStorage` on that browser only,
never committed, and never sent anywhere except `api.github.com`.

[fg]: https://github.com/settings/personal-access-tokens/new
[cl]: https://github.com/settings/tokens/new?scopes=repo

## 2. Point the app at your repo

In this checkout, run `npm --loglevel verbose start` and open the displayed local
URL. For an ephemeral preview, run `npm --loglevel verbose start -- --demo`.
The upstream public demo runs the original application. The rebuilt app's
first-run wizard asks for:

- **Data repo** — `your-username/worklog-data`, or any repo you like. It can be one you already use.
- **Visibility**, if it doesn't exist yet — **Private** is the recommended default. Public means
  anyone can read your task titles and notes (and the app can then read it with no token at all,
  which is handy for a read-only view on a machine you don't want to put a token on).
- Whether to seed **three example tasks** so the board isn't empty.

Then it shows you the exact files it is about to commit, and commits nothing until you say yes.

If you'd rather create and seed the repo from a terminal, see [Option B](#option-b-gh-cli) below.

## 3. Choose an AI tier

Settings → AI. Four options; the default is the first.

**No AI.** The board and the changelog, nothing sent anywhere. Everything except the summary and
brain-dump panes works exactly the same.

**On my machine.** Task context stays local when the configured endpoint is on this machine. Remote overrides require disclosure and consent.

- *In this browser (WebGPU)* — downloads an open model into the browser and runs it on your GPU.
  Needs a WebGPU-capable browser and enough disk for the selected model. Runtime
  capability checks report unavailable devices. See STATUS.md for executed
  checks; real GPU inference was not exercised on this machine.
- *Ollama* — `ollama serve`, then set the endpoint to `http://localhost:11434/v1`. Ollama needs to
  allow the exact origin printed by the local app server, or your own static
  deployment origin. Configure the server for that origin before calling it.
- *llama.cpp server* / *LM Studio* — same idea; both expose an OpenAI-compatible `/v1`. Start them
  with CORS enabled (`llama-server --host 127.0.0.1 ... ` behind a proxy that adds the header, or
  LM Studio's "Enable CORS" toggle).

**Open models in the cloud.** A Hugging Face token from
<https://huggingface.co/settings/tokens>. The model list is read live from HF's catalogue. Free-tier
inference credits are small; a 402 from HF means you've used them up, and the app says so plainly.

**A commercial or custom API.** OpenAI, Anthropic, Google, or OpenRouter — pick the provider, paste
its key, choose a model. For anything else that speaks the OpenAI chat-completions format
(a company gateway, LiteLLM, vLLM, a proxy), choose **Custom endpoint** and give it the base URL,
the key, and the model name. Requests degrade gracefully: if the endpoint rejects
`response_format` or a sampling parameter like `temperature`, the app retries without it rather than
failing.

Keys are stored per provider, so switching back and forth doesn't make you re-paste them.

## 4. Optional: lock your tokens with a passphrase

Settings → Security. Without it, tokens sit in plaintext `localStorage` — fine on a machine only you
use, less fine on a shared one. With it, they're encrypted at rest (PBKDF2-SHA256, 600k iterations →
AES-GCM) and you're prompted once per session. Skipping the prompt gives you a read-only board.

There is no recovery: forget the passphrase and you re-enter your tokens.

---

## Option B: gh CLI

If you prefer to create the repo yourself, or want to script it for a team:

```powershell
node scripts/setup.mjs                          # private repo named <you>/worklog-data
node scripts/setup.mjs --repo me/journal        # a name you pick
node scripts/setup.mjs --public                 # public instead
node scripts/setup.mjs --no-examples            # skip the three example tasks
node scripts/setup.mjs --dry-run                # print the plan and every file, write nothing
node scripts/setup.mjs --yes                    # skip the confirmation prompt
```

It needs the [`gh` CLI](https://cli.github.com) authenticated (`gh auth login`), creates the repo if
it's missing, and commits the same starter files the in-app wizard would — literally the same code
renders them. Both paths have exact-plan regression checks. Like the app, it shows you the plan and waits for a `y`
before creating anything. If the repo already holds a log it stops rather than guessing at a merge;
open the app and point it at the repo instead. It never touches tokens — you still paste one into
the app.

## Running and hosting this rebuild

From this checkout:

```powershell
npm --loglevel verbose start
npm --loglevel verbose start -- --demo --no-open
```

The CLI serves this checkout's files, prints its local URL and opens a browser
unless `--no-open` is supplied. `--port` and `--host` select the listener.
The npm name `work-log` is retained for compatibility; this rebuild has not been
published to npm. Use this checkout to run its actual generated Bend modules.

The shipped HTML, CSS, JavaScript and generated modules can also be served by a
static host. Keep their relative directory layout. Subpath execution is tested
at `/project/`. No hosted deployment was published as part of this recovery.
The data repository is separate from the application repository.

For a local model, configure its server to allow the exact app origin. If a
browser blocks the request, inspect the endpoint error and use the local app
with the server's matching origin configuration.

## Using it from more than one machine

Point both at the same data repo and paste a token into each. Edits stage locally and merge by event
id on push, so two machines that both went a while without syncing converge rather than clobbering
each other — that case has a test. What doesn't sync is your token or your AI keys: those are
per-browser by design.

## Troubleshooting

**"GitHub refused the write (403)"** — the token lacks *Contents: Read and write* on that repo, or
it's fine-grained and that repo isn't in its selected list.

**The wizard cannot create the repository:** verify repository-creation permission
using the GitHub documentation linked above, or create it with the authenticated
terminal setup and then grant the browser token access to that repository.

**"404 reading data/manifest.json"** on a repo you know exists — usually a private repo with no
token, or a token without access to it. A public repo needs no token; a private one always does.

**Nothing loads and the console mentions modules** — you opened `index.html` as a `file://` URL.
Serve it over HTTP (`python3 -m http.server 8000`).

**Changes to a public data repo take a few minutes to appear** — reads of public repos go through
`raw.githubusercontent.com`, which caches for about five minutes. Adding a token switches to the
API, which doesn't.

**A local model endpoint gives a CORS error** — the server needs to allow the app's origin; see the
Ollama and LM Studio notes above.

**The board looks like it's missing old work** — it isn't. Boot reads a snapshot plus recent months
so startup stays fast; the wiki's Days view has *Load 2025* / *Load everything* buttons, and tasks
whose older notes weren't downloaded say so with a button to fetch them.

**An "Upgrade layout" banner appears** — your repo was written by an earlier version that put every
month in one flat directory. The upgrade is one commit that rewrites the layout without changing a
single event, and like every other write it shows you the full plan first. It refuses to run until
the whole history is loaded, so it can't drop anything.
