import type { ExtensionAPI, McpServerConfig } from "@earendil-works/pi-coding-agent";
import { accessSync, constants, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";

export default function services(pi: ExtensionAPI) {
  const servers: Record<string, McpServerConfig> = JSON.parse(
    readFileSync(new URL("./servers.json", import.meta.url), "utf8"),
  );
  for (const [name, server] of Object.entries(servers)) {
    if ("command" in server) {
      const command = server.command.startsWith("~/")
        ? join(homedir(), server.command.slice(2))
        : server.command;
      const candidates = command.includes("/")
        ? [command]
        : (process.env.PATH || "").split(delimiter).filter(Boolean).map((directory) =>
          join(directory, command)
        );
      if (
        !candidates.some((candidate) => {
          try {
            accessSync(candidate, constants.X_OK);
            return true;
          } catch {
            return false;
          }
        })
      ) continue;
    }
    pi.registerMcpServer(name, { ...server, exposure: "codemode" });
  }
}
