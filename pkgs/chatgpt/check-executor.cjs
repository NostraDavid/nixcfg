// Run with: node check-executor.cjs /path/to/chatgpt/resources/app.asar
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

(async () => {
  const archive = await fs.open(process.argv[2], "r");
  let code;
  try {
    const prefix = Buffer.alloc(16);
    await archive.read(prefix, 0, prefix.length, 0);
    const header = Buffer.alloc(prefix.readUInt32LE(12));
    await archive.read(header, 0, header.length, 16);
    const tree = JSON.parse(header).files;
    const files = tree[".vite"].files.build.files;
    const readSource = async member => {
      const bytes = Buffer.alloc(member.size);
      await archive.read(
        bytes,
        0,
        bytes.length,
        8 + prefix.readUInt32LE(4) + Number(member.offset),
      );
      return bytes.toString();
    };
    const [, main] = Object.entries(files).find(([name]) => /^main-.*\.js$/.test(name));
    const text = await readSource(main);
    const start = text.indexOf("async function el({executorPluginRoot:");
    const end = text.indexOf("async function tl(", start);
    assert.ok(start >= 0 && end > start, "executor initializer not found");
    code = text.slice(start, end);
  } finally {
    await archive.close();
  }

  const root = await fs.mkdtemp(path.join(os.tmpdir(), "chatgpt-executor-test-"));
  try {
    const src = path.join(root, "source");
    const dest = path.join(root, "executor");
    await fs.mkdir(src);
    await fs.writeFile(path.join(src, ".mcp.json"), "{}", { mode: 0o444 });
    await fs.writeFile(path.join(src, "server.js"), "");
    const initialize = new Function("b", "S", "r", "nl", `${code}; return el;`)(
      { default: fs },
      { default: path },
      { Dn: "local" },
      async () => ({ cwd: src, command: path.join(src, "server.js"), env: {} }),
    );
    for (let i = 0; i < 2; i++) {
      assert.equal(await initialize({ executorPluginRoot: dest, resourcesPath: "" }), dest);
      const config = JSON.parse(await fs.readFile(path.join(dest, ".mcp.json"), "utf8"));
      assert.equal(config.mcpServers.codex_app.env.CODEX_APP_TOOLS_CALLER_HOST_ID, "local");
      assert.equal(config.mcpServers.codex_app.command, path.join(dest, "server.js"));
      assert.ok((await fs.stat(path.join(dest, ".mcp.json"))).mode & 0o200);
    }
    console.log("PASS: executor starts and restarts with read-only Nix package files");
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
