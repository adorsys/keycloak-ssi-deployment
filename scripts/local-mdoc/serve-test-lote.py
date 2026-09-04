#!/usr/bin/env python3
import argparse
import http.server
import signal
import ssl
import sys


def main():
    parser = argparse.ArgumentParser(description="Serve the local signed LoTE over HTTPS")
    parser.add_argument("--directory", required=True)
    parser.add_argument("--certificate", required=True)
    parser.add_argument("--private-key", required=True)
    parser.add_argument("--port", type=int, default=9443)
    args = parser.parse_args()

    handler = lambda *handler_args, **kwargs: http.server.SimpleHTTPRequestHandler(
        *handler_args, directory=args.directory, **kwargs
    )
    http.server.ThreadingHTTPServer.allow_reuse_address = True
    server = http.server.ThreadingHTTPServer(("0.0.0.0", args.port), handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.certificate, args.private_key)
    server.socket = context.wrap_socket(server.socket, server_side=True)

    def handle_shutdown(signum, frame):
        try:
            server.server_close()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_shutdown)
    signal.signal(signal.SIGINT, handle_shutdown)

    try:
        server.serve_forever()
    except (KeyboardInterrupt, SystemExit):
        try:
            server.server_close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
