// Run with: node check-executor.cjs /path/to/chatgpt/resources/app.asar
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { execFile } = require("node:child_process");
const { promisify } = require("node:util");

(async () => {
  const archive = await fs.open(process.argv[2], "r");
  let code;
  let copyCode;
  let initializerName;
  let fsModule;
  let pathModule;
  let definitionName;
  let hostModule;
  let hostProperty;
  let copyName;
  let runnerName;
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
    const initializer = /async function ([\w$]+)\(\{executorPluginRoot:/.exec(text);
    assert.ok(initializer, "executor initializer not found");
    const start = initializer.index;
    const end = text.indexOf("async function ", start + initializer[0].length);
    assert.ok(start >= 0 && end > start, "executor initializer not found");
    code = text.slice(start, end);
    initializerName = initializer[1];
    const modules = /f=([\w$]+)\.default,p=([\w$]+)\.default/.exec(code);
    assert.ok(modules, "executor aliases were not patched");
    [, fsModule, pathModule] = modules;
    definitionName = /let n=await ([\w$]+)\(/.exec(code)[1];
    [, hostModule, hostProperty] = /CODEX_APP_TOOLS_CALLER_HOST_ID:([\w$]+)\.([\w$]+)/.exec(code);
    const copy = /async function ([\w$]+)\(e,t\)\{await ([\w$]+)\(`[^`]+\/bin\/cp`/.exec(text);
    assert.ok(copy, "marketplace copy helper not found");
    const copyStart = copy.index;
    const copyEnd = text.indexOf("async function ", copyStart + copy[0].length);
    assert.ok(copyStart >= 0 && copyEnd > copyStart, "marketplace copy helper not found");
    copyCode = text.slice(copyStart, copyEnd);
    [, copyName, runnerName] = copy;
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
    const initialize = new Function(
      fsModule,
      pathModule,
      hostModule,
      definitionName,
      `${code}; return ${initializerName};`,
    )(
      { default: fs },
      { default: path },
      { [hostProperty]: "local" },
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

    const pluginSource = path.join(root, "plugin-source");
    const pluginTarget = path.join(root, "plugin-target");
    await fs.mkdir(path.join(pluginSource, ".codex-plugin"), { recursive: true });
    await fs.writeFile(path.join(pluginSource, ".codex-plugin", "plugin.json"), "{}", {
      mode: 0o444,
    });
    await fs.writeFile(path.join(pluginSource, "executable"), "", { mode: 0o555 });
    await fs.symlink("executable", path.join(pluginSource, "link"));
    await fs.chmod(path.join(pluginSource, ".codex-plugin"), 0o555);
    await fs.chmod(pluginSource, 0o555);
    const copyPlugin = new Function(runnerName, `${copyCode}; return ${copyName};`)(
      promisify(execFile),
    );
    try {
      for (let i = 0; i < 2; i++) {
        await copyPlugin(pluginSource, pluginTarget);
        assert.ok((await fs.stat(path.join(pluginTarget, ".codex-plugin"))).mode & 0o200);
        await fs.writeFile(
          path.join(pluginTarget, ".codex-plugin", "plugin.json"),
          "{\"bundledContentVariant\":\"live\"}",
        );
        assert.ok((await fs.stat(path.join(pluginTarget, "executable"))).mode & 0o100);
        assert.equal(await fs.readlink(path.join(pluginTarget, "link")), "executable");
        assert.equal(
          await fs.readFile(path.join(pluginSource, ".codex-plugin", "plugin.json"), "utf8"),
          "{}",
        );
      }
      console.log(
        "PASS: marketplace plugins remain writable across repeated copies from read-only packages",
      );
    } finally {
      for (const directory of [pluginSource, pluginTarget]) {
        await fs.chmod(directory, 0o755);
        await fs.chmod(path.join(directory, ".codex-plugin"), 0o755);
      }
    }
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
