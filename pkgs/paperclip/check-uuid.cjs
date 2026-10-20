const assert = require("node:assert/strict");
const { createRequire } = require("node:module");

const paperclipRequire = createRequire(`${process.argv[2]}/package.json`);
const svixRequire = createRequire(paperclipRequire.resolve("svix"));
const uuid = svixRequire("uuid");

assert.equal(uuid.validate(uuid.v4()), true);
for (const name of ["v3", "v5", "v6"]) {
  const generate = (buffer, offset) =>
    name === "v6"
      ? uuid[name]({}, buffer, offset)
      : uuid[name]("x", uuid[name].DNS, buffer, offset);
  for (const [size, offset] of [[8, 4], [16, 1], [16, -1]]) {
    assert.throws(() => generate(new Uint8Array(size), offset), RangeError);
  }
  const buffer = new Uint8Array(20).fill(0xaa);
  assert.equal(generate(buffer, 4), buffer);
  assert.deepEqual(buffer.slice(0, 4), new Uint8Array(4).fill(0xaa));
  assert.equal(uuid.validate(uuid.stringify(buffer, 4)), true);
}
console.log("PASS: Svix UUID generation works and rejects invalid buffer bounds");
