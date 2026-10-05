# -*- coding: utf-8 -*-
"""
AI 量化平台 · 前后端全链路自动化测试
直接模拟客户端调用后端 API(与 Flutter 前端相同接口/请求头),覆盖:
  A. 前端静态服务(Flutter 8090 / Admin 5173)
  B. 用户端认证全链路(图形验证码→短信→注册→登录→刷新→风控→协议→行情)
  C. Python AI 服务(健康/Agent 状态/五因子决策/回测)
  D. 管理端(登录/看板/用户列表/RBAC)

依赖:仅 Python 标准库。Redis 读取走原生 RESP 协议(localhost:6379 嵌入式 Redis)。
用法:python test_e2e.py
"""
import json
import random
import socket
import time
import urllib.request
import urllib.error

JAVA = "http://localhost:8080/api/v1"
AI = "http://localhost:8000"
FLUTTER = "http://localhost:8090"
ADMIN_WEB = "http://localhost:5173"

PASS, FAIL = 0, 0


def report(ok, name, detail=""):
    global PASS, FAIL
    ok = bool(ok)
    PASS, FAIL = PASS + ok, FAIL + (not ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"  -- {detail}" if detail else ""))


def http(method, url, body=None, headers=None, timeout=15):
    """返回 (http_status, json_dict_or_text_or_None)"""
    req = urllib.request.Request(url, method=method)
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data=data, timeout=timeout) as r:
            return r.status, _parse(r.read())
    except urllib.error.HTTPError as e:
        return e.code, _parse(e.read())
    except Exception as e:
        return -1, {"error": str(e)}


def _parse(raw):
    text = raw.decode(errors="replace")
    try:
        return json.loads(text)
    except Exception:
        return {"_text": text}


def redis_get(key):
    """原生 RESP 协议 GET"""
    with socket.create_connection(("localhost", 6379), timeout=5) as s:
        cmd = f"*2\r\n$3\r\nGET\r\n${len(key)}\r\n{key}\r\n"
        s.sendall(cmd.encode())
        buf = b""
        while b"\r\n" not in buf:
            buf += s.recv(1024)
        line, rest = buf.split(b"\r\n", 1)
        if line.startswith(b"$"):
            n = int(line[1:])
            if n < 0:
                return None
            while len(rest) < n:
                rest += s.recv(1024)
            return rest[:n].decode()
        return None


def api_ok(resp):
    return resp and resp.get("code") == 200


def fresh_captcha():
    """取新图形验证码并从 Redis 读出答案(一次性:用后即毁,每次发送前都要新取)"""
    _, cap = http("GET", JAVA + "/auth/captcha")
    cid = cap["data"]["captcha_id"]
    return cid, redis_get("captcha:id:" + cid)


def main():
    print("=" * 60)
    print("A. 前端静态服务")
    print("=" * 60)
    st, body = http("GET", FLUTTER + "/")
    report(st == 200, "Flutter 客户端页面可访问 (8090)")
    st, body = http("GET", FLUTTER + "/main.dart.js")
    report(st == 200, "Flutter main.dart.js 已构建")
    st, body = http("GET", ADMIN_WEB + "/")
    report(st == 200, "管理后台页面可访问 (5173)")

    print("=" * 60)
    print("B. 用户端认证全链路 (Java :8080)")
    print("=" * 60)
    # 1. 图形验证码
    _, cap = http("GET", JAVA + "/auth/captcha")
    ok = api_ok(cap) and cap["data"].get("captcha_id")
    report(ok, "获取图形验证码 /auth/captcha")
    captcha_id = cap["data"]["captcha_id"]
    captcha_code = redis_get("captcha:id:" + captcha_id)
    report(captcha_code is not None, "Redis 中存在图形验证码答案", f"captcha_id={captcha_id[:8]}...")

    # 2. 新手机号走注册全流程
    phone = "139" + "".join(random.choice("0123456789") for _ in range(8))

    # 负向:错误图形码(单独取一张)
    cid, _ = fresh_captcha()
    _, bad = http("POST", JAVA + "/auth/sms/send",
                  {"phone": phone, "captcha_id": cid, "captcha_code": "000000"})
    report(not api_ok(bad), "负向:错误图形码发送短信被拒绝", bad.get("message", ""))

    # 正向:正确图形码(图形码一次性,需重新取)
    cid, ccode = fresh_captcha()
    _, sms = http("POST", JAVA + "/auth/sms/send",
                  {"phone": phone, "captcha_id": cid, "captcha_code": ccode})
    report(api_ok(sms) and sms["data"].get("mock_code"), "发送短信验证码(图形校验通过)",
           "" if api_ok(sms) else str(sms)[:120])
    if not api_ok(sms):
        print("短信发送失败,中止后续注册流程"); return 1
    mock_code = sms["data"]["mock_code"]
    redis_code = redis_get("sms:code:" + phone)
    report(redis_code == mock_code, "Redis 短信验证码与 mock 返回一致", f"code={mock_code}")

    # 注册
    _, reg = http("POST", JAVA + "/auth/register",
                  {"phone": phone, "code": mock_code, "invite_code": ""})
    report(api_ok(reg) and reg["data"].get("access_token"), f"注册新用户 {phone}")
    reg_token = reg["data"]["access_token"]
    reg_user_id = reg["data"]["user"]["user_id"]
    reg_auth_h = {"Authorization": "Bearer " + reg_token}

    # 负向:验证码一次性
    _, reg2 = http("POST", JAVA + "/auth/register",
                   {"phone": phone, "code": mock_code})
    report(not api_ok(reg2), "负向:同一验证码重复注册被拒绝")

    # 3. 密码登录(测试账号,带设备指纹头)
    fp = "e2e-auto-test-" + str(int(time.time()))
    _, login = http("POST", JAVA + "/auth/login",
                    {"phone": "13800138000", "password": "123456"},
                    headers={"X-Device-Fp": fp})
    if api_ok(login) and login["data"].get("access_token"):
        report(True, "密码登录 13800138000 (X-Device-Fp)")
        token = login["data"]["access_token"]
        refresh = login["data"]["refresh_token"]
    elif api_ok(login) and login["data"].get("need_second_verify"):
        report(True, "密码登录触发新设备风控(need_second_verify,符合 R2 设计)")
        token, refresh = None, None
    else:
        report(False, "密码登录 13800138000", str(login)[:120])
        token, refresh = None, None

    # 负向:错误密码
    _, bad_login = http("POST", JAVA + "/auth/login",
                        {"phone": "13800138000", "password": "wrongpwd"},
                        headers={"X-Device-Fp": fp})
    report(not api_ok(bad_login), "负向:错误密码登录被拒绝")

    # 4. 验证码登录(给 13800138000 发码)
    cid2, ccode2 = fresh_captcha()
    _, sms2 = http("POST", JAVA + "/auth/sms/send",
                   {"phone": "13800138000", "captcha_id": cid2, "captcha_code": ccode2})
    # 容错:60s 业务限频(连续跑 e2e 时可能撞上),等 30s 换新图形码重试一次
    if not api_ok(sms2) and "频繁" in sms2.get("message", ""):
        time.sleep(30)
        cid2, ccode2 = fresh_captcha()
        _, sms2 = http("POST", JAVA + "/auth/sms/send",
                       {"phone": "13800138000", "captcha_id": cid2, "captcha_code": ccode2})
    if api_ok(sms2):
        code2 = sms2["data"]["mock_code"]
        _, login2 = http("POST", JAVA + "/auth/login",
                         {"phone": "13800138000", "code": code2},
                         headers={"X-Device-Fp": fp})
        if api_ok(login2) and login2["data"].get("access_token"):
            report(True, "验证码登录 13800138000")
            token = token or login2["data"]["access_token"]
            refresh = refresh or login2["data"]["refresh_token"]
        elif api_ok(login2) and login2["data"].get("need_second_verify"):
            report(True, "验证码登录触发新设备风控(符合设计)")
        else:
            report(False, "验证码登录", str(login2)[:120])
    else:
        report(False, "发送验证码(13800138000)", str(sms2)[:120])

    token = token or reg_token  # 兜底:用新注册用户 token 做后续鉴权接口

    # 5. 刷新 Token
    if refresh:
        _, ref = http("POST", JAVA + "/auth/refresh", {"refresh_token": refresh})
        report(api_ok(ref) and ref["data"].get("access_token"), "RefreshToken 换新 JWT")
    _, bad_ref = http("POST", JAVA + "/auth/refresh", {"refresh_token": "invalid-token"})
    report(not api_ok(bad_ref), "负向:非法 RefreshToken 被拒绝")

    # 6. 风险测评
    auth_h = {"Authorization": "Bearer " + token}
    _, risk = http("POST", JAVA + "/auth/risk/assessment",
                   {"answers": [3, 3, 3, 3, 3]}, headers=auth_h)
    report(api_ok(risk) and risk["data"].get("risk_level"),
           "风险测评提交", f"level={risk.get('data', {}).get('risk_level')}")
    st, noauth = http("POST", JAVA + "/auth/risk/assessment", {"answers": [1, 2, 3]})
    report(not api_ok(noauth), "负向:无 Token 访问鉴权接口被拒")

    # 7. 协议签署
    _, sign = http("POST", JAVA + "/auth/agreement/sign",
                   {"signature": "data:image/png;base64,iVBORw0KGgo=",
                    "agreements": ["user_agreement", "privacy_policy"]}, headers=auth_h)
    report(api_ok(sign) and sign["data"].get("seal_time"), "协议签署", sign.get("data", {}).get("seal_time", ""))

    # 8. 行情(需登录态)
    _, quotes = http("GET", JAVA + "/market/quotes", headers=auth_h)
    ok = api_ok(quotes) and quotes["data"]
    report(ok, "行情列表 /market/quotes",
           f"{len(quotes['data'])} 个标的" if ok else str(quotes)[:120])
    # 单标的:从列表动态取一个不含 '/' 的符号
    # 注意:/market/quote/{symbol} 路径变量无法承载 "BTC/USDT" 这类带斜杠符号(404/400),已知限制
    syms = [q["symbol"] for q in quotes["data"] if "/" not in q.get("symbol", "")] if ok else []
    if syms:
        _, quote = http("GET", JAVA + "/market/quote/" + syms[0], headers=auth_h)
        report(api_ok(quote) and quote["data"].get("price"),
               f"单标的行情 /market/quote/{syms[0]}")
    else:
        report(False, "单标的行情", "行情列表为空,无法取测试符号")

    # K线:query 参数传 symbol,支持带斜杠标的(BTC/USDT)
    import urllib.parse
    ksym = urllib.parse.quote("BTC/USDT", safe="")
    _, kl = http("GET", JAVA + f"/market/kline?symbol={ksym}&period=5m&limit=60", headers=auth_h)
    ok = api_ok(kl) and len(kl.get("data") or []) == 60
    bar = kl["data"][-1] if ok else {}
    report(ok and all(k in bar for k in ("time", "open", "high", "low", "close", "volume")),
           "K线 /market/kline (BTC/USDT 5m×60)",
           f"last_close={bar.get('close')}" if ok else str(kl)[:120])
    _, bad_kl = http("GET", JAVA + f"/market/kline?symbol={ksym}&period=3m", headers=auth_h)
    report(not api_ok(bad_kl), "负向:非法K线周期被拒", bad_kl.get("message", ""))

    print("=" * 60)
    print("E. 交易模块 (/trading)")
    print("=" * 60)
    _, acc = http("GET", JAVA + "/trading/account", headers=auth_h)
    report(api_ok(acc) and acc["data"].get("total_asset") is not None,
           "账户总览 /trading/account",
           f"total_asset={acc.get('data', {}).get('total_asset')}" if api_ok(acc) else str(acc)[:120])

    # 流动性自愈:连续多轮 e2e 会累积 BTC 持仓锁占可用余额,
    # 低于 4000 时先卖出大部分 BTC(保留 0.05),保证后续下单用例稳定
    if api_ok(acc) and acc["data"].get("available", 0) < 4000:
        _, oldpos = http("GET", JAVA + "/trading/positions", headers=auth_h)
        for p in (oldpos.get("data") or []):
            if p["symbol"] == "BTC/USDT" and p["amount"] > 0.06:
                sell_amt = round(p["amount"] - 0.05, 3)
                http("POST", JAVA + "/trading/orders",
                     {"symbol": "BTC/USDT", "side": "sell", "order_type": "market",
                      "amount": sell_amt}, headers=auth_h)

    _, buy = http("POST", JAVA + "/trading/orders",
                  {"symbol": "BTC/USDT", "side": "buy", "order_type": "market", "amount": 0.1},
                  headers=auth_h)
    report(api_ok(buy) and buy["data"].get("status") == "filled",
           "市价买入 BTC/USDT 0.1 立即成交",
           f"price={buy.get('data', {}).get('price')}" if api_ok(buy) else str(buy)[:120])

    _, pos = http("GET", JAVA + "/trading/positions", headers=auth_h)
    report(api_ok(pos) and any(p["symbol"] == "BTC/USDT" for p in pos["data"]),
           "持仓列表含 BTC/USDT")

    _, ords = http("GET", JAVA + "/trading/orders", headers=auth_h)
    report(api_ok(ords) and len(ords["data"]) > 0, "委托记录 /trading/orders")

    # 限价单:买价远低于现价 → 挂单 pending → 撤单
    cur_price = buy["data"]["price"] if api_ok(buy) else 65000
    _, lim = http("POST", JAVA + "/trading/orders",
                  {"symbol": "BTC/USDT", "side": "buy", "order_type": "limit",
                   "price": round(cur_price * 0.5, 2), "amount": 0.05}, headers=auth_h)
    pending_oid = None
    if api_ok(lim) and lim["data"].get("status") == "pending":
        report(True, "限价单未达现价挂出(pending)")
        pending_oid = lim["data"]["orderId"]
    else:
        report(False, "限价单挂出", str(lim)[:120])
    if pending_oid:
        _, cancel = http("DELETE", JAVA + "/trading/orders/" + pending_oid, headers=auth_h)
        report(api_ok(cancel) and cancel["data"].get("status") == "cancelled", "撤销挂单")

    _, bad_sell = http("POST", JAVA + "/trading/orders",
                       {"symbol": "SOL/USDT", "side": "sell", "order_type": "market", "amount": 1},
                       headers=auth_h)
    report(not api_ok(bad_sell), "负向:无持仓卖出被拒", bad_sell.get("message", "")[:60])
    _, bad_amt = http("POST", JAVA + "/trading/orders",
                      {"symbol": "BTC/USDT", "side": "buy", "order_type": "market", "amount": -1},
                      headers=auth_h)
    report(not api_ok(bad_amt), "负向:非法数量下单被拒")

    # ── A股规则:独立 CNY 账户 / 按手下单 / T+1 / 币种报错 ──
    _, cnyacc = http("GET", JAVA + "/trading/account?currency=CNY", headers=auth_h)
    report(api_ok(cnyacc) and cnyacc["data"].get("currency") == "CNY",
           "A股独立 CNY 账户总览",
           f"available={cnyacc.get('data', {}).get('available')}" if api_ok(cnyacc) else str(cnyacc)[:120])

    ASYM = "600036"  # 招商银行(CNY 计价)
    _, ashbuy = http("POST", JAVA + "/trading/orders",
                     {"symbol": ASYM, "side": "buy", "order_type": "market", "amount": 100},
                     headers=auth_h)
    report(api_ok(ashbuy) and ashbuy["data"].get("status") == "filled",
           "A股市价买入1手(100股)立即成交",
           f"price={ashbuy.get('data', {}).get('price')}" if api_ok(ashbuy) else str(ashbuy)[:120])

    _, bad_lot = http("POST", JAVA + "/trading/orders",
                      {"symbol": ASYM, "side": "buy", "order_type": "market", "amount": 150},
                      headers=auth_h)
    report(not api_ok(bad_lot) and "手" in bad_lot.get("message", ""),
           "负向:A股非整手(150股)被拒", bad_lot.get("message", "")[:60])

    _, t1 = http("POST", JAVA + "/trading/orders",
                 {"symbol": ASYM, "side": "sell", "order_type": "market", "amount": 100},
                 headers=auth_h)
    report(not api_ok(t1) and "T+1" in t1.get("message", ""),
           "负向:A股当日买入当日卖出(T+1)被拒", t1.get("message", "")[:60])

    _, cny_short = http("POST", JAVA + "/trading/orders",
                        {"symbol": ASYM, "side": "buy", "order_type": "market", "amount": 100000},
                        headers=auth_h)
    report(not api_ok(cny_short) and "CNY" in cny_short.get("message", ""),
           "负向:A股余额不足提示CNY币种", cny_short.get("message", "")[:70])

    print("=" * 60)
    print("F. API Key + 实盘开关 (/api-keys, /trading/mode)")
    print("=" * 60)
    _, key = http("POST", JAVA + "/api-keys",
                  {"exchange": "binance", "api_key": "AKE2ETEST1234567890", "secret_key": "SKE2ETEST1234567890"},
                  headers=auth_h)
    key_id = key.get("data", {}).get("id") if api_ok(key) else None
    report(api_ok(key) and "****" in key["data"].get("api_key_masked", ""),
           "绑定 Binance API Key(脱敏返回)")
    _, keys = http("GET", JAVA + "/api-keys", headers=auth_h)
    leak = api_ok(keys) and any("secret_key" in k or "secretKey" in k for k in keys["data"])
    report(api_ok(keys) and not leak, "Key 列表不泄露 secret 字段")
    _, mode = http("PUT", JAVA + "/trading/mode", {"mode": "live"}, headers=auth_h)
    report(api_ok(mode) and mode["data"].get("trading_mode") == "live",
           "已签协议+已绑 Key → 开启实盘")
    if key_id:
        _, dk = http("DELETE", JAVA + f"/api-keys/{key_id}", headers=auth_h)
        report(api_ok(dk), "删除 API Key")
        _, mode2 = http("PUT", JAVA + "/trading/mode", {"mode": "live"}, headers=auth_h)
        report(not api_ok(mode2), "负向:无 Key 开启实盘被拒")
        http("PUT", JAVA + "/trading/mode", {"mode": "sim"}, headers=auth_h)  # 复位模拟盘

    print("=" * 60)
    print("G. 监控 (/monitors)")
    print("=" * 60)
    # 清理 testuser001 历史残留监控(避免套餐上限拦截后续创建)
    _, old_mons = http("GET", JAVA + "/monitors", headers=auth_h)
    for om in (old_mons.get("data") or []):
        http("DELETE", JAVA + f"/monitors/{om['id']}", headers=auth_h)

    _, mon = http("POST", JAVA + "/monitors",
                  {"symbol": "ETH/USDT", "strategy": "网格区间"}, headers=auth_h)
    mon_id = mon.get("data", {}).get("id") if api_ok(mon) else None
    report(api_ok(mon) and mon["data"].get("status") == "running", "创建监控 ETH/USDT 网格区间")
    _, mons = http("GET", JAVA + "/monitors", headers=auth_h)
    report(api_ok(mons) and len(mons["data"]) > 0, "监控列表 /monitors")
    if mon_id:
        _, pause = http("PUT", JAVA + f"/monitors/{mon_id}/status",
                        {"status": "paused"}, headers=auth_h)
        report(api_ok(pause) and pause["data"].get("status") == "paused", "暂停监控")
        _, dm = http("DELETE", JAVA + f"/monitors/{mon_id}", headers=auth_h)
        report(api_ok(dm), "删除监控")
    _, bad_mon = http("POST", JAVA + "/monitors",
                      {"symbol": "ETH/USDT", "strategy": "不存在的策略"}, headers=auth_h)
    report(not api_ok(bad_mon), "负向:非法策略创建监控被拒")

    # 套餐权益:新注册用户(免费版,上限1个)——第1个成功,第2个被拦截,随后删除
    _, rm1 = http("POST", JAVA + "/monitors",
                  {"symbol": "SOL/USDT", "strategy": "趋势追踪"}, headers=reg_auth_h)
    report(api_ok(rm1), "免费用户创建第1个监控(权益内)")
    rm1_id = rm1.get("data", {}).get("id")
    _, rm2 = http("POST", JAVA + "/monitors",
                  {"symbol": "ETH/USDT", "strategy": "网格区间"}, headers=reg_auth_h)
    report(not api_ok(rm2) and "上限" in rm2.get("message", ""),
           "负向:免费用户超监控上限被拒", rm2.get("message", "")[:60])
    if rm1_id:
        http("DELETE", JAVA + f"/monitors/{rm1_id}", headers=reg_auth_h)

    agt_st, agt_resp = http("GET", JAVA + "/monitors/agents-status", headers=auth_h)
    agt_list = agt_resp.get("data", {}).get("agents")
    report(agt_st == 200 and isinstance(agt_list, list) and len(agt_list) == 4,
           "AI Agent 状态代理端点(4个Agent)",
           ", ".join(a.get("name", "?") for a in (agt_list or [])))

    print("=" * 60)
    print("H. 订阅/分成/公告 (/subscription, /billing, /announcements)")
    print("=" * 60)
    _, sub = http("POST", JAVA + "/subscription/subscribe",
                  {"plan_level": "pro", "period": "month"}, headers=auth_h)
    report(api_ok(sub) and sub["data"].get("status") == "paid", "订阅专业版(月付 ¥299)")
    _, stt = http("GET", JAVA + "/subscription/status", headers=auth_h)
    report(api_ok(stt) and stt["data"].get("active") is True, "订阅状态生效中")
    report(api_ok(stt) and stt["data"].get("expire_at"),
           "订阅返回到期时间 expire_at", stt.get("data", {}).get("expire_at", ""))
    _, setl = http("GET", JAVA + "/billing/settlements", headers=auth_h)
    report(api_ok(setl) and isinstance(setl["data"], list), "分成结算记录 /billing/settlements")
    _, ann = http("GET", JAVA + "/announcements", headers=auth_h)
    report(api_ok(ann) and isinstance(ann["data"], list), "用户端公告 /announcements")
    _, bad_sub = http("POST", JAVA + "/subscription/subscribe",
                      {"plan_level": "vip", "period": "month"}, headers=auth_h)
    report(not api_ok(bad_sub), "负向:非法套餐订阅被拒")

    print("=" * 60)
    print("C. Python AI 服务 (:8000)")
    print("=" * 60)
    _, h = http("GET", AI + "/health")
    report(h and h.get("status") == "ok", "AI /health")
    _, ag = http("GET", AI + "/agents/status")
    report(ag is not None and (ag.get("agents") or ag.get("status")), "AI /agents/status")
    prices = [100 + i * 0.5 + random.uniform(-1, 1) for i in range(60)]
    _, dec = http("POST", AI + "/decision",
                  {"symbol": "BTCUSDT", "current_price": prices[-1],
                   "historical_prices": prices, "risk_level": "R3"})
    report(dec is not None and ("signal" in dec or "decision" in dec or "action" in dec),
           "AI 五因子门控决策 /decision", str(dec)[:100])
    _, bt = http("POST", AI + "/backtest", {"strategy_name": "五因子门控", "symbol": "BTCUSDT"})
    report(bt and bt.get("status") == "submitted", "AI 回测提交 /backtest")

    print("=" * 60)
    print("D. 管理端 (Java /admin)")
    print("=" * 60)
    _, alogin = http("POST", JAVA + "/admin/login", {"username": "admin", "password": "admin123"})
    report(api_ok(alogin) and alogin["data"].get("token"), "管理员登录 admin/admin123")
    atoken = alogin["data"]["token"]
    ah = {"Authorization": "Bearer " + atoken}
    _, bad_alogin = http("POST", JAVA + "/admin/login", {"username": "admin", "password": "bad"})
    report(not api_ok(bad_alogin), "负向:管理员错误密码被拒")
    _, dash = http("GET", JAVA + "/admin/system/dashboard", headers=ah)
    report(api_ok(dash), "数据看板 /admin/system/dashboard")
    _, users = http("GET", JAVA + "/admin/users", headers=ah)
    report(api_ok(users), "用户列表 /admin/users")
    _, orders = http("GET", JAVA + "/admin/trades/orders", headers=ah)
    report(api_ok(orders), "委托订单 /admin/trades/orders")
    _, logs = http("GET", JAVA + "/admin/system/audit-logs", headers=ah)
    report(api_ok(logs), "审计日志 /admin/system/audit-logs")
    _, noauth2 = http("GET", JAVA + "/admin/system/dashboard")
    report(not api_ok(noauth2), "负向:无 Token 访问管理接口被拒")

    # 冻结实时生效:冻结新注册用户 → 其已签发 token 立即 401 → 解冻后恢复
    _, fz = http("PUT", JAVA + f"/admin/users/{reg_user_id}/status",
                 {"status": 1}, headers=ah)
    report(api_ok(fz), "冻结用户")
    fz_st, fz_req = http("GET", JAVA + "/market/quotes", headers=reg_auth_h)
    report(fz_st == 401, "冻结后用户 token 立即失效(401)", fz_req.get("message", ""))
    _, ufz = http("PUT", JAVA + f"/admin/users/{reg_user_id}/status",
                  {"status": 0}, headers=ah)
    report(api_ok(ufz), "解冻用户")
    rst_st, _ = http("GET", JAVA + "/market/quotes", headers=reg_auth_h)
    report(rst_st == 200, "解冻后 token 恢复可用(200)")

    print("=" * 60)
    print("I. AI 自动执行 (Python /decision → 下单闭环)")
    print("=" * 60)
    _, amon = http("POST", JAVA + "/monitors",
                   {"symbol": "SOL/USDT", "strategy": "趋势追踪"}, headers=reg_auth_h)
    amon_id = amon.get("data", {}).get("id")
    processed, sig_text = False, ""
    for _ in range(18):  # 最多 90s(调度器 10s 起步 + 15s 间隔)
        time.sleep(5)
        _, amons = http("GET", JAVA + "/monitors", headers=reg_auth_h)
        for mm in (amons.get("data") or []):
            if mm.get("id") == amon_id and str(mm.get("signal", "")).startswith("AI"):
                processed, sig_text = True, str(mm["signal"])
                break
        if processed:
            break
    report(processed, "AI 自动执行:监控信号已处理", sig_text)
    if "买入" in sig_text or "平仓" in sig_text:
        _, aorders = http("GET", JAVA + "/trading/orders", headers=reg_auth_h)
        has_ai_order = any(
            str(o.get("strategyName", "")).startswith("AI:")
            for o in (aorders.get("data") or []))
        report(has_ai_order, "AI 信号已产生订单(strategyName=AI:...)")
    else:
        report(True, "AI 本轮决策为观望/拦截(无需下单,属正常)")
    if amon_id:
        http("DELETE", JAVA + f"/monitors/{amon_id}", headers=reg_auth_h)
    # 清理 AI 本轮买入的 SOL 持仓,避免数据残留
    _, apos = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    for p in (apos.get("data") or []):
        if p["symbol"] == "SOL/USDT" and p["amount"] > 0:
            http("POST", JAVA + "/trading/orders",
                 {"symbol": "SOL/USDT", "side": "sell", "order_type": "market",
                  "amount": p["amount"]}, headers=reg_auth_h)

    print("=" * 60)
    print(f"结果: {PASS} 通过 / {FAIL} 失败 / 共 {PASS + FAIL} 项")
    print("=" * 60)
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
