import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

// Git's commit-hook environment must not escape into disposable test repositories.
for (const key of Object.keys(process.env)) if (key.startsWith("GIT_")) delete process.env[key];

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
function buildPinned(attribute) {
  const expression = `(builtins.getFlake ${JSON.stringify(`path:${root}`)}).${attribute}`;
  return execFileSync("nix", [
    "build",
    "--no-link",
    "--print-out-paths",
    "--impure",
    "--expr",
    expression,
  ], {
    cwd: root,
    encoding: "utf8",
  }).trim();
}
const packagePath = process.env.PI_TEST_PACKAGE
  || buildPinned("inputs.pi.packages.${builtins.currentSystem}.coding-agent");
const packageDir = join(packagePath, "lib/node_modules/@earendil-works/pi-coding-agent");
const sdk = await import(pathToFileURL(join(packageDir, "dist/index.js")).href);
const dot = join(root, "dotfiles/pi-1.2.0/.pi/agent");

test("TypeScript extensions typecheck against the pinned SDK", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "pi-typecheck-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const modules = join(packagePath, "lib/node_modules");
  const compiler = buildPinned(
    "inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.typescript",
  );
  const config = join(directory, "tsconfig.json");
  writeFileSync(
    config,
    JSON.stringify({
      compilerOptions: {
        target: "ES2023",
        module: "ESNext",
        moduleResolution: "Bundler",
        strict: true,
        noEmit: true,
        skipLibCheck: true,
        allowImportingTsExtensions: true,
        types: ["node"],
        typeRoots: [join(modules, "@types")],
        baseUrl: root,
        paths: {
          "@earendil-works/pi-coding-agent": [join(packageDir, "dist/index.d.ts")],
          typebox: [join(modules, "typebox/build/index.d.mts")],
          "typebox/value": [join(modules, "typebox/build/value/index.d.mts")],
        },
      },
      files: [join(dot, "extensions/workflow/index.ts"), join(dot, "extensions/services/index.ts")],
    }),
  );
  execFileSync(join(compiler, "bin/tsc"), ["-p", config], { cwd: root, stdio: "pipe" });
});

async function fixture(t) {
  const cwd = mkdtempSync(join(tmpdir(), "pi-parity-"));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const loader = new sdk.DefaultResourceLoader({
    cwd,
    agentDir: cwd,
    settingsManager: sdk.SettingsManager.inMemory({ packages: [] }),
    additionalExtensionPaths: [
      join(dot, "extensions/workflow/index.ts"),
      join(dot, "extensions/services/index.ts"),
      join(packageDir, "examples/extensions/subagent/index.ts"),
    ],
    noSkills: true,
    noThemes: true,
    noPromptTemplates: true,
    noContextFiles: true,
  });
  await loader.reload();
  const loaded = loader.getExtensions();
  assert.deepEqual(loaded.errors, []);
  const workflow = loaded.extensions.find((extension) => extension.path.includes("/workflow/"));
  assert.ok(workflow);
  let branch = [];
  let active = ["read", "bash", "edit", "write", "codemode", "subagent"];
  const initial = [...active];
  const widgets = new Map();
  const messages = [];
  Object.assign(loaded.runtime, {
    getActiveTools: () => [...active],
    setActiveTools: (tools) => {
      active = [...tools];
    },
    appendEntry: (customType, data) => branch.push({ type: "custom", customType, data }),
    sendUserMessage: (message) => messages.push(message),
  });
  const ctx = {
    cwd,
    hasUI: true,
    waitForIdle: async () => {},
    sessionManager: { getBranch: () => branch },
    ui: {
      setStatus: () => {},
      setWidget: (name, value) => widgets.set(name, value),
      notify: () => {},
      select: async () => undefined,
      input: async () => undefined,
    },
  };
  const emit = async (name, event = {}) => {
    const results = [];
    for (const handler of workflow.handlers.get(name) || []) {
      results.push(await handler(event, ctx));
    }
    return results;
  };
  return {
    cwd,
    loaded,
    ctx,
    initial,
    widgets,
    messages,
    active: () => active,
    branch: () => structuredClone(branch),
    switchBranch: (entries) => {
      branch = entries;
    },
    emit,
    command: (name, args = "") => workflow.commands.get(name).handler(args, ctx),
    tool: (name, params) =>
      workflow.tools.get(name).definition.execute("test", params, undefined, undefined, ctx),
  };
}

test("real Pi SDK loads workflow, native MCP registrations and upstream subagent", async (t) => {
  const f = await fixture(t);
  const tools = f.loaded.extensions.flatMap((extension) => [...extension.tools.keys()]);
  for (const name of ["update_plan", "request_user_input", "git_diff", "subagent"]) {
    assert.ok(tools.includes(name));
  }
  assert.equal(
    f.loaded.runtime.mcpServers.get("openaiDeveloperDocs").config.url,
    "https://developers.openai.com/mcp",
  );
  assert.equal(f.loaded.runtime.mcpServers.get("openaiDeveloperDocs").config.exposure, "codemode");
  const settings = JSON.parse(readFileSync(join(dot, "settings.json"), "utf8"));
  assert.ok(!settings.packages.includes("npm:pi-mcp-adapter"));
  assert.ok(settings.defaultTools.includes("+codemode"));
});

test("real Pi RPC process exposes the extension commands without a model request", (t) => {
  const cwd = mkdtempSync(join(tmpdir(), "pi-rpc-"));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const result = spawnSync(join(packagePath, "bin/pi"), [
    "--mode",
    "rpc",
    "--no-session",
    "--no-mcp",
    "--no-skills",
    "--no-context-files",
    "--no-extensions",
    "-e",
    join(dot, "extensions/workflow/index.ts"),
  ], {
    cwd,
    env: { ...process.env, PI_CODING_AGENT_DIR: cwd },
    encoding: "utf8",
    input: "{\"id\":\"commands\",\"type\":\"get_commands\"}\n",
    timeout: 15000,
  });
  assert.equal(result.status, 0, result.stderr);
  const response = result.stdout.split("\n").filter(Boolean).map((line) => JSON.parse(line))
    .find((event) => event.id === "commands");
  assert.equal(response.success, true);
  assert.deepEqual(response.data.commands.map((command) => command.name).sort(), [
    "plan",
    "review",
  ]);
});

test("plan mode blocks execution, mutation and indirect tool access, then restores tools", async (t) => {
  const f = await fixture(t);
  await f.command("plan", "on");
  for (
    const toolName of [
      "bash",
      "powershell",
      "edit",
      "write",
      "codemode",
      "tool_search",
      "subagent",
      "mcp__service__delete",
    ]
  ) {
    assert.equal((await f.emit("tool_call", { toolName }))[0].block, true, toolName);
  }
  for (
    const toolName of [
      "read",
      "grep",
      "find",
      "ls",
      "git_diff",
      "update_plan",
      "request_user_input",
    ]
  ) {
    assert.equal((await f.emit("tool_call", { toolName }))[0], undefined, toolName);
  }
  assert.ok(!f.active().includes("bash"));
  await f.command("plan", "off");
  assert.deepEqual(f.active(), f.initial);
});

test("plan and progress follow the current session branch and ignore malformed state", async (t) => {
  const f = await fixture(t);
  await f.emit("session_start");
  const before = f.branch();
  await f.command("plan", "on");
  await f.tool("update_plan", {
    plan: [{ step: "Inspect", status: "completed" }, { step: "Implement", status: "pending" }],
  });
  const saved = f.branch();
  f.switchBranch(before);
  await f.emit("session_tree");
  assert.deepEqual(f.active(), f.initial);
  assert.equal(f.widgets.get("nixcfg-plan"), undefined);
  f.switchBranch([...saved, {
    type: "custom",
    customType: "nixcfg-workflow",
    data: { readOnly: "wrong" },
  }]);
  await f.emit("session_tree");
  assert.deepEqual(f.widgets.get("nixcfg-plan"), ["[x] Inspect", "[ ] Implement"]);
  assert.ok(!f.active().includes("bash"));
  const prompt = (await f.emit("before_agent_start", { systemPrompt: "base" }))[0].systemPrompt;
  assert.ok(prompt.includes("Inspect") && prompt.includes("Plan mode is active"));
  await assert.rejects(() =>
    f.tool("update_plan", {
      plan: [
        { step: "One", status: "in_progress" },
        { step: "Two", status: "in_progress" },
      ],
    }), /At most one/);
});

test("questions never assume an answer on cancellation or without interactive UI", async (t) => {
  const f = await fixture(t);
  const question = { id: "choice", question: "Choose", options: ["One", "Two"] };
  assert.equal(
    (await f.tool("request_user_input", { questions: [question] })).details.cancelled,
    true,
  );
  f.ctx.hasUI = false;
  await assert.rejects(
    () => f.tool("request_user_input", { questions: [question] }),
    /no answer was assumed/,
  );
  f.ctx.hasUI = true;
  f.ctx.ui.select = async () => "Write an answer…";
  f.ctx.ui.input = async () => "Custom answer";
  assert.deepEqual(
    (await f.tool("request_user_input", { questions: [question] })).details.answers,
    { choice: "Custom answer" },
  );
  await assert.rejects(
    () => f.tool("request_user_input", { questions: [question, question] }),
    /unique/,
  );
});

test("review enters plan mode and Git inspection includes staged, unstaged and untracked status", async (t) => {
  const f = await fixture(t);
  const env = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !key.startsWith("GIT_")),
  );
  env.GIT_CONFIG_GLOBAL = "/dev/null";
  env.GIT_CONFIG_NOSYSTEM = "1";
  const git = (...args) =>
    execFileSync("git", [
      "-c",
      "core.hooksPath=/dev/null",
      "-c",
      "user.name=Fixture",
      "-c",
      "user.email=fixture@example.invalid",
      ...args,
    ], { cwd: f.cwd, env, stdio: "pipe" });
  git("init", "-q");
  writeFileSync(join(f.cwd, "file.txt"), "before\n");
  git("add", "file.txt");
  git("commit", "-qm", "fixture");
  writeFileSync(join(f.cwd, "file.txt"), "after\n");
  writeFileSync(join(f.cwd, "untracked.txt"), "not yet tracked\n");
  await f.command("review");
  assert.ok(!f.active().includes("write"));
  assert.ok(f.messages[0].includes("uncommitted"));
  const working = (await f.tool("git_diff", { target: "working" })).content[0].text;
  assert.ok(working.includes("+after") && working.includes("?? untracked.txt"));
  git("add", "file.txt");
  const staged = (await f.tool("git_diff", { target: "staged" })).content[0].text;
  assert.ok(staged.includes("+after"));
  assert.equal(readFileSync(join(f.cwd, "file.txt"), "utf8"), "after\n");
});
