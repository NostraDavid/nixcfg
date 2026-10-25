import assert from "node:assert/strict";
import { once } from "node:events";
import { brotliCompressSync, brotliDecompressSync, createBrotliDecompress } from "node:zlib";

// The upstream Node regression for CVE-2026-111497.
const invalid = Buffer.from("200010414141fcffff07002228f00b60f7f41f000000", "hex");
assert.throws(() => brotliDecompressSync(invalid), { errno: -17 });
const stream = createBrotliDecompress();
stream.resume();
const failure = once(stream, "error");
for (const byte of invalid) stream.write(Buffer.from([byte]));
stream.end();
const [error] = await failure;
assert.equal(error.errno, -17);
for (const data of [Buffer.alloc(0), Buffer.from("ordinary text\n".repeat(10000))]) {
  assert.deepEqual(brotliDecompressSync(brotliCompressSync(data)), data);
}
console.log("Brotli rejects invalid block switches and preserves valid streams.");
