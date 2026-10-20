import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const packagePath = execFileSync("nix", [
  "build",
  `path:${root}#dbhub`,
  "--no-link",
  "--print-out-paths",
], { encoding: "utf8" }).trim();
const directory = mkdtempSync(join(tmpdir(), "dbhub-local-"));
const database = join(directory, "local.sqlite");
const config = join(directory, "local.toml");

function sql(query) {
  const messages = [
    {
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        capabilities: {},
        clientInfo: { name: "nixcfg-check", version: "1" },
      },
    },
    { method: "notifications/initialized" },
    { id: 2, method: "tools/list", params: {} },
    { id: 3, method: "tools/call", params: { name: "execute_sql", arguments: { sql: query } } },
  ];
  const result = spawnSync(join(packagePath, "bin/dbhub"), [
    "--transport",
    "stdio",
    "--config",
    config,
  ], {
    cwd: directory,
    env: { ...process.env, DSN: "sqlite:///:memory:" },
    encoding: "utf8",
    input: messages.map((message) => JSON.stringify({ jsonrpc: "2.0", ...message })).join("\n")
      + "\n",
    timeout: 15000,
  });
  assert.equal(result.status, 0, result.stderr);
  const replies = result.stdout.trim().split("\n").map((line) => JSON.parse(line));
  const tools = replies.find((reply) => reply.id === 2).result.tools.map((tool) => tool.name);
  assert.ok(tools.includes("execute_sql") && tools.includes("search_objects"));
  const response = replies.find((reply) => reply.id === 3);
  assert.ok(!response.error && !response.result.isError, JSON.stringify(response));
  return response.result;
}

try {
  writeFileSync(config, `[[sources]]\nid = "local"\ndsn = "sqlite://${database}"\n`);
  writeFileSync(
    join(directory, "dbhub.toml"),
    `[[sources]]\nid = "ambient"\ndsn = "sqlite://${join(directory, "ambient.sqlite")}"\n`,
  );
  sql("CREATE TABLE dbhub_check (answer INTEGER)");
  sql("INSERT INTO dbhub_check VALUES (42)");
  assert.match(JSON.stringify(sql("SELECT answer FROM dbhub_check").content), /42/);
  assert.equal(readFileSync(database).subarray(0, 16).toString(), "SQLite format 3\0");
  assert.equal(existsSync(join(directory, "ambient.sqlite")), false);
  console.log("DBHub MCP, persistent local SQLite and explicit config isolation checks passed.");
} finally {
  rmSync(directory, { recursive: true, force: true });
}
