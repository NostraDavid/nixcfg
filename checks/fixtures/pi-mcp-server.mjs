import { createInterface } from "node:readline";

createInterface({ input: process.stdin }).on("line", (line) => {
  const request = JSON.parse(line);
  if (request.id === undefined) return;
  const result = request.method === "initialize"
    ? {
      protocolVersion: request.params.protocolVersion,
      capabilities: { tools: {} },
      serverInfo: { name: "pi-parity-fixture", version: "1.0.0" },
    }
    : request.method === "tools/list"
    ? {
      tools: [{
        name: "fixture_echo",
        description: "Local integration fixture",
        inputSchema: { type: "object" },
      }],
    }
    : {};
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: request.id, result })}\n`);
});
