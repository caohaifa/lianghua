# -*- coding: utf-8 -*-
"""开发用:no-cache 静态服务器托管 Flutter Web 构建产物,避免浏览器/Service Worker 缓存旧版本。
用法: python serve_nocache.py [port] [directory]
"""
import functools
import http.server
import socketserver
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
directory = sys.argv[2] if len(sys.argv) > 2 else "build/web"


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_GET(self):
        # 给引导文件中的 main.dart.js 引用加版本参数(?v=mtime_ns):
        # 浏览器 HTTP 缓存可能持有无条件命中的旧 main.dart.js,URL 变化即强制拉新。
        rel = self.path.split("?", 1)[0].lstrip("/")
        base = rel.split("/")[-1]
        if base in ("flutter_bootstrap.js", "index.html", ""):
            fpath = self.translate_path(self.path)
            try:
                import os
                if os.path.isdir(fpath):
                    fpath = os.path.join(fpath, "index.html")
                base = os.path.basename(fpath)
                with open(fpath, "rb") as f:
                    text = f.read().decode("utf-8")
                if base == "index.html":
                    # 版本化 bootstrap,防止旧 flutter_bootstrap.js HTTP 缓存
                    bs = os.path.join(os.path.dirname(fpath), "flutter_bootstrap.js")
                    bver = str(os.stat(bs).st_mtime_ns)
                    text = text.replace('"flutter_bootstrap.js"',
                                        f'"flutter_bootstrap.js?v={bver}"')
                else:
                    # 版本化入口 JS,防止旧 main.dart.js HTTP 缓存
                    main_js = os.path.join(os.path.dirname(fpath), "main.dart.js")
                    ver = str(os.stat(main_js).st_mtime_ns)
                    text = text.replace('"main.dart.js"',
                                        f'"main.dart.js?v={ver}"')
                body = text.encode("utf-8")
                ctype = self.guess_type(fpath)
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            except FileNotFoundError:
                pass
        super().do_GET()


handler = functools.partial(NoCacheHandler, directory=directory)
with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
    print(f"serving {directory} on :{port} (no-cache)")
    httpd.serve_forever()
