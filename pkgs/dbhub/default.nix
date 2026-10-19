{
  fetchFromGitHub,
  fetchPnpmDeps,
  lib,
  makeWrapper,
  nodejs_24,
  pnpm_12,
  pnpmConfigHook,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dbhub";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "bytebase";
    repo = "dbhub";
    tag = "v${finalAttrs.version}";
    hash = "sha256-R7lO0FrUYxppVZ4B5bKD54EnT7apPwJG2GwDSoy8qd0=";
  };
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-0tWTTWrRjuQyU7R1/93oM9UseRDVWbVg8tAnjm8ltUw=";
  };
  nativeBuildInputs = [nodejs_24 pnpm_12 pnpmConfigHook makeWrapper];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    pnpm --filter dbhub deploy --prod --offline --ignore-scripts "$out/lib/dbhub"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/dbhub" \
      --add-flags "$out/lib/dbhub/dist/index.js"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${nodejs_24}/bin/node --input-type=module - "$out/bin/dbhub" <<'JS'
    import assert from "node:assert/strict";
    import { spawnSync } from "node:child_process";
    const messages = [
      { id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "nixcfg-check", version: "1" } } },
      { method: "notifications/initialized" },
      { id: 2, method: "tools/list", params: {} },
      { id: 3, method: "tools/call", params: { name: "execute_sql", arguments: { sql: "SELECT 42 AS answer" } } },
    ];
    const result = spawnSync(process.argv[2], ["--transport", "stdio", "--dsn", "sqlite:///:memory:"], {
      input: messages.map(message => JSON.stringify({ jsonrpc: "2.0", ...message })).join("\n") + "\n",
      encoding: "utf8", timeout: 15000, cwd: process.env.TMPDIR,
    });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stderr);
    const replies = result.stdout.trim().split("\n").map(line => JSON.parse(line));
    assert.equal(replies.find(reply => reply.id === 1).result.serverInfo.version, "${finalAttrs.version}");
    const tools = replies.find(reply => reply.id === 2).result.tools.map(tool => tool.name);
    assert.ok(tools.includes("execute_sql") && tools.includes("search_objects"));
    const query = replies.find(reply => reply.id === 3).result;
    assert.ok(!query.isError, JSON.stringify(query));
    assert.match(JSON.stringify(query.content), /42/);
    console.log("DBHub MCP initializes and executes SQL using an in-memory database.");
    JS
    runHook postInstallCheck
  '';

  meta = {
    description = "Database MCP server for PostgreSQL, MySQL, MariaDB, SQL Server, Oracle and SQLite";
    homepage = "https://dbhub.ai";
    license = lib.licenses.mit;
    mainProgram = "dbhub";
    platforms = lib.platforms.linux;
  };
})
