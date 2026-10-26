#!/usr/bin/env python3
"""A small readiness demonstration; never returns the OpenBao secret."""

import html
import http.server
import json
import os
from pathlib import Path

SECRET = Path("/run/openbao/probe.json")


def ready() -> bool:
    try:
        with SECRET.open("rb") as stream:
            content = stream.read(4097)
        if len(content) > 4096:
            return False
        value = json.loads(content)
        return (
            isinstance(value, dict)
            and set(value) == {"value"}
            and isinstance(value["value"], str)
            and 20 <= len(value["value"]) <= 256
        )
    except (OSError, ValueError, TypeError):
        return False


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path not in ("/", "/healthz"):
            self.send_error(404)
            return
        healthy = ready()
        if self.path == "/healthz":
            body = json.dumps({"ready": healthy}).encode()
            content_type = "application/json"
        else:
            state = "geladen" if healthy else "nog niet beschikbaar"
            pod = html.escape(os.environ.get("POD_NAME", "poc"))
            body = f"""<!doctype html>
<html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>PowerLAN K3s POC</title>
<style>body{{font:18px system-ui;background:#172334;color:#edf2f7;max-width:48rem;margin:5rem auto;padding:1.5rem}}article{{border:1px solid #50617a;border-radius:12px;padding:1.5rem}}h1{{margin-top:0}}code{{overflow-wrap:anywhere}}a{{color:#9fd7ff}}</style>
<article><h1>PowerLAN K3s POC</h1><p>De testapp draait in Kubernetes.</p>
<p>OpenBao-geheim: <strong>{state}</strong>. De waarde wordt niet getoond.</p>
<p>Pod: <code>{pod}</code></p>
<p>CTB, het huishoudboekje en de receptenapp worden later afzonderlijk uitgerold.</p>
<a href="https://home.powerlan.empire/">Terug naar Homepage</a></article></html>""".encode()
            content_type = "text/html; charset=utf-8"
        self.send_response(200 if healthy else 503)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_: object) -> None:
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()  # noqa: S104 -- Pod listener behind the ingress and NetworkPolicy.
