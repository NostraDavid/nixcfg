"""Check the installed MCP server without downloading an embedding model."""

import json
import os
import select
import subprocess
import sys
import tempfile
import time


def main() -> None:
    env = os.environ | {"HF_HUB_OFFLINE": "1"}
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            [sys.argv[1]],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=errors,
            env=env,
            bufsize=0,
        )
        assert process.stdin is not None and process.stdout is not None

        def send(message: dict) -> None:
            process.stdin.write(
                json.dumps({"jsonrpc": "2.0", **message}).encode() + b"\n"
            )

        def response(identifier: int) -> dict:
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                ready, _, _ = select.select(
                    [process.stdout], [], [], max(0, deadline - time.monotonic())
                )
                if not ready:
                    break
                line = process.stdout.readline()
                if not line:
                    errors.seek(0)
                    raise AssertionError(errors.read().decode(errors="replace"))
                result = json.loads(line)
                if result.get("id") == identifier:
                    assert "error" not in result, result
                    return result["result"]
            raise AssertionError("MCP server did not respond within 30 seconds")

        try:
            send(
                {
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-11-25",
                        "capabilities": {},
                        "clientInfo": {"name": "nixcfg-install-check", "version": "1"},
                    },
                }
            )
            assert response(1)["serverInfo"]["name"] == "semble"
            send({"method": "notifications/initialized"})
            send({"id": 2, "method": "tools/list", "params": {}})
            names = {tool["name"] for tool in response(2)["tools"]}
            assert {"search", "find_related"} <= names, names
            print(
                "PASS: Semble MCP initializes and exposes search tools without network access"
            )
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
