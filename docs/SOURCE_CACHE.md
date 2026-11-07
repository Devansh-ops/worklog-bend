# Verified source cache

Implemented and checked on 2026-11-08. This adapter reduces repeated source downloads while preserving authoritative Bend replay. It does not trust snapshot state, infer coverage from timestamps, introduce a schema migration, or establish an incremental-checkpoint theorem.

## Index and reader contract

After `repo.pinRevision()`, call `readSourceIndex(repo)` from `js/source-index.js`. It reads the exact commit object, its nonrecursive root tree, and the complete recursive `data/` tree. These are three metadata requests after the ref lookup, or two when `data/` is absent. Indexing the data subtree avoids unrelated large code trees. Responses must match the requested object IDs, have valid entries, and explicitly report `truncated: false`. A truncated tree, malformed path, invalid month, unsupported hash shape, or symlink/submodule in a declared ledger source is refused. An ordinary absent `data/` directory yields a complete empty index for setup handling.

The immutable result is `{ revision, complete: true, files, months }`. `files` maps manifest, board, and every schema 1/2 month source path to its remote blob ID and byte size. `months` discovers both canonical and legacy month filenames independently of the manifest. Integration must union those months with manifest months before authoritative loading; otherwise an incomplete manifest could hide privacy/deletion history. Extra unrelated files are never deleted by the cache.

`createVerifiedSourceReader(repo, index, { storage, cryptoObject })` in `js/source-cache.js` returns a reader synchronously. Both options default to browser capabilities. Its `getFile(path)` method is asynchronous; `flush()` is a synchronous best-effort cache write returning a boolean. `stats` exposes hit/miss/absence, invalid-body, network-read and storage-failure counters. The reader captures repository, branch and immutable revision, and refuses destination/revision changes before or during reads. Construct a new index/reader after conflict reload or a successful commit.

An indexed missing source body is an integrity error, not an empty month. A path absent from the complete index returns null. Calls outside the declared ledger source paths are refused. Concurrent reads of one source share a fetch.

## Integrity and persistence

Cache entries contain raw text and bookkeeping, never credentials or trusted coverage claims. Every cached hit is encoded as UTF-8 and checked against the current remote index using the Git object framing `blob <byte-length>\0<body>`. Byte length and blob digest must both match. A cached SHA or revision cannot authorize a body. Cache corruption causes a verified source refetch; wrong, missing or mismatched network bodies fail before the store receives them. Unpaired UTF-16 surrogates are refused before TextEncoder could silently normalize them.

The reader uses WebCrypto SHA-1 for 40-character Git blob IDs. The generic 64-character SHA-256 framing route is tested locally; the inspected GitHub documentation specifies SHA-1 and no live SHA-256 GitHub repository was tested. Unsupported lengths fail explicitly. Verification requires WebCrypto on a secure browser origin such as HTTPS or localhost. Cryptographic collision resistance, GitHub response authenticity, browser behavior and generated Bend code remain outside the modeled domain proof guarantees.

The storage key is scoped to normalized repository identity and branch. Bodies may be reused across commits only after verification against the new remote tree. Flush saves only bodies verified for that reader. Denied storage, corrupt cache envelopes, or quota failure fall back to verified network reads; the adapter never overwrites pending-event or credential keys and never discards domain work. Optional caching may therefore be unavailable for large histories or restrictive browser policies. Initial clients and invalid/missing caches still download all authoritative source bodies.

The store continues to parse versions, detect duplicate keys, reconcile events and run full Bend replay for both cached and network bodies. A cached future-schema month is returned verbatim for that existing schema guard to refuse. Cache verification cannot make unsupported semantics safe. CPU work and memory for full replay remain proportional to history even when body downloads are bounded.

## Executed checks

`node test/source-cache.mjs` passed nine independent adapter checks, all using synthetic repository data. They include actual `git hash-object --stdin` agreement with WebCrypto for Unicode, SHA-256 framing against an independent Node hash, malformed string/hash rejection, complete metadata discovery, truncation/symlink/path refusal, destination changes, body/SHA mismatch, cached tampering, concurrent fetch sharing, branch isolation, and storage denial/quota behavior.

A 1,000-month fixture plus manifest and board required 1,002 body reads on initial load, zero body reads on an unchanged reload, and three body reads after a new revision changed only its manifest, board and newest month. Each index used three metadata requests. This is finite test evidence for source-download bounds, not a claim that a fresh client can skip historical privacy provenance or that full replay has constant cost.

## Primary API documentation reviewed

The GitHub [Get a commit documentation](https://docs.github.com/en/rest/git/commits#get-a-commit) defines the commit-to-tree relationship. The [Get a tree documentation](https://docs.github.com/en/rest/git/trees#get-a-tree) defines recursive traversal, blob metadata and truncation. Its documented recursive limit is 100,000 entries or 7 MB; this adapter never treats a truncated response as complete. A separately reviewed traversal fallback would be needed to support histories exceeding that limit.
