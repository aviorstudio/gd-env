#!/usr/bin/env python3
import http.server
import json
import pathlib
import socketserver
import sys

root = pathlib.Path(sys.argv[1]).resolve()
port = int(sys.argv[2])

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=root, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def do_GET(self):
        if self.path in ("/small.json", "/oversized.json", "/custom.json"):
            padding = "ok" if self.path == "/small.json" else "x" * (1024 * 1024 + 4096)
            body = json.dumps({"padding": padding}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

with socketserver.TCPServer(("127.0.0.1", port), Handler) as server:
    server.serve_forever()
