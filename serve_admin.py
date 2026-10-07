# -*- coding: utf-8 -*-
"""
管理后台静态服务器(带 API 反代)
- 静态托管 admin_web/dist
- /api/v1/* 反向代理到后端 8080(替代 nginx 反代,供本地生产态预览)
用法: python serve_admin.py [port] [dist_dir]
"""
import sys
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8889
DIST = sys.argv[2] if len(sys.argv) > 2 else "d:/Lh/lianghua/admin_web/dist"
BACKEND = "http://localhost:8080"
HOP_HEADERS = {"connection", "keep-alive", "transfer-encoding", "upgrade",
               "proxy-authenticate", "proxy-authorization", "te", "trailers"}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIST, **kwargs)

    def _proxy(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else None
        url = BACKEND + self.path
        req = urllib.request.Request(url, data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in HOP_HEADERS and k.lower() != "host":
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                payload = r.read()
                self.send_response(r.status)
                for k, v in r.headers.items():
                    if k.lower() not in HOP_HEADERS:
                        self.send_header(k, v)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as e:
            payload = e.read()
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in HOP_HEADERS:
                    self.send_header(k, v)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as ex:
            self.send_response(502)
            msg = str(ex).encode()
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def do_POST(self):
        if self.path.startswith("/api/"):
            self._proxy()
        else:
            self.send_error(404)

    def do_GET(self):
        if self.path.startswith("/api/"):
            self._proxy()
        else:
            super().do_GET()

    def do_PUT(self):
        self._proxy() if self.path.startswith("/api/") else self.send_error(404)

    def do_DELETE(self):
        self._proxy() if self.path.startswith("/api/") else self.send_error(404)

    def do_OPTIONS(self):
        self._proxy() if self.path.startswith("/api/") else self.send_response(204), self.end_headers()

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
