"""Local preview server for the VigilDesk docs site (stdlib http.server).

Usage (from repo root or this directory):

    python docs-site/serve.py            # serve docs-site/ on http://127.0.0.1:8080
    python docs-site/serve.py --port 9000
    python docs-site/serve.py --root path/to/site

Zero external dependencies. Binds loopback only.
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parent
DEFAULT_PORT = 8080


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="VigilDesk docs-site local preview")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="site root directory")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="port to listen on")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    handler = partial(SimpleHTTPRequestHandler, directory=str(root))
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
