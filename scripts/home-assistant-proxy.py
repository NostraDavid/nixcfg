#!/usr/bin/env python3
"""Configure and confirm the existing Home Assistant HTTP proxy through its API."""

import argparse
import asyncio
import os
from pathlib import Path

import aiohttp

PROXY = "192.168.2.111/32"
META = {"created_at", "error", "error_message"}


def proxy_config(config: dict) -> dict:
    result = {k: v for k, v in config.items() if k not in META}
    result["use_x_forwarded_for"] = True
    result["trusted_proxies"] = list(
        dict.fromkeys([*config.get("trusted_proxies", []), PROXY])
    )
    return result


async def request(
    connection: aiohttp.ClientWebSocketResponse,
    sequence: int,
    kind: str,
    **values: object,
) -> dict:
    await connection.send_json({"id": sequence, "type": kind, **values})
    while True:
        reply = await connection.receive_json()
        if reply.get("id") == sequence:
            if not reply.get("success"):
                raise ValueError(
                    f"Home Assistant rejected {kind}: {reply.get('error', {}).get('code')}"
                )
            return reply.get("result")


async def main(command: str) -> None:
    path = Path(os.environ["SUPERVISOR_CORE_API_SOCKET"])
    if not path.is_absolute() or not await asyncio.to_thread(path.is_socket):
        raise ValueError("Expected the existing local Supervisor administration socket")
    async with (
        aiohttp.ClientSession(
            connector=aiohttp.UnixConnector(path=str(path))
        ) as session,
        session.ws_connect(
            "http://localhost/api/websocket", receive_timeout=15
        ) as connection,
    ):
        if (await connection.receive_json())["type"] != "auth_ok":
            raise ValueError("Local Supervisor authentication failed")
        state = await request(connection, 1, "http/config")
        stable = state["stable"]
        pending = state["pending"]
        desired = proxy_config(stable)
        if command == "configure":
            if pending is not None:
                raise ValueError("An existing pending HTTP configuration needs review")
            if {k: v for k, v in stable.items() if k not in META} == desired:
                print("Home Assistant already trusts the PowerLAN proxy")
                return
            result = await request(
                connection, 2, "http/config/configure", config=desired
            )
            print(
                f"PowerLAN proxy configured; automatic restart: {result['restart']}. Verify HTTPS before confirm."
            )
        else:
            if pending is not None:
                if (
                    state["active_config_type"] != "pending"
                    or pending.get("error")
                    or {k: v for k, v in pending.items() if k not in META} != desired
                ):
                    raise ValueError(
                        "The active pending configuration does not match the requested proxy"
                    )
                await request(connection, 2, "http/config/promote")
                state = await request(connection, 3, "http/config")
            if state["pending"] is not None or proxy_config(state["stable"]) != {
                k: v for k, v in state["stable"].items() if k not in META
            }:
                raise ValueError("The proxy configuration has not been confirmed")
            print("PowerLAN proxy configuration confirmed and persisted")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("configure", "confirm"))
    asyncio.run(main(parser.parse_args().command))
