#!/usr/bin/env python3
import _socket
from http.server import HTTPServer, SimpleHTTPRequestHandler, test
import sys
import os

class RequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, request, client_address, server) -> None:
        directory = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                 "dist")
        super().__init__(request, client_address, server, directory=directory)

    def end_headers(self):
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    test(RequestHandler, HTTPServer, port=int(sys.argv[1]) if len(sys.argv) > 1 else 8000)