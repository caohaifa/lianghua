"""
Flutter Web 开发用静态服务器
与 python -m http.server 的区别:对所有响应强制 no-cache,
避免 main.dart.js / flutter_bootstrap.js 被浏览器缓存导致"改了代码却看到旧页面"。

用法:
    python serve.py [端口]
默认端口 8090,服务目录为本脚本同级的 build/web。
"""
import sys
import http.server
import functools
import os
import socketserver

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main():
    handler = functools.partial(NoCacheHandler)
    with ReusableTCPServer(("", PORT), handler) as httpd:
        print(f"Serving {DIRECTORY} at http://localhost:{PORT} (no-cache)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")


if __name__ == "__main__":
    main()
