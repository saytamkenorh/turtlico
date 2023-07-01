#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler, test
import ssl
import sys
import os

class RequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, request, client_address, server) -> None:
        directory = os.curdir
        super().__init__(request, client_address, server, directory=directory)

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        SimpleHTTPRequestHandler.end_headers(self)

if __name__ == '__main__':
    httpd = HTTPServer(('0.0.0.0', 8000), RequestHandler)

    cert_file = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                             "cert.pem")
    key_file = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            "key.pem")

    protocol = "http"
    # If you want to access the server from another device (e.g. a phone) the webpage must be accessed via https
    # To obtain a self-signed cert run:
    # openssl req -new -x509 -keyout key.pem -out cert.pem -days 365 -nodes
    if os.path.isfile(cert_file) and os.path.isfile(key_file):
        ctx = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cert_file, key_file)
        httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
        protocol = "https"
    print("Serving at: {}://{}:{}".format(protocol, httpd.server_address[0], httpd.server_port))

    httpd.serve_forever()
