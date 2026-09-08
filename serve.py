#!/usr/bin/env python3
"""
DENTRA Flutter Web server with Cross-Origin-Isolation headers.
Required for Skwasm (WebAssembly) multithreading in Firefox.
"""
import http.server
import os

PORT = 8080
BUILD_DIR = os.path.join(os.path.dirname(__file__), 'build', 'web')

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BUILD_DIR, **kwargs)

    def end_headers(self):
        # Required for SharedArrayBuffer / Wasm multithreading
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def log_message(self, format, *args):
        pass  # Suppress access logs

if __name__ == '__main__':
    with http.server.HTTPServer(('', PORT), CORSHandler) as httpd:
        print(f'DENTRA running at http://localhost:{PORT}')
        httpd.serve_forever()
