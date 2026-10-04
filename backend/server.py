#!/usr/bin/env python3
"""dmjl_port - CN Phase 1 backend.

Usage:  python3 backend/server.py A 3001    (Mac 3)
        python3 backend/server.py B 3002    (Mac 4)

Endpoints:
  GET /            -> JSON confirming the service is running
  GET /api/status  -> {"backend": "A", "status": "ok"}
Every response carries an X-Backend header.
/api/status also sends Cache-Control + ETag and answers 304 Not Modified
to a conditional request (If-None-Match).
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND_ID = sys.argv[1] if len(sys.argv) > 1 else "A"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 3001

# Version tag of the /api/status resource. Both replicas serve version v1,
# so a client can revalidate against whichever backend round robin picks.
STATUS_ETAG = '"status-v1"'


class Handler(BaseHTTPRequestHandler):
    server_version = "dmjl-backend/1.0"

    def send_json(self, code, payload, cache=False):
        body = json.dumps(payload).encode()
        self.send_response(code)  # also adds Date + Server headers
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Backend", BACKEND_ID)
        if cache:
            self.send_header("Cache-Control", "public, max-age=60")
            self.send_header("ETag", STATUS_ETAG)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self.send_json(200, {"service": "dmjl_port",
                                 "backend": BACKEND_ID,
                                 "message": "Backend %s is running" % BACKEND_ID})
        elif self.path == "/api/status":
            if self.headers.get("If-None-Match") == STATUS_ETAG:
                # Client's cached copy is still valid: no body
                self.send_response(304)
                self.send_header("X-Backend", BACKEND_ID)
                self.send_header("Cache-Control", "public, max-age=60")
                self.send_header("ETag", STATUS_ETAG)
                self.end_headers()
                return
            self.send_json(200, {"backend": BACKEND_ID, "status": "ok"},
                           cache=True)
        else:
            self.send_json(404, {"error": "not found", "backend": BACKEND_ID})

    def do_HEAD(self):
        self.do_GET()


if __name__ == "__main__":
    # 0.0.0.0 = every interface, so nginx on Mac 2 can reach us over the LAN
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("Backend %s listening on 0.0.0.0:%d" % (BACKEND_ID, PORT), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nBackend %s stopped" % BACKEND_ID)
