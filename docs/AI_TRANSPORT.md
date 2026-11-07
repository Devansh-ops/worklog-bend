# AI request boundary and verification

Updated 2026-11-08. These are adapter checks against generated Bend projections,
not proof claims about HTTP, browsers, providers, or arbitrary user-authored text.

## Prepared values and effects

Each UI flow obtains an authoritative event history, then prepares a request using
the generated Bend `requestContext` or `reportContext` adapter. Visible board rows
cannot establish eligibility. Unsupported/incomplete authoritative history blocks
the UI path. Deleted and private task eligibility is decided from full replay,
including tombstones. Summary activity is the generated typed allowlist projection;
raw event envelopes, saved reports, and previous summaries are never inserted.

`js/request.js` freezes the endpoint identity, model, notes policy, selected context,
free text, exact transport messages, schema, and bounded generation parameters.
Credentials and the full source-revision comparison remain in a private WeakMap,
outside the disclosed request. The consent dialog and standing expandable preview
read that same request. Transport does not rebuild its content after approval.
Remembered consent is scoped to normalized provider and destination; a prepared
request still appears in the view so its exact messages can be inspected.

The coordinator compares the current event revision, destination, model, notes
policy, and authoritative status before dispatch, before each fallback, and after
a response. A changed revision requires a fresh request. Selected operations are
checked against the request's original eligible targets and the current generated
Bend proposal validator before staging. Empty selection stages nothing. A later
change to private/deleted state invalidates a previously public target.

Brain-dump input and edited report drafts are separate verbatim free-text inputs.
They can contain any words. The application does not infer or promise semantic
redaction of this text. Automatic notes-off context contains no note-derived
strings, including through old summaries or reports. The deterministic report
projection also removes internal ID fields before preparing model messages.

## Destination and transport

Locality follows the actual normalized HTTP destination. Only explicit loopback
hosts qualify as local HTTP services. A remote override of a local preset is
remote. URL credentials, fragments, non-HTTP schemes, and credential-like query
keys are refused. Relevant query parameters remain part of the destination and
are preserved when appending the API route. Model and catalogue fetches reject
redirects, so approval cannot silently transfer content or credentials elsewhere.

All nine HTTP presets retain their OpenAI-compatible routes and extra headers.
Format negotiation remains json_schema, json_object, then plain prompting.
Only an identified unsupported sampling parameter is dropped, and max_tokens
can be renamed to max_completion_tokens when the response identifies that need.
The loop is bounded. Fallbacks reuse identical frozen messages and destination.
Output JSON is parsed with duplicate-key rejection and a one-million-character
limit; malformed summaries cannot be recorded as empty successes.

The existing WebLLM worker, model discovery/load/unload/progress and error UI are
retained. This change does not claim a real GPU model was downloaded or executed.

## Executed checks

`node test/ai-privacy.mjs` executes the actual generated Bend modules with
synthetic public, private, deleted, note, report, and summary records, then
intercepts actual outgoing fetch options and body bytes. It checks notes-off,
deleted-task canaries, separate verbatim free text, safe report selection,
disclosure/message equality, credentials absent from disclosure, frozen retries,
changed destination, newly private proposal targets, cancelled consent, AI off,
demo rules, and loopback/remote URL classification. Its Cancel dispatch uses the
documented test DOM shim; it is not real browser evidence.

`node test/ai-provider-contracts.mjs` checks all nine HTTP preset routes, model
names and authentication/extra headers using fake credentials. It separately
checks bounded parameter and format fallback, 401/402/403/404/429/500 errors,
network/CORS failure, malformed provider JSON, malformed summary shape, duplicate
model keys, and oversized output. No request reaches a real provider.

The existing `ai.test.js`, `consent.test.js`, `providers.test.js`, and `rules.test.js`
were also run through the Node baseline. Standup-view fixtures require complete
authoritative history and the new report bridge before their model actions are
meaningful integration checks. The parent integration owns that fixture update
and real browser acceptance.

## Current documentation inspection

The API shapes were checked against the primary
[Anthropic OpenAI compatibility documentation](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk),
[Hugging Face Chat Completion documentation](https://huggingface.co/docs/inference-providers/tasks/chat-completion),
and [OpenAI Chat API reference](https://developers.openai.com/api/reference/resources/chat).
These support the retained compatible request shape; they are not evidence that
this machine completed a live authenticated request or browser CORS preflight.
Google's compatibility documentation URL returned an unsupported content type
to the documentation fetcher, so that check remains limited to the deterministic
existing Google route contract. Catalogue fallbacks are suggestions, not a promise
of current model availability; actual discovery remains supported.
