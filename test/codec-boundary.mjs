import assert from 'node:assert/strict';
import { CodecError, parseJSON, canonicalJSON, immutableJSON, listToBend, listFromBend } from '../js/codec.js';

for (const input of ['null', 'true', 'false', '12', '-3.5e2', '"\\u03bb"', '[1,{},[]]', '{"a":1,"b":[false,null]}']) {
  assert.deepEqual(parseJSON(input), JSON.parse(input));
}
for (const input of ['{"a":1,"a":2}', '{"a":1,"\\u0061":2}', '[1,]', '{"a":1,}', '01', '1e', 'true false', '"\\x"', '"unfinished', '1e400', '9007199254740993']) {
  assert.throws(() => parseJSON(input), CodecError, input);
}
assert.throws(() => parseJSON('[[[0]]]', { maxDepth: 2 }), /nesting/);
const proto = parseJSON('{"__proto__":{"polluted":true}}');
assert.equal(Object.getPrototypeOf(proto), Object.prototype);
assert.equal(Object.hasOwn(proto, '__proto__'), true);
assert.equal({}.polluted, undefined);
assert.equal(canonicalJSON({ b: [2, 1], a: { z: true, x: null } }), '{"a":{"x":null,"z":true},"b":[2,1]}');
assert.equal(canonicalJSON(parseJSON('{"future":{"keep":[1,"synthetic"]},"id":"event"}')), '{"future":{"keep":[1,"synthetic"]},"id":"event"}');
for (const value of [undefined, NaN, Infinity, 9007199254740992, () => {}, new Date(), '\ud800', { a: undefined }, [, 1], { [Symbol('x')]: 1 }]) {
  assert.throws(() => canonicalJSON(value), CodecError);
}
const cyclic = {}; cyclic.self = cyclic;
assert.throws(() => canonicalJSON(cyclic), /cycle/);
const accessor = {};
Object.defineProperty(accessor, 'secret', { enumerable: true, get() { throw new Error('getter must not run'); } });
assert.throws(() => canonicalJSON(accessor), /accessor/);
const source = { files: [{ path: 'synthetic.json', text: 'before' }] };
const copy = immutableJSON(source);
source.files[0].text = 'after';
assert.equal(copy.files[0].text, 'before');
assert.throws(() => { copy.files[0].text = 'changed'; }, TypeError);
assert.deepEqual(listFromBend(listToBend(['a', 'b'])), ['a', 'b']);
assert.throws(() => listFromBend({ $: 'Unexpected' }), CodecError);
const loop = { $: 'Con', head: 'a' }; loop.tail = loop;
assert.throws(() => listFromBend(loop), /cyclic/);
console.log('Codec boundary passed: strict JSON, duplicate keys, unknown data, ownership, unicode, malformed values, list ABI');
