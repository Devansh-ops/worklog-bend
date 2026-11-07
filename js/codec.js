/** Untrusted JSON boundary. These checks are outside Bend proof guarantees. */
export class CodecError extends Error {
  constructor(message, path = '$') {
    super(`${path}: ${message}`);
    this.name = 'CodecError';
    this.path = path;
  }
}

// JSON.parse discards duplicate object keys. Parse before that information is
// lost, and use own data properties so '__proto__' remains ordinary JSON data.
export function parseJSON(text, { maxDepth = 64 } = {}) {
  if (typeof text !== 'string') throw new CodecError('expected JSON text');
  let offset = 0;
  const fail = message => { throw new CodecError(`${message} at offset ${offset}`); };
  const whitespace = () => { while (/[\x20\t\r\n]/.test(text[offset] || '\0')) offset++; };
  const string = () => {
    const start = offset++;
    while (offset < text.length) {
      const character = text[offset++];
      if (character === '\\') { offset++; continue; }
      if (character === '"') {
        try { return JSON.parse(text.slice(start, offset)); } catch { fail('invalid string'); }
      }
    }
    fail('unterminated string');
  };
  function value(depth) {
    if (depth > maxDepth) fail('JSON nesting limit exceeded');
    whitespace();
    const character = text[offset];
    if (character === '"') return string();
    if (character === '{') {
      offset++; whitespace();
      const result = {}, seen = new Set();
      if (text[offset] === '}') { offset++; return result; }
      while (true) {
        whitespace();
        if (text[offset] !== '"') fail('expected object key');
        const key = string();
        if (seen.has(key)) fail(`duplicate object key ${JSON.stringify(key)}`);
        seen.add(key); whitespace();
        if (text[offset++] !== ':') fail('expected colon');
        Object.defineProperty(result, key, { value: value(depth + 1), enumerable: true, writable: true, configurable: true });
        whitespace();
        const separator = text[offset++];
        if (separator === '}') return result;
        if (separator !== ',') fail('expected comma or closing brace');
      }
    }
    if (character === '[') {
      offset++; whitespace();
      const result = [];
      if (text[offset] === ']') { offset++; return result; }
      while (true) {
        result.push(value(depth + 1)); whitespace();
        const separator = text[offset++];
        if (separator === ']') return result;
        if (separator !== ',') fail('expected comma or closing bracket');
      }
    }
    for (const [token, result] of [['true', true], ['false', false], ['null', null]]) {
      if (text.startsWith(token, offset)) { offset += token.length; return result; }
    }
    const token = text.slice(offset).match(/^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/)?.[0];
    if (!token) fail('expected JSON value');
    offset += token.length;
    const number = Number(token);
    if (!Number.isFinite(number)) fail('nonfinite number');
    if (Number.isInteger(number) && !Number.isSafeInteger(number)) fail('integer exceeds exact host range');
    return number;
  }
  const result = value(0);
  whitespace();
  if (offset !== text.length) fail('unexpected trailing text');
  return result;
}

export function canonicalJSON(value) {
  const active = new Set();
  function encode(item) {
    if (item === null || typeof item === 'boolean') return JSON.stringify(item);
    if (typeof item === 'number' && Number.isFinite(item) && (!Number.isInteger(item) || Number.isSafeInteger(item))) return JSON.stringify(item);
    if (typeof item === 'string') {
      // Generated Bend strings normalize lone UTF-16 surrogates. Refuse rather
      // than silently change event identity at the compiler boundary.
      for (const point of item) {
        const code = point.charCodeAt(0);
        if (point.length === 1 && code >= 0xd800 && code <= 0xdfff) throw new CodecError('unpaired UTF-16 surrogate');
      }
      return JSON.stringify(item);
    }
    if (typeof item !== 'object' || active.has(item)) throw new CodecError('non-JSON value or cycle');
    if (!Array.isArray(item) && ![Object.prototype, null].includes(Object.getPrototypeOf(item))) throw new CodecError('expected plain JSON object');
    active.add(item);
    if (Object.getOwnPropertySymbols(item).length) throw new CodecError('symbol property');
    let result;
    if (Array.isArray(item)) {
      const values = [];
      for (let index = 0; index < item.length; index++) {
        if (!Object.hasOwn(item, index)) throw new CodecError('sparse array');
        const descriptor = Object.getOwnPropertyDescriptor(item, String(index));
        if (!Object.hasOwn(descriptor, 'value')) throw new CodecError('accessor property');
        values.push(encode(descriptor.value));
      }
      result = `[${values.join(',')}]`;
    } else {
      result = `{${Object.keys(item).sort().map(key => {
        const descriptor = Object.getOwnPropertyDescriptor(item, key);
        if (!descriptor || !Object.hasOwn(descriptor, 'value')) throw new CodecError('accessor property');
        return `${encode(key)}:${encode(descriptor.value)}`;
      }).join(',')}}`;
    }
    active.delete(item);
    return result;
  }
  return encode(value);
}

export function immutableJSON(value) {
  const owned = parseJSON(canonicalJSON(value));
  function freeze(item) {
    if (item && typeof item === 'object') {
      for (const child of Object.values(item)) freeze(child);
      Object.freeze(item);
    }
    return item;
  }
  return freeze(owned);
}

export function listToBend(items, encode = value => value) {
  if (!Array.isArray(items)) throw new CodecError('expected array');
  let result = { $: 'Nil' };
  for (let index = items.length - 1; index >= 0; index--) result = { $: 'Con', head: encode(items[index]), tail: result };
  return result;
}

export function listFromBend(list, decode = value => value) {
  const result = [], seen = new Set();
  while (list?.$ === 'Con') {
    if (seen.has(list)) throw new CodecError('cyclic compiler list');
    seen.add(list); result.push(decode(list.head)); list = list.tail;
  }
  if (list?.$ !== 'Nil') throw new CodecError('invalid compiler list terminator');
  return result;
}
