#!/usr/bin/env python3
"""Local server with headers required for SharedArrayBuffer (love.js needs threads)."""
import http.server
import sys
import os

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    # Default to latest output dir, or pass dir as second arg
    serve_dir = sys.argv[2] if len(sys.argv) > 2 else "output-catapult"
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), serve_dir))
    server = http.server.HTTPServer(("", port), CORSHandler)
    print(f"Serving on http://localhost:{port}")
    server.serve_forever()
