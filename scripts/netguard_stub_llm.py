"""A stand-in for LM Studio's OpenAI-compatible API, bound to 127.0.0.1 only.

Used by scripts/network-guard.sh so the Network Guard exercises Dictum's
cleanup path without a real model. Standard library only.

    python3 -I netguard_stub_llm.py <port-file> <request-log>

Picks a free port, writes it to <port-file>, and logs one line per request.
Every chat completion returns REPLY, streamed the way LM Studio streams.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLY = "Network guard stub reply."
MODEL = "netguard-stub"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep stderr quiet
        pass

    def _record(self):
        with open(self.server.request_log, "a", encoding="utf-8") as log:
            log.write(f"{self.command} {self.path} from {self.client_address[0]}\n")

    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._record()
        if self.path.rstrip("/") == "/v1/models":
            self._json(200, {"object": "list", "data": [{"id": MODEL, "object": "model"}]})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        self._record()
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length) or b"{}")
        if self.path.rstrip("/") != "/v1/chat/completions":
            self._json(404, {"error": "not found"})
            return
        if not request.get("stream"):
            self._json(200, {"choices": [{"message": {"role": "assistant", "content": REPLY}}]})
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for piece in REPLY.split(" "):
            chunk = {"choices": [{"delta": {"content": piece + " "}}]}
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")


def main():
    port_file, request_log = sys.argv[1], sys.argv[2]
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.request_log = request_log
    with open(port_file, "w", encoding="utf-8") as f:
        f.write(str(server.server_address[1]))
    server.serve_forever()


if __name__ == "__main__":
    main()
