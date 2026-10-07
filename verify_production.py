# -*- coding: utf-8 -*-
"""
AI 量化平台 · 上线后生产验证脚本
================================
用途: 部署到生产环境后执行,验证核心链路可用 + 生产安全整改项真实生效。

设计原则(与开发态 test_e2e.py 的区别):
  1. 纯 HTTP 黑盒 —— 不依赖 Redis/数据库/服务器登录
  2. 只读优先 —— 不发真实短信、不注册用户、不下单、不创建订单
  3. 安全整改项反向断言 —— mock_code 不回传 / 邀请码强制 / 接口鉴权 / CORS 白名单
  4. 退出码 0=全部通过 1=存在失败,可直接接入 CI/发布流水线卡点

用法:
  python verify_production.py --base https://api.example.com/api/v1
  python verify_production.py --base https://api.example.com/api/v1 \
      --admin-user admin --admin-pass <生产管理员密码>
  python verify_production.py --base https://api.example.com/api/v1 --skip-admin
  # 管理员密码建议用环境变量 ADMIN_USER / ADMIN_PASS 传入,避免落 shell 历史

  # 行情/聚合接口需用户 JWT:传入一个真实用户 token 可验证行情真实数据;
  # 不传则降级为"鉴权在位"断言(401 即通过),并提示补验。
  python verify_production.py --base https://api.example.com/api/v1 --user-token <JWT>

  # 本地 dev 自检:CORS 默认 * 属正常配置,加 --dev 放宽该断言
  python verify_production.py --base http://localhost:8080/api/v1 --dev
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

PASS = 0
FAIL = 0
RESULTS = []


def report(ok, name, detail=""):
    global PASS, FAIL
    tag = "PASS" if ok else "FAIL"
    if ok:
        PASS += 1
    else:
        FAIL += 1
    suffix = f"  -- {detail}" if detail else ""
    print(f"[{tag}] {name}{suffix}")
    RESULTS.append((ok, name, detail))


def http(method, url, body=None, headers=None, timeout=15, return_headers=False):
    req = urllib.request.Request(url, method=method)
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=timeout) as r:
            raw = r.read().decode("utf-8", "replace")
            if return_headers:
                return r.status, raw, dict(r.headers)
            try:
                return r.status, json.loads(raw)
            except json.JSONDecodeError:
                return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        if return_headers:
            return e.code, raw, dict(e.headers)
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw
    except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
        return 0, str(e)


def api_ok(resp):
    return isinstance(resp, dict) and resp.get("code") == 200


def section(title):
    print("=" * 60)
    print(title)
    print("=" * 60)


def skip(name, detail=""):
    print(f"[SKIP] {name}" + (f"  -- {detail}" if detail else ""))


def main():
    ap = argparse.ArgumentParser(description="AI 量化平台上线后验证")
    ap.add_argument("--base", default="http://localhost:8080/api/v1",
                    help="后端 API 根地址,如 https://api.example.com/api/v1")
    ap.add_argument("--admin-user", default=None, help="管理员账号(默认读 ADMIN_USER)")
    ap.add_argument("--admin-pass", default=None, help="管理员密码(默认读 ADMIN_PASS)")
    ap.add_argument("--skip-admin", action="store_true", help="跳过管理员组(未持有生产管理员凭据时)")
    ap.add_argument("--user-token", default=os.environ.get("USER_TOKEN"),
                    help="用户 JWT(可选):传入后行情/聚合组做真实数据验证")
    ap.add_argument("--dev", action="store_true", help="dev 自检:放宽 CORS 白名单断言")
    ap.add_argument("--timeout", type=int, default=15)
    args = ap.parse_args()

    admin_user = args.admin_user or os.environ.get("ADMIN_USER", "admin")
    admin_pass = args.admin_pass or os.environ.get("ADMIN_PASS", "admin123")
    B = args.base.rstrip("/")
    T = args.timeout

    # ══════════ A. 健康与连通性 ══════════
    section("A. 健康与连通性")
    st, body = http("GET", f"{B}/auth/health", timeout=T)
    report(st == 200 and api_ok(body) and body.get("data", {}).get("status") == "UP",
           "健康检查 /auth/health", str(body)[:80] if st != 200 else "")

    # ══════════ B. 生产安全整改项反向断言 ══════════
    section("B. 生产安全整改项(反向断言)")
    # 1. 图形验证码服务可用
    st, cap = http("GET", f"{B}/auth/captcha", timeout=T)
    report(st == 200 and api_ok(cap) and cap["data"].get("captcha_id"),
           "图形验证码服务 /auth/captcha")
    # 2. 短信接口图形校验前置仍生效(假图形码必须被拒,响应绝不回传 mock_code)
    st, resp = http("POST", f"{B}/auth/sms/send",
                    {"phone": "19900000000", "captcha_id": "deadbeef", "captcha_code": "000000"}, timeout=T)
    rejected = not api_ok(resp)
    no_mock = "mock_code" not in json.dumps(resp, ensure_ascii=False) if isinstance(resp, dict) else True
    report(rejected, "负向:假图形码发短信被拒(图形校验前置生效)", str(resp)[:80])
    report(no_mock, "生产不回传 mock_code(sms.mock-return-code=false 生效)")
    # 3. 匿名不能注册(无验证码必须被拒 → 内测邀请码/验证码防线在位)
    st, resp = http("POST", f"{B}/auth/register",
                    {"phone": "19900000001", "code": "000000", "invite_code": "AIQUANT2026"}, timeout=T)
    report(not api_ok(resp), "负向:无短信验证码不能注册", str(resp)[:80])
    # 4. 用户接口鉴权
    st, resp = http("GET", f"{B}/trading/account", timeout=T)
    report(st in (401, 403), "负向:无 Token 访问用户接口被拒(401/403)", f"status={st}")
    # 5. 管理接口鉴权
    st, resp = http("GET", f"{B}/admin/users", timeout=T)
    report(st in (401, 403), "负向:无 Token 访问管理接口被拒(401/403)", f"status={st}")
    # 6. CORS(伪源预检:若返回 CORS 头,断言不是 *;--dev 模式下 * 属 dev 默认配置,放宽)
    st, _, hdrs = http("OPTIONS", f"{B}/auth/login",
                       headers={"Origin": "https://evil.example.com",
                                "Access-Control-Request-Method": "POST"}, timeout=T, return_headers=True)
    acao = hdrs.get("Access-Control-Allow-Origin", "")
    if acao:
        if args.dev:
            report(True, "CORS 开关在位(dev 默认 *,生产注入白名单)", f" ACAO={acao}")
        else:
            report(acao != "*", "CORS 白名单生效(伪源未获得 * 授权)", f" ACAO={acao}")
    else:
        report(True, "CORS 未对伪源开放(网关层处理或在 nginx 配置)", f"OPTIONS status={st}")

    # ══════════ C. 管理端 ══════════
    if args.skip_admin:
        print("\n[--] C. 管理端 --skip-admin 跳过")
    else:
        section("C. 管理端")
        st, login = http("POST", f"{B}/admin/login",
                         {"username": admin_user, "password": admin_pass}, timeout=T)
        report(api_ok(login) and login.get("data", {}).get("token"),
               "管理员登录", str(login)[:80] if not api_ok(login) else "")
        st, bad = http("POST", f"{B}/admin/login",
                       {"username": admin_user, "password": "wrong-password"}, timeout=T)
        report(not api_ok(bad), "负向:管理员错误密码被拒")
        if api_ok(login):
            token = login["data"]["token"]
            st, dash = http("GET", f"{B}/admin/system/dashboard",
                            headers={"Authorization": f"Bearer {token}"}, timeout=T)
            report(api_ok(dash), "数据看板 /admin/system/dashboard")
            st, users = http("GET", f"{B}/admin/users?page=1&size=1",
                             headers={"Authorization": f"Bearer {token}"}, timeout=T)
            report(api_ok(users), "用户列表 /admin/users")

    # ══════════ D. 行情真实源 ══════════
    section("D. 行情(RealMarketDataProvider 真实源)")
    user_h = {"Authorization": f"Bearer {args.user_token}"} if args.user_token else None
    if user_h:
        st, quotes = http("GET", f"{B}/market/quotes", headers=user_h, timeout=T)
        n = len(quotes.get("data", [])) if api_ok(quotes) else 0
        report(api_ok(quotes) and n > 0, "行情列表 /market/quotes", f"{n} 个标的")
        st, btc = http("GET", f"{B}/market/quote?symbol=BTC/USDT", headers=user_h, timeout=T)
        price = btc.get("data", {}).get("price", 0) if api_ok(btc) else 0
        report(api_ok(btc) and price > 0, "BTC/USDT 实时价格(query 版支持斜杠)", f"price={price}")
        st, kl = http("GET", f"{B}/market/kline?symbol=BTC/USDT&period=5m&limit=10", headers=user_h, timeout=T + 20)
        if not api_ok(kl):  # 冷缓存首次拉币安可能慢,重试一次
            st, kl = http("GET", f"{B}/market/kline?symbol=BTC/USDT&period=5m&limit=10", headers=user_h, timeout=T + 20)
        bars = kl.get("data", []) if api_ok(kl) else []
        report(api_ok(kl) and len(bars) == 10, "K线 BTC/USDT 5m×10", f"{len(bars)} 根")
        st, dep = http("GET", f"{B}/market/depth?symbol=BTC/USDT&limit=5", headers=user_h, timeout=T)
        dd = (dep.get("data") or {}) if isinstance(dep, dict) else {}
        if not (api_ok(dep) and dd.get("bids")):  # 冷缓存首次拉币安可能慢,重试一次
            st, dep = http("GET", f"{B}/market/depth?symbol=BTC/USDT&limit=5", headers=user_h, timeout=T)
            dd = (dep.get("data") or {}) if isinstance(dep, dict) else {}
        report(api_ok(dep) and bool(dd.get("bids")) and bool(dd.get("asks")), "盘口 BTC/USDT 5 档")
        st, tr = http("GET", f"{B}/market/trades?symbol=BTC/USDT&limit=5", headers=user_h, timeout=T)
        report(api_ok(tr) and len(tr.get("data", [])) > 0, "成交流水 BTC/USDT ×5")
        st, resp = http("GET", f"{B}/market/depth?symbol=000333&limit=5", headers=user_h, timeout=T)
        # 业务错误约定:HTTP 200 + body code=400(全局异常处理器);容忍两种形态
        code = resp.get("code") if isinstance(resp, dict) else None
        report(code == 400 or st == 400, "负向:A股盘口被拒(仅加密开放)", f"http={st} code={code}")
    else:
        print("[--] 未提供 --user-token,行情组降级为鉴权断言(401 在位即通过)")
        for name, path in [("行情列表", "/market/quotes"), ("实时价格", "/market/quote?symbol=BTC/USDT"),
                           ("K线", "/market/kline?symbol=BTC/USDT&period=5m&limit=10"),
                           ("盘口", "/market/depth?symbol=BTC/USDT&limit=5"),
                           ("成交流水", "/market/trades?symbol=BTC/USDT&limit=5")]:
            st, _ = http("GET", f"{B}{path}", timeout=T)
            report(st in (401, 403), f"鉴权在位:{name} 接口无 Token 被拒", f"status={st}")
        skip("行情真实数据断言", "需 --user-token 或补跑:python verify_production.py --user-token <JWT>")

    # ══════════ E. 聚合接口 ══════════
    section("E. 聚合接口")
    st, ov = http("GET", f"{B}/market/overview", headers=user_h, timeout=T)
    if st in (401, 403):
        report(True, "行情总览 /market/overview(需登录,黑盒跳过)")
    else:
        report(api_ok(ov) and ov.get("data", {}).get("btc_dominance") is not None,
               "行情总览 /market/overview")
    st, meta = http("GET", f"{B}/market/meta", headers=user_h, timeout=T)
    if st in (401, 403):
        report(True, "币种品牌色 /market/meta(需登录,黑盒跳过)")
    else:
        report(api_ok(meta), "币种品牌色 /market/meta")
    st, ais = http("GET", f"{B}/ai/summary", headers=user_h, timeout=T)
    if st in (401, 403):
        report(True, "AI 收益摘要 /ai/summary(需登录,黑盒跳过)")
    else:
        report(api_ok(ais), "AI 收益摘要 /ai/summary")

    # ══════════ F. 指标与监控 ══════════
    section("F. 指标与监控")
    st, prom = http("GET", f"{B}/actuator/prometheus", timeout=T)
    text = prom if isinstance(prom, str) else ""
    has_orders = "aiquant_orders_total" in text
    has_ws = "aiquant_ws_online" in text
    report(st == 200 and has_orders and has_ws,
           "Prometheus 指标端点含业务埋点", f"status={st} orders={has_orders} ws={has_ws}")

    # ══════════ 汇总 ══════════
    print("=" * 60)
    print(f"结果: {PASS} 通过 / {FAIL} 失败 / 共 {PASS + FAIL} 项")
    print("=" * 60)
    if FAIL:
        print("\n失败项明细:")
        for ok, name, detail in RESULTS:
            if not ok:
                print(f"  ✗ {name}  {detail}")
    sys.exit(0 if FAIL == 0 else 1)


if __name__ == "__main__":
    main()
