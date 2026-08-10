#!/usr/bin/env python3
"""Minimal stand-in for the Home Assistant Supervisor API.

Only exists so the add-on image can be exercised on a plain Docker host. bashio
reads the add-on options and metadata from the Supervisor API rather than from
/data/options.json, so without something answering on http://supervisor the s6
init chain stops before any of our own services start.

Serves the handful of endpoints the base image and this add-on actually call.
Not a simulation of the Supervisor -- anything unknown returns an empty ok.
"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

OPTIONS_FILE = os.environ.get("OPTIONS_FILE", "/data/options.json")
INGRESS_PORT = int(os.environ.get("INGRESS_PORT", "7681"))

INFO = {
    "slug": "claude-code",
    "name": "Claude Code",
    "hostname": "local-claude-code",
    "version": "0.1.0",
    "version_latest": "0.1.0",
    "state": "started",
    "ingress": True,
    "ingress_port": INGRESS_PORT,
    "ingress_entry": "/api/hassio_ingress/testtoken",
    "protected": True,
    "arch": ["amd64", "aarch64"],
}


def options():
    try:
        with open(OPTIONS_FILE, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


class Handler(BaseHTTPRequestHandler):
    def _send(self, payload):
        body = json.dumps({"result": "ok", "data": payload}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 - required by BaseHTTPRequestHandler
        path = self.path.split("?")[0].rstrip("/")
        if path in ("/addons/self/options/config", "/apps/self/options/config"):
            self._send(options())
        elif path in ("/addons/self/info", "/apps/self/info"):
            self._send(INFO)
        elif path == "/info":
            self._send({"supervisor": "2026.07.5", "homeassistant": "2026.8.1",
                        "arch": "amd64", "machine": "qemux86-64"})
        elif path == "/supervisor/info":
            self._send({"version": "2026.07.5", "arch": "amd64",
                        "logging": "info", "addons": []})
        elif path == "/core/info":
            self._send({"version": "2026.8.1", "arch": "amd64"})
        else:
            self._send({})

    do_POST = do_GET

    def log_message(self, fmt, *args):
        print("supervisor-stub: " + fmt % args, flush=True)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
