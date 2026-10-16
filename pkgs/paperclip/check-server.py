"""Start an isolated instance and check its database, API, and bundled UI."""

import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def main() -> None:
    with tempfile.TemporaryDirectory() as home, tempfile.TemporaryFile() as log:
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("PAPERCLIP_") and key != "DATABASE_URL"
        }
        env.update(
            HOME=home,
            PAPERCLIP_HOME=f"{home}/state",
            PAPERCLIP_NO_BROWSER="1",
            PAPERCLIP_UPDATE_CHECK="0",
            PAPERCLIP_SERVER_PORT=str(port),
            PORT=str(port),
            DO_NOT_TRACK="1",
        )
        process = subprocess.Popen(
            [sys.argv[1], "onboard", "--yes", "--no-install-service"],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
            start_new_session=True,
        )
        try:
            base_url = f"http://127.0.0.1:{port}"
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline and process.poll() is None:
                try:
                    with opener.open(f"{base_url}/api/health", timeout=2) as r:
                        if json.load(r)["status"] == "ok":
                            break
                except (urllib.error.URLError, TimeoutError):
                    pass
                time.sleep(0.25)
            else:
                log.seek(0)
                raise AssertionError(
                    f"Server exit code: {process.poll()}\n"
                    + log.read().decode(errors="replace")
                )
            with opener.open(base_url, timeout=5) as r:
                assert r.status == 200 and b"<html" in r.read().lower()
            print("PASS: Paperclip starts with PostgreSQL and serves its API and UI")
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()


if __name__ == "__main__":
    main()
