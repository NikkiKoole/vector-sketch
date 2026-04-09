#!/bin/bash
# Serve a web build with required CORS headers
# Usage: ./serve.sh [port] [scene-name]
# Example: ./serve.sh 8080 catapult

PORT="${1:-8080}"
SCENE="${2:-catapult}"
DIR="$(dirname "$0")/output-${SCENE}"

if [ ! -d "$DIR" ]; then
    echo "Error: $DIR not found. Run build-web.sh $SCENE first."
    exit 1
fi

# Kill anything on this port
lsof -ti:$PORT | xargs kill -9 2>/dev/null
sleep 1

echo "Serving $DIR on http://localhost:$PORT"
cd "$DIR" && exec python3 -c "
import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        super().end_headers()
    def log_message(self, format, *args):
        pass  # quiet
socketserver.TCPServer.allow_reuse_address = True
s = socketserver.TCPServer(('',${PORT}),H)
print('Ready.')
s.serve_forever()
"
