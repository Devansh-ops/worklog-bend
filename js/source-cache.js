/** Raw source cache. Every body is checked against a remote commit's blob ID. */
import { parseJSON } from './codec.js';
import { isSourcePath, sourceMonth, SourceIndexError } from './source-index.js';

const SHA = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const encoder = new TextEncoder();

export class SourceIntegrityError extends Error {
  constructor(message) { super(message); this.name = 'SourceIntegrityError'; }
}

function utf8(text) {
  if (typeof text !== 'string') throw new SourceIntegrityError('Source body must be UTF-8 text.');
  for (const point of text) {
    const code = point.charCodeAt(0);
    if (point.length === 1 && code >= 0xd800 && code <= 0xdfff) throw new SourceIntegrityError('Source body contains an unpaired UTF-16 surrogate.');
  }
  return encoder.encode(text);
}

/** Git hashes header + exact UTF-8 bytes, not the JSON semantics or bare text. */
export async function gitBlobHash(text, length = 40, cryptoObject = globalThis.crypto) {
  if (![40, 64].includes(length)) throw new SourceIntegrityError('Unsupported Git object hash format.');
  if (!cryptoObject?.subtle) throw new SourceIntegrityError('WebCrypto is required to verify source bodies. Use a secure browser origin.');
  const body = utf8(text);
  const header = encoder.encode(`blob ${body.length}\0`);
  const bytes = new Uint8Array(header.length + body.length);
  bytes.set(header); bytes.set(body, header.length);
  const digest = await cryptoObject.subtle.digest(length === 40 ? 'SHA-1' : 'SHA-256', bytes);
  return [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('');
}

/**
 * Synchronous construction, asynchronous getFile(), explicit best-effort flush().
 * Cache scope is repository and branch; reuse across commits is safe only because
 * every hit is rehashed against the newly fetched, complete remote tree index.
 */
export function createVerifiedSourceReader(repo, index, options = {}) {
  const revision = repo.readRevision, slug = repo.slug, branch = repo.branch || 'main';
  if (index?.complete !== true || index.revision !== revision || !SHA.test(revision || '') || !index.files || Array.isArray(index.files)) {
    throw new SourceIndexError('A complete source index for the pinned read revision is required.');
  }
  const expected = new Map();
  for (const [path, entry] of Object.entries(index.files)) {
    if (!isSourcePath(path) || !SHA.test(entry?.sha || '') || entry.sha.length !== revision.length || !Number.isSafeInteger(entry.size) || entry.size < 0) {
      throw new SourceIndexError('Invalid indexed source shape or object format.');
    }
    expected.set(path, { sha: entry.sha, size: entry.size });
  }
  const key = `worklog.sources.v1.${encodeURIComponent(String(slug).toLowerCase())}#${encodeURIComponent(branch)}`;
  const stats = { hits: 0, misses: 0, absent: 0, invalid: 0, networkReads: 0, storageReadFailed: false, storageWriteFailed: false };
  let storage;
  try { storage = Object.hasOwn(options, 'storage') ? options.storage : globalThis.localStorage; }
  catch { stats.storageReadFailed = true; }
  const cryptoObject = options.cryptoObject || globalThis.crypto;
  const cached = new Map(), verified = new Map(), pending = new Map();
  try {
    const saved = storage?.getItem(key);
    if (saved) {
      const value = parseJSON(saved);
      if (value?.version !== 1 || !value.files || Array.isArray(value.files) || typeof value.files !== 'object') throw new Error('Invalid cache envelope');
      for (const [path, body] of Object.entries(value.files)) if (expected.has(path) && typeof body === 'string') cached.set(path, body);
    }
  } catch { stats.storageReadFailed = true; }
  const unchanged = () => {
    if (repo.readRevision !== revision || repo.slug !== slug || (repo.branch || 'main') !== branch) throw new SourceIntegrityError('The source reader revision or destination changed. Reload its index.');
  };
  const matches = async (text, entry) => {
    if (utf8(text).length !== entry.size) return false;
    return await gitBlobHash(text, entry.sha.length, cryptoObject) === entry.sha;
  };
  async function read(path) {
    unchanged();
    if (!isSourcePath(path)) throw new SourceIndexError('The verified source reader only accepts declared ledger source paths.');
    // Validate even absent month paths so malformed paths cannot look safely absent.
    sourceMonth(path);
    const entry = expected.get(path);
    if (!entry) { stats.absent++; return null; }
    if (verified.has(path)) return { text: verified.get(path), sha: entry.sha };
    if (cached.has(path)) {
      let valid = false;
      try { valid = await matches(cached.get(path), entry); } catch { /* unusable cache is refetched, then checked strictly below */ }
      unchanged();
      if (valid) { stats.hits++; verified.set(path, cached.get(path)); return { text: cached.get(path), sha: entry.sha }; }
      stats.invalid++; cached.delete(path);
    }
    stats.misses++; stats.networkReads++;
    const file = await repo.getFile(path);
    unchanged();
    if (!file || typeof file.text !== 'string' || (file.sha && file.sha !== entry.sha) || !await matches(file.text, entry)) throw new SourceIntegrityError(`Source body does not match the pinned Git tree: ${path}`);
    unchanged();
    verified.set(path, file.text);
    return { text: file.text, sha: entry.sha };
  }
  return {
    stats,
    getFile(path) {
      if (pending.has(path)) return pending.get(path);
      const promise = read(path).finally(() => pending.delete(path));
      pending.set(path, promise);
      return promise;
    },
    flush() {
      unchanged();
      if (!storage) return false;
      try {
        // Only bodies verified against this index are saved. Other unrelated
        // localStorage keys, including pending events and credentials, stay intact.
        storage.setItem(key, JSON.stringify({ version: 1, revision, files: Object.fromEntries(verified) }));
        return true;
      } catch { stats.storageWriteFailed = true; return false; }
    },
  };
}
