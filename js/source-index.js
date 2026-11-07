/** Git tree metadata is trusted only for the exact pinned read commit. */
export class SourceIndexError extends Error {
  constructor(message) { super(message); this.name = 'SourceIndexError'; }
}

const SHA = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const MONTH = /^\d{4}-(?:0[1-9]|1[0-2])$/;

export function sourceMonth(path) {
  const current = /^data\/log\/(\d{4})\/(\d{2})\.json$/.exec(path);
  const legacy = /^data\/log\/(\d{4}-\d{2})\.json$/.exec(path);
  const month = current ? `${current[1]}-${current[2]}` : legacy?.[1];
  if (month && !MONTH.test(month)) throw new SourceIndexError(`Invalid source month path: ${path}`);
  return month || null;
}

export function isSourcePath(path) {
  return typeof path === 'string' && (path === 'data/manifest.json' || path === 'data/board.json' || sourceMonth(path) !== null);
}

function validPath(path) {
  return typeof path === 'string' && !/[\\\x00-\x1f]/.test(path)
    && path.split('/').every(part => part && part !== '.' && part !== '..');
}

function treeResponse(value, expectedSha) {
  if (!value || value.sha !== expectedSha || value.truncated !== false || !Array.isArray(value.tree)) {
    throw new SourceIndexError('The source tree is invalid or truncated. Complete authoritative source coverage is unavailable.');
  }
  const seen = new Set();
  for (const entry of value.tree) {
    if (!entry || !validPath(entry.path) || seen.has(entry.path) || !SHA.test(entry.sha || '') || entry.sha.length !== expectedSha.length) {
      throw new SourceIndexError('Invalid or repeated source tree entry.');
    }
    seen.add(entry.path);
  }
  return value.tree;
}

/**
 * Fetch complete metadata under data/, avoiding unrelated large repository trees.
 * No file bodies or tokens are persisted here. Missing data/ is a complete empty
 * index; a truncated response is never presented as a complete index.
 */
export async function readSourceIndex(repo) {
  const revision = repo.readRevision;
  const slug = repo.slug;
  const branch = repo.branch || 'main';
  if (!SHA.test(revision || '')) throw new SourceIndexError('Pin an exact Git read revision before indexing sources.');
  if (!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}$/.test(slug || '') || ['.', '..'].includes(slug.split('/')[1])) {
    throw new SourceIndexError('Invalid repository identity for source metadata.');
  }
  const unchanged = () => {
    if (repo.readRevision !== revision || repo.slug !== slug || (repo.branch || 'main') !== branch) throw new SourceIndexError('The repository read revision changed during source indexing.');
  };
  const base = `https://api.github.com/repos/${slug}`;
  const get = async path => { unchanged(); const result = await repo._json(base + path); unchanged(); return result; };
  const commit = await get(`/git/commits/${revision}`);
  if (commit?.sha !== revision || !SHA.test(commit.tree?.sha || '') || commit.tree.sha.length !== revision.length) throw new SourceIndexError('GitHub returned a commit that does not match the pinned read revision.');
  const root = treeResponse(await get(`/git/trees/${commit.tree.sha}`), commit.tree.sha);
  if (root.some(entry => entry.path.includes('/'))) throw new SourceIndexError('A nonrecursive root tree contained nested entries.');
  const data = root.find(entry => entry.path === 'data');
  const files = Object.create(null);
  const months = new Set();
  if (data) {
    if (data.type !== 'tree' || data.mode !== '040000') throw new SourceIndexError('The data source must be an ordinary Git directory.');
    const entries = treeResponse(await get(`/git/trees/${data.sha}?recursive=1`), data.sha);
    for (const entry of entries) {
      const path = `data/${entry.path}`;
      if ((entry.path === 'log' || /^log\/\d{4}$/.test(entry.path)) && (entry.type !== 'tree' || entry.mode !== '040000')) {
        throw new SourceIndexError(`Ledger source directory must be an ordinary Git tree: ${path}`);
      }
      if (!isSourcePath(path)) continue;
      if (entry.type !== 'blob' || !['100644', '100755'].includes(entry.mode) || !Number.isSafeInteger(entry.size) || entry.size < 0) {
        throw new SourceIndexError(`Source must be an ordinary Git blob: ${path}`);
      }
      files[path] = Object.freeze({ sha: entry.sha, size: entry.size });
      const month = sourceMonth(path);
      if (month) months.add(month);
    }
  }
  unchanged();
  return Object.freeze({ revision, complete: true, files: Object.freeze(files), months: Object.freeze([...months].sort()) });
}
