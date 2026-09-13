"""Local preview server for the VigilDesk site — 404-correct, stdlib only.

`python -m http.server` answers a missing path with its own bare error page; this
server answers it with the branded site 404.html **and** keeps the real HTTP 404
status, so local previews match GitHub Pages behaviour.

Usage (from this directory or with --root):
    python serve.py                  # serve this directory on http://127.0.0.1:8080
    python serve.py --port 9000
    python serve.py --root path/to/site

Binds loopback only. This is a local/Pages artifact — it is NOT wired into the
online stack (run-stack.mjs is deliberately untouched).
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parent
DEFAULT_PORT = 8080
NOT_FOUND_PAGE = "404.html"


class SiteHandler(SimpleHTTPRequestHandler):
    """Static handler that serves 404.html for misses, with status 404."""

    server_version = "VigilDeskSite/1.0"

    def send_error(self, code, message=None, explain=None):
        if code == 404:
            page = Path(self.directory or ".") / NOT_FOUND_PAGE
            if page.is_file():
                body = page.read_bytes()
                self.send_response(404)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(body)
                return
        super().send_error(code, message, explain)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="VigilDesk site local preview")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT,
                        help="site root directory (default: this file's directory)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="port to listen on")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    handler = partial(SiteHandler, directory=str(root))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Serving {root} at http://127.0.0.1:{args.port}/  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
