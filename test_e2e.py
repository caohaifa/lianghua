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

    # 7.1 专属邀请码(= userId,新用户注册时填入可建立邀请关系)
    _, ic = http("GET", JAVA + "/auth/invite-code", headers=auth_h)
    report(api_ok(ic) and ic["data"].get("invite_code"), "获取专属邀请码 /auth/invite-code",
           str(ic.get("data", {}).get("invite_code"))[:8] + "..." if api_ok(ic) else "")

    # 7.2 邀请奖励:被推荐人每笔现货成交,推荐人获交易流水 1% 返佣
    inviter_code = ic["data"]["invite_code"] if api_ok(ic) else ""
    if inviter_code:
        phone_b = "137" + "".join(random.choice("0123456789") for _ in range(8))
        cid3, ccode3 = fresh_captcha()
        _, smsb = http("POST", JAVA + "/auth/sms/send",
                       {"phone": phone_b, "captcha_id": cid3, "captcha_code": ccode3})
        if api_ok(smsb):
            _, regb = http("POST", JAVA + "/auth/register",
                           {"phone": phone_b, "code": smsb["data"]["mock_code"],
                            "invite_code": inviter_code})
            okb = api_ok(regb) and regb["data"].get("access_token")
            report(okb, "好友B注册(携带邀请码,建立邀请关系)",
                   phone_b if okb else str(regb)[:120])
        else:
            okb = False
            report(False, "好友B发送验证码", str(smsb)[:120])
        if okb:
            bh = {"Authorization": "Bearer " + regb["data"]["access_token"]}
            _, bbuy = http("POST", JAVA + "/trading/orders",
                           {"symbol": "BTC/USDT", "side": "buy", "order_type": "market",
                            "amount": 0.001}, headers=bh)
            report(api_ok(bbuy) and bbuy["data"].get("status") == "filled",
                   "好友B市价买入 BTC/USDT 0.001",
                   "" if api_ok(bbuy) else str(bbuy)[:120])
            _, summ = http("GET", JAVA + "/referral/summary", headers=auth_h)
            sd = summ.get("data", {}) if api_ok(summ) else {}
            report(api_ok(summ) and (sd.get("total_reward_usdt") or 0) > 0,
                   "推荐人邀请奖励到账(流水1%返佣)",
                   f"usdt={sd.get('total_reward_usdt')} invited={sd.get('invited_count')}"
                   if api_ok(summ) else str(summ)[:120])
            report(api_ok(summ) and bool(sd.get("rewards")), "邀请奖励明细列表非空")
            # 团队管理:团队人数 / 交易总金额 / 成员明细 / 交易流水
            _, team = http("GET", JAVA + "/referral/team", headers=auth_h)
            td = team.get("data", {}) if api_ok(team) else {}
            report(api_ok(team) and (td.get("team_count") or 0) >= 1
                   and (td.get("total_volume_usdt") or 0) > 0,
                   "团队管理:团队人数与交易总金额统计",
                   f"team={td.get('team_count')} active={td.get('active_count')} "
                   f"vol_usdt={td.get('total_volume_usdt')}" if api_ok(team) else str(team)[:120])
            report(api_ok(team) and bool(td.get("members")) and bool(td.get("flows")),
                   "团队管理:成员明细与交易流水列表非空")
    else:
        report(False, "邀请奖励用例跳过(未获取到邀请码)")

    # 8. 行情(需登录态)
    _, quotes = http("GET", JAVA + "/market/quotes", headers=auth_h)
    ok = api_ok(quotes) and quotes["data"]
    report(ok, "行情列表 /market/quotes",
           f"{len(quotes['data'])} 个标的" if ok else str(quotes)[:120])
    # 单标的(路径版,仅适用于无 '/' 符号如 A 股代码)
    syms = [q["symbol"] for q in quotes["data"] if "/" not in q.get("symbol", "")] if ok else []
    if syms:
        _, quote = http("GET", JAVA + "/market/quote/" + syms[0], headers=auth_h)
        report(api_ok(quote) and quote["data"].get("price"),
               f"单标的行情 /market/quote/{syms[0]}")
    else:
        report(False, "单标的行情", "行情列表为空,无法取测试符号")

    # 单标的(query 版):支持带斜杠标的 BTC/USDT(与 /kline 传参一致)
    import urllib.parse
    qsym = urllib.parse.quote("BTC/USDT", safe="")
    _, quote_q = http("GET", JAVA + f"/market/quote?symbol={qsym}", headers=auth_h)
    report(api_ok(quote_q) and quote_q["data"].get("price"),
           "单标的行情 /market/quote?symbol=BTC/USDT(query 版)",
           f"price={quote_q.get('data', {}).get('price')}" if api_ok(quote_q) else str(quote_q)[:120])

    # K线:query 参数传 symbol,支持带斜杠标的(BTC/USDT)
    ksym = qsym
    _, kl = http("GET", JAVA + f"/market/kline?symbol={ksym}&period=5m&limit=60", headers=auth_h)
    ok = api_ok(kl) and len(kl.get("data") or []) == 60
    bar = kl["data"][-1] if ok else {}
    report(ok and all(k in bar for k in ("time", "open", "high", "low", "close", "volume")),
           "K线 /market/kline (BTC/USDT 5m×60)",
           f"last_close={bar.get('close')}" if ok else str(kl)[:120])
    _, bad_kl = http("GET", JAVA + f"/market/kline?symbol={ksym}&period=7m", headers=auth_h)
    report(not api_ok(bad_kl), "负向:非法K线周期被拒", bad_kl.get("message", ""))

    # 盘口(仅加密):bids/asks 各 20 档 [[price, qty]]
    _, dep = http("GET", JAVA + f"/market/depth?symbol={ksym}&limit=20", headers=auth_h)
    ok = api_ok(dep) and dep["data"].get("bids") and dep["data"].get("asks")
    report(ok, "盘口 /market/depth (BTC/USDT 20档)",
           f"bid0={dep['data']['bids'][0]} ask0={dep['data']['asks'][0]}" if ok else str(dep)[:120])
    # 成交流水(仅加密):price/qty/time/isBuyerMaker
    _, trd = http("GET", JAVA + f"/market/trades?symbol={ksym}&limit=30", headers=auth_h)
    ok = api_ok(trd) and len(trd.get("data") or []) > 0
    tr0 = trd["data"][0] if ok else {}
    report(ok and all(k in tr0 for k in ("price", "qty", "time", "isBuyerMaker")),
           "成交流水 /market/trades (BTC/USDT ×30)",
           f"first_price={tr0.get('price')}" if ok else str(trd)[:120])
    # 负向:A股不支持盘口/成交
    _, bad_dep = http("GET", JAVA + "/market/depth?symbol=600519", headers=auth_h)
    report(bad_dep.get("code") == 400, "负向:A股盘口返回 400", bad_dep.get("message", ""))
    _, bad_trd = http("GET", JAVA + "/market/trades?symbol=600519", headers=auth_h)
    report(bad_trd.get("code") == 400, "负向:A股成交流水返回 400", bad_trd.get("message", ""))

    print("=" * 60)
    print("E. 交易模块 (/trading)")
    print("=" * 60)
    _, acc = http("GET", JAVA + "/trading/account", headers=auth_h)
    report(api_ok(acc) and acc["data"].get("total_asset") is not None,
           "账户总览 /trading/account",
           f"total_asset={acc.get('data', {}).get('total_asset')}" if api_ok(acc) else str(acc)[:120])

    # 流动性自愈:连续多轮 e2e 会累积 BTC 持仓锁占可用余额,
    # 低于 12000(需覆盖 0.1 BTC 市价买入,真实价约 8.6 万 USDT/BTC)时先卖出大部分 BTC(保留 0.05)
    if api_ok(acc) and acc["data"].get("available", 0) < 12000:
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

    # 负向:卖出超过持仓量被拒(用超大数量,不依赖测试库中是否恰好无持仓)
    _, bad_sell = http("POST", JAVA + "/trading/orders",
                       {"symbol": "SOL/USDT", "side": "sell", "order_type": "market", "amount": 999999},
                       headers=auth_h)
    report(not api_ok(bad_sell), "负向:超持仓卖出被拒", bad_sell.get("message", "")[:60])
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

    # T+1 校验:买入后尝试卖出全部持仓(含当日冻结的100股,跨轮次旧仓也不影响)
    _, apos_now = http("GET", JAVA + "/trading/positions", headers=auth_h)
    asym_pos = next((p for p in (apos_now.get("data") or []) if p["symbol"] == ASYM), None)
    sell_all = asym_pos["amount"] if asym_pos else 100
    _, t1 = http("POST", JAVA + "/trading/orders",
                 {"symbol": ASYM, "side": "sell", "order_type": "market", "amount": sell_all},
                 headers=auth_h)
    report(not api_ok(t1) and "T+1" in t1.get("message", ""),
           "负向:A股当日买入份额卖出(T+1)被拒", t1.get("message", "")[:60])

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
    # 清理 testuser001 历史残留监控
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

    agt_st, agt_resp = http("GET", JAVA + "/monitors/agents-status", headers=auth_h)
    agt_list = agt_resp.get("data", {}).get("agents")
    report(agt_st == 200 and isinstance(agt_list, list) and len(agt_list) == 4,
           "AI Agent 状态代理端点(4个Agent)",
           ", ".join(a.get("name", "?") for a in (agt_list or [])))

    print("=" * 60)
    print("H. 公告 (/announcements)")
    print("=" * 60)
    _, ann = http("GET", JAVA + "/announcements", headers=auth_h)
    report(api_ok(ann) and isinstance(ann["data"], list), "用户端公告 /announcements")

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
    print("J. 合约交易 + 聚合接口 (/futures, /market/overview, /market/meta, /ai/summary)")
    print("=" * 60)

    def faccount():
        _, a = http("GET", JAVA + "/futures/account", headers=auth_h)
        return a.get("data") if api_ok(a) else None

    def fpositions():
        _, ps = http("GET", JAVA + "/futures/positions", headers=auth_h)
        return ps.get("data") if api_ok(ps) else None

    # 0. 清理历史残留持仓(跨轮次 e2e),再取账户快照
    for p in (fpositions() or []):
        http("POST", JAVA + "/futures/close",
             {"position_id": p["id"], "amount": p["amount"]}, headers=auth_h)
    time.sleep(1)

    st, noauth3 = http("GET", JAVA + "/futures/account")
    report(st in (401, 403), "负向:无 Token 访问合约账户被拒", str(st))

    a0 = faccount()
    ok = a0 is not None and all(
        k in a0 for k in ("wallet_balance", "available", "used_margin",
                          "unrealized_pnl", "total_equity", "margin_ratio"))
    report(ok, "合约账户懒初始化/视图字段完整",
           f"wallet={a0.get('wallet_balance') if a0 else '--'}")
    w0 = a0["wallet_balance"] if a0 else 0

    # 1. 划转 in 2000
    _, tr_in = http("POST", JAVA + "/futures/transfer",
                    {"direction": "in", "amount": 2000}, headers=auth_h)
    a1 = faccount()
    report(api_ok(tr_in) and a1 is not None and abs(a1["wallet_balance"] - (w0 + 2000)) < 1e-6,
           "现货→合约划转 2000 USDT",
           "" if api_ok(tr_in) else str(tr_in)[:120])

    # 2. 负向:A 股标的不能开合约
    _, bad_fsym = http("POST", JAVA + "/futures/order",
                       {"symbol": "600519", "direction": "long",
                        "leverage": 10, "amount": 100}, headers=auth_h)
    report(not api_ok(bad_fsym) and "加密" in bad_fsym.get("message", ""),
           "负向:A股标的开合约被拒", bad_fsym.get("message", "")[:60])

    # 3. 开多 20x 0.01 BTC
    _, op = http("POST", JAVA + "/futures/order",
                 {"symbol": "BTC/USDT", "direction": "long",
                  "leverage": 20, "amount": 0.01}, headers=auth_h)
    time.sleep(1)
    a2 = faccount()
    plist = fpositions() or []
    pcur = next((p for p in plist if p["symbol"] == "BTC/USDT"), None)
    expect_margin = (pcur["mark_price"] * 0.01 / 20) if pcur else 0
    report(api_ok(op) and op["data"].get("action") == "open"
           and pcur is not None and pcur["direction"] == "long"
           and a2 is not None and abs(a2["used_margin"] - expect_margin) < 1.0
           and abs(pcur["amount"] - 0.01) < 1e-6,
           "开多 20x 0.01 BTC(占用保证金≈名义/杠杆)",
           f"margin={pcur['margin'] if pcur else '--'}")

    # 4. 负向:反向开空被拒(单向持仓)
    _, rev = http("POST", JAVA + "/futures/order",
                  {"symbol": "BTC/USDT", "direction": "short",
                   "leverage": 20, "amount": 0.01}, headers=auth_h)
    report(not api_ok(rev) and "反向" in rev.get("message", ""),
           "负向:持仓中反向开仓被拒", rev.get("message", "")[:60])

    # 5. 同向加仓 0.005 → 合计 0.015
    _, add = http("POST", JAVA + "/futures/order",
                  {"symbol": "BTC/USDT", "direction": "long",
                   "leverage": 20, "amount": 0.005}, headers=auth_h)
    time.sleep(1)
    pcur = next((p for p in (fpositions() or []) if p["symbol"] == "BTC/USDT"), None)
    report(api_ok(add) and pcur is not None and abs(pcur["amount"] - 0.015) < 1e-6
           and pcur["entry_price"] > 0,
           "同向加仓 0.005(加权开仓价)",
           f"amount={pcur['amount'] if pcur else '--'}")

    # 6. 负向:占用保证金不可划(超额 out)
    _, bad_out = http("POST", JAVA + "/futures/transfer",
                      {"direction": "out", "amount": 99999999}, headers=auth_h)
    report(not api_ok(bad_out) and "保证金" in bad_out.get("message", ""),
           "负向:超额划转(占用保证金不可划)被拒", bad_out.get("message", "")[:60])

    # 7. 部分平仓 0.005
    _, pc = http("POST", JAVA + "/futures/close",
                 {"position_id": pcur["id"], "amount": 0.005}, headers=auth_h)
    time.sleep(1)
    pcur = next((p for p in (fpositions() or []) if p["symbol"] == "BTC/USDT"), None)
    report(api_ok(pc) and pcur is not None and abs(pcur["amount"] - 0.01) < 1e-6,
           "部分平仓 0.005(持仓剩 0.01)")

    # 8. 强平价方向正确(多仓:0 < liq < entry)
    liq_ok = pcur is not None and 0 < pcur["liquidation_price"] < pcur["entry_price"]
    report(liq_ok, "多仓预估强平价低于开仓价",
           f"entry={pcur['entry_price'] if pcur else '--'} liq={pcur['liquidation_price'] if pcur else '--'}")

    # 9. 全部平仓
    _, fc = http("POST", JAVA + "/futures/close", {"position_id": pcur["id"]}, headers=auth_h)
    time.sleep(1)
    gone = not any(p["symbol"] == "BTC/USDT" for p in (fpositions() or []))
    a3 = faccount()
    report(api_ok(fc) and gone and a3 is not None and abs(a3["used_margin"]) < 1e-6,
           "市价全平(保证金释放,盈亏已入钱包)")

    # 10. 合约成交记录
    _, forders = http("GET", JAVA + "/futures/orders?limit=50", headers=auth_h)
    flist = forders.get("data") if api_ok(forders) else None
    report(isinstance(flist, list) and any(o.get("action") == "open" for o in (flist or []))
           and any(o.get("action") == "close" for o in (flist or [])),
           "合约成交记录含开/平仓")

    # 11. 划回余量(保留极少量灰尘,避免脏占资金)
    avail = a3["available"]
    if avail > 1:
        back = int(avail * 100) / 100 - 0.02
        if back > 0:
            http("POST", JAVA + "/futures/transfer",
                 {"direction": "out", "amount": back}, headers=auth_h)

    # 12. 行情总览
    _, ov = http("GET", JAVA + "/market/overview", headers=auth_h)
    d = ov.get("data") if api_ok(ov) else None
    ok = d is not None and d.get("total_market_cap", 0) > 1e9 \
        and d.get("total_24h_volume", 0) > 0 \
        and 0 < d.get("btc_dominance", -1) < 100 \
        and d.get("active_cryptos", 0) > 0
    report(ok, "行情总览 /market/overview(市值/24h量/BTC占比)",
           f"mcap={d.get('total_market_cap') if d else '--'}")

    # 13. 币种元数据
    _, meta = http("GET", JAVA + "/market/meta", headers=auth_h)
    md = meta.get("data") if api_ok(meta) else None
    report(isinstance(md, dict) and md.get("BTC/USDT") == "#F7931A"
           and md.get("ETH/USDT") == "#627EEA",
           "币种品牌色元数据 /market/meta")

    # 14. AI 收益摘要
    _, ais = http("GET", JAVA + "/ai/summary", headers=auth_h)
    ad = ais.get("data") if api_ok(ais) else None
    ok = ad is not None and all(k in ad for k in
          ("total_pnl", "today_pnl", "running_strategies", "closed_trades", "win_rate")) \
        and 0 <= ad.get("win_rate", -1) <= 100
    report(ok, "AI 收益摘要 /ai/summary(累计/今日/胜率)",
           f"win_rate={ad.get('win_rate') if ad else '--'}")

    print("=" * 60)
    print("K. 钱包充值/提现 (/wallet)")
    print("=" * 60)

    # 取充值前快照
    _, acc_pre = http("GET", JAVA + "/trading/account", headers=auth_h)
    bal_pre = acc_pre["data"]["available"] if api_ok(acc_pre) else 0

    _, dep = http("POST", JAVA + "/wallet/deposit",
                  {"currency": "USDT", "amount": 1000, "channel": "USDT-TRC20"},
                  headers=auth_h)
    report(api_ok(dep) and dep["data"].get("type") == "deposit"
           and dep["data"].get("balance_after") is not None,
           "充值 1000 USDT(模拟入账)",
           f"balance_after={dep.get('data',{}).get('balance_after') if api_ok(dep) else dep}")

    _, wd = http("POST", JAVA + "/wallet/withdraw",
                 {"currency": "USDT", "amount": 300, "network": "TRC20",
                  "address": "TWalletTestAddr"}, headers=auth_h)
    report(api_ok(wd) and wd["data"].get("type") == "withdraw",
           "提现 300 USDT(模拟出账)",
           f"balance_after={wd.get('data',{}).get('balance_after') if api_ok(wd) else wd}")

    _, bad_wd = http("POST", JAVA + "/wallet/withdraw",
                     {"currency": "USDT", "amount": 99999999, "network": "TRC20"},
                     headers=auth_h)
    report(not api_ok(bad_wd), "负向:超额提现被拒",
           bad_wd.get("message", "")[:60])

    _, bad_cur = http("POST", JAVA + "/wallet/deposit",
                      {"currency": "BTC", "amount": 1}, headers=auth_h)
    report(not api_ok(bad_cur), "负向:非支持币种充值被拒",
           bad_cur.get("message", "")[:50])

    _, txs = http("GET", JAVA + "/wallet/transactions?currency=USDT&limit=10",
                  headers=auth_h)
    tlist = txs.get("data") if api_ok(txs) else None
    report(isinstance(tlist, list) and len(tlist) >= 2
           and any(t["type"] == "deposit" for t in tlist)
           and any(t["type"] == "withdraw" for t in tlist),
           "钱包流水含充值/提现记录",
           f"count={len(tlist) if isinstance(tlist,list) else '--'}")

    print("=" * 60)
    print("L. 接口限流 (RateLimit)")
    print("=" * 60)

    # 监控指标端点(Actuator/Prometheus)
    st, prom = http("GET", JAVA + "/actuator/prometheus")
    prom_text = prom if isinstance(prom, str) else str(prom)
    report(st == 200 and "aiquant_orders_total" in prom_text,
           "Prometheus 指标端点含下单计数", f"status={st}")

    # 限流冒烟:/auth/password/reset 窗口限 10 次/分,连打 12 次后应 429
    last_st = 0
    for _ in range(12):
        last_st, _ = http("POST", JAVA + "/auth/password/reset",
                          {"phone": "19900000000", "code": "000000", "new_password": "x"})
    report(last_st == 429, "限流生效:敏感接口超频返回 429", f"last_status={last_st}")

    print("=" * 60)
    print("M. 跟单系统 (/copy + /admin/copy)")
    print("=" * 60)

    # leader 创建监控并发布(免审核直接上架)
    _, lmon = http("POST", JAVA + "/monitors",
                   {"symbol": "BTC/USDT", "strategy": "网格区间"}, headers=auth_h)
    lmon_id = lmon.get("data", {}).get("id") if api_ok(lmon) else None
    pub_id = None
    if lmon_id:
        _, pub = http("POST", JAVA + "/copy/publish",
                      {"monitor_id": lmon_id, "title": "e2e 网格策略",
                       "description": "e2e 测试发布,免审核直接上架"}, headers=auth_h)
        pub_id = pub.get("data", {}).get("id") if api_ok(pub) else None
        report(api_ok(pub) and pub["data"].get("status") == "published",
               "leader 发布 → 直接 published(免审核)", str(pub)[:80])
        _, myp = http("GET", JAVA + "/copy/my-publish", headers=auth_h)
        report(api_ok(myp) and any(p["id"] == pub_id and p.get("monitorId") == lmon_id
                                   for p in (myp.get("data") or [])),
               "我的发布列表含该记录(camelCase 字段)")
    else:
        report(False, "leader 创建监控(发布前置)", str(lmon)[:80])

    # 负向:发布他人监控被拒
    if lmon_id:
        _, steal = http("POST", JAVA + "/copy/publish",
                        {"monitor_id": lmon_id, "title": "偷发布"}, headers=reg_auth_h)
        report(not api_ok(steal), "负向:发布他人监控被拒",
               steal.get("message", "")[:50])

    # 免审核:发布后立即广场可见
    _, sq1 = http("GET", JAVA + "/copy/published", headers=reg_auth_h)
    vis1 = api_ok(sq1) and any(p["id"] == pub_id for p in (sq1.get("data") or []))
    report(api_ok(sq1) and vis1, "发布后立即广场可见(免审核)")

    # 管理端审核接口保留(历史数据可审):非法动作校验
    _, bad_act = http("PUT", JAVA + f"/admin/copy/publishes/{pub_id}/status",
                      {"status": "approved"}, headers=ah)
    report(not api_ok(bad_act), "负向:非法审核动作被拒",
           bad_act.get("message", "")[:50])

    # 广场可见(leaderName/followers)
    _, sq2 = http("GET", JAVA + "/copy/published", headers=reg_auth_h)
    p2 = next((p for p in (sq2.get("data") or []) if p["id"] == pub_id), None)
    report(p2 is not None and p2.get("leaderName") and p2.get("followers") == 0,
           "广场可见(leaderName/followers)",
           f"leaderName={p2.get('leaderName') if p2 else '--'}")

    # follower 跟单
    _, fol = http("PUT", JAVA + "/copy/follow",
                  {"publish_id": pub_id, "ratio": 50}, headers=reg_auth_h)
    report(api_ok(fol) and fol["data"].get("ratio") == 50
           and fol["data"].get("status") == "active", "follower 跟单(50%)")
    _, fols = http("GET", JAVA + "/copy/follows", headers=reg_auth_h)
    frow = next((f for f in (fols.get("data") or []) if f.get("publishId") == pub_id), None)
    report(frow is not None and frow.get("title") == "e2e 网格策略"
           and frow.get("publishStatus") == "published" and frow.get("leaderName"),
           "我的跟单列表(联表 title/leader/发布状态)")

    # 跟单盈亏跟踪字段(复制笔数/已实现盈亏汇总,成交前应为 0)
    report(frow is not None and "tradeCount" in frow and "totalPnl" in frow,
           "我的跟单含 tradeCount/totalPnl 盈亏跟踪字段",
           f"tradeCount={frow.get('tradeCount') if frow else '--'} totalPnl={frow.get('totalPnl') if frow else '--'}")

    # 广场跟单人数 +1
    _, sq3 = http("GET", JAVA + "/copy/published", headers=reg_auth_h)
    p3 = next((p for p in (sq3.get("data") or []) if p["id"] == pub_id), None)
    report(p3 is not None and p3.get("followers") == 1, "广场跟单人数 +1")

    # 负向:跟自己的策略 / 非法比例
    _, self_fol = http("PUT", JAVA + "/copy/follow",
                       {"publish_id": pub_id, "ratio": 10}, headers=auth_h)
    report(not api_ok(self_fol), "负向:跟单自己的策略被拒",
           self_fol.get("message", "")[:50])
    _, bad_ratio = http("PUT", JAVA + "/copy/follow",
                        {"publish_id": pub_id, "ratio": 33}, headers=reg_auth_h)
    report(not api_ok(bad_ratio), "负向:非法跟单比例被拒",
           bad_ratio.get("message", "")[:50])

    # 修改跟单比例(复用同一条记录)
    _, chg = http("PUT", JAVA + "/copy/follow",
                  {"publish_id": pub_id, "ratio": 25}, headers=reg_auth_h)
    report(api_ok(chg) and chg["data"].get("ratio") == 25, "跟单比例调整 50→25")

    # leader 下架 → 跟单自动停止、广场移除
    _, unp = http("DELETE", JAVA + f"/copy/publish/{pub_id}", headers=auth_h)
    report(api_ok(unp), "leader 下架策略")
    _, fols2 = http("GET", JAVA + "/copy/follows", headers=reg_auth_h)
    frow2 = next((f for f in (fols2.get("data") or []) if f.get("publishId") == pub_id), None)
    report(frow2 is not None and frow2.get("status") == "stopped"
           and frow2.get("publishStatus") == "offline",
           "下架后相关跟单自动停止(stopped/offline)")
    _, sq4 = http("GET", JAVA + "/copy/published", headers=reg_auth_h)
    report(api_ok(sq4) and not any(p["id"] == pub_id for p in (sq4.get("data") or [])),
           "下架后从策略广场移除")

    # 清理:删除 leader 监控
    if lmon_id:
        http("DELETE", JAVA + f"/monitors/{lmon_id}", headers=auth_h)

    print("=" * 60)
    print("M2. 个人策略 (/personal + /admin/risk)")
    print("=" * 60)

    # 0. 清理 leader 跨轮次残留的 BTC/USDT 仓位(现货 + 合约)
    _, lfps0 = http("GET", JAVA + "/futures/positions", headers=auth_h)
    for p in (lfps0.get("data") or []):
        if p.get("symbol") == "BTC/USDT" and p.get("amount") and p["amount"] > 0:
            http("POST", JAVA + "/futures/close",
                 {"position_id": p["id"], "amount": p["amount"]}, headers=auth_h)
    _, lsps0 = http("GET", JAVA + "/trading/positions", headers=auth_h)
    for p in (lsps0.get("data") or []):
        if p.get("symbol") == "BTC/USDT" and p.get("amount") and p["amount"] > 0:
            http("POST", JAVA + "/trading/orders",
                 {"symbol": "BTC/USDT", "side": "sell", "order_type": "market",
                  "amount": p["amount"]}, headers=auth_h)
    # leader 预划转合约保证金(J 段结束已把保证金划回现货,开空信号需要)
    http("POST", JAVA + "/futures/transfer",
         {"direction": "in", "amount": 500}, headers=auth_h)

    # 1. leader 创建「个人策略」监控(默认 running)
    _, pmon = http("POST", JAVA + "/monitors",
                   {"symbol": "BTC/USDT", "strategy": "个人策略"}, headers=auth_h)
    pmon_id = pmon.get("data", {}).get("id") if api_ok(pmon) else None
    report(api_ok(pmon) and pmon_id and pmon["data"].get("status") == "running",
           "leader 创建「个人策略」监控(默认 running)", str(pmon)[:80])

    # 2. 负向:非个人策略监控下发信号被拒
    _, nmon = http("POST", JAVA + "/monitors",
                   {"symbol": "BTC/USDT", "strategy": "网格区间"}, headers=auth_h)
    nmon_id = nmon.get("data", {}).get("id") if api_ok(nmon) else None
    if nmon_id:
        _, badsig = http("POST", JAVA + f"/personal/monitors/{nmon_id}/signal",
                         {"action": "open_long", "amount": 0.001}, headers=auth_h)
        report(not api_ok(badsig), "负向:非个人策略下发信号被拒", badsig.get("message", "")[:50])
        http("DELETE", JAVA + f"/monitors/{nmon_id}", headers=auth_h)
    else:
        report(False, "负向:非个人策略下发信号被拒(前置监控创建失败)")

    # 3. 发布个人策略并走管理端审核
    mpub_id = None
    if pmon_id:
        _, mpub = http("POST", JAVA + "/copy/publish",
                       {"monitor_id": pmon_id, "title": "e2e 个人策略",
                        "description": "人工信号台测试"}, headers=auth_h)
        mpub_id = mpub.get("data", {}).get("id") if api_ok(mpub) else None
        _, mappr = http("PUT", JAVA + f"/admin/copy/publishes/{mpub_id}/status",
                        {"status": "published"}, headers=ah)
        report(api_ok(mpub) and api_ok(mappr), "个人策略发布并审核通过")
    else:
        report(False, "个人策略发布(前置监控创建失败)")

    # 4. 负向:固定倍数超范围被拒
    _, badmul = http("PUT", JAVA + "/copy/follow",
                     {"publish_id": mpub_id, "mode": "fixed", "multiplier": 15}, headers=reg_auth_h)
    report(not api_ok(badmul), "负向:跟随倍数 15 超范围被拒", badmul.get("message", "")[:50])

    # 5. 本金比例跟单(balance)
    _, bfol = http("PUT", JAVA + "/copy/follow",
                   {"publish_id": mpub_id, "mode": "balance"}, headers=reg_auth_h)
    report(api_ok(bfol) and bfol["data"].get("mode") == "balance"
           and bfol["data"].get("ratio") == 100,
           "follower 本金比例跟单(mode=balance, ratio=100)")
    mfollow_id = bfol.get("data", {}).get("id") if api_ok(bfol) else None

    # 6. 切换固定倍数(×2)再切回本金比例
    _, ffol = http("PUT", JAVA + "/copy/follow",
                   {"publish_id": mpub_id, "mode": "fixed", "multiplier": 2}, headers=reg_auth_h)
    report(api_ok(ffol) and ffol["data"].get("mode") == "fixed"
           and ffol["data"].get("fixedMultiplier") == 2, "切换固定倍数跟单(fixedMultiplier=2)")
    http("PUT", JAVA + "/copy/follow",
         {"publish_id": mpub_id, "mode": "balance"}, headers=reg_auth_h)

    # 7. 开多信号:leader 买 0.001 BTC → follower 按本金比例自动买入
    _, s1 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "open_long", "amount": 0.001}, headers=auth_h)
    ok1 = api_ok(s1) and s1["data"].get("signal", {}).get("action") == "open_long"
    report(ok1, "开多信号 open_long 下发成功", str(s1)[:100] if not ok1 else "")
    _, rpos = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    r_btc = next((p for p in (rpos.get("data") or [])
                  if p.get("symbol") == "BTC/USDT" and p.get("amount", 0) > 0), None)
    report(r_btc is not None, "balance 模式: follower 自动买入现货多头",
           f"amount={r_btc.get('amount') if r_btc else '--'}")
    qty1 = r_btc["amount"] if r_btc else 0

    # 8. 加仓信号
    _, s2 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "add_long", "amount": 0.001}, headers=auth_h)
    report(api_ok(s2), "加仓信号 add_long 下发成功")
    _, rpos2 = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    r_btc2 = next((p for p in (rpos2.get("data") or [])
                   if p.get("symbol") == "BTC/USDT"), None)
    qty2 = r_btc2["amount"] if r_btc2 else 0
    report(qty2 > qty1, "follower 加仓后持仓增加", f"{qty1} → {qty2}")

    # 9. 部分平仓 50%
    _, s3 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "partial_close", "ratio_pct": 50}, headers=auth_h)
    report(api_ok(s3), "部分平仓信号 partial_close(50%) 下发成功")
    _, rpos3 = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    r_btc3 = next((p for p in (rpos3.get("data") or [])
                   if p.get("symbol") == "BTC/USDT"), None)
    qty3 = r_btc3["amount"] if r_btc3 else 0
    report(qty3 < qty2, "follower 部分平仓后持仓减少", f"{qty2} → {qty3}")

    # 10. 开空:自动全平现货多头 → 双方合约开空(5 倍)
    # follower 新注册合约钱包为 0,先预划转保证金
    http("POST", JAVA + "/futures/transfer",
         {"direction": "in", "amount": 500}, headers=reg_auth_h)
    _, s4 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "open_short", "amount": 0.002, "leverage": 5}, headers=auth_h)
    report(api_ok(s4), "开空信号 open_short 下发成功", str(s4)[:100] if not api_ok(s4) else "")
    _, lfpos = http("GET", JAVA + "/futures/positions", headers=auth_h)
    l_short = next((p for p in (lfpos.get("data") or [])
                    if p.get("symbol") == "BTC/USDT" and p.get("direction") == "short"
                    and p.get("amount", 0) > 0), None)
    report(l_short is not None, "leader 合约空头建立")
    _, rfpos = http("GET", JAVA + "/futures/positions", headers=reg_auth_h)
    r_short = next((p for p in (rfpos.get("data") or [])
                    if p.get("symbol") == "BTC/USDT" and p.get("direction") == "short"
                    and p.get("amount", 0) > 0), None)
    report(r_short is not None, "follower 合约空头同步建立")
    _, rpos4 = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    r_btc4 = next((p for p in (rpos4.get("data") or [])
                   if p.get("symbol") == "BTC/USDT" and p.get("amount", 0) > 0), None)
    report(r_btc4 is None, "开空后现货多头自动全平(单方向持仓)")

    # 11. follower 暂停跟单 → 信号不再复制
    _, paus = http("PUT", JAVA + f"/personal/follows/{mfollow_id}/status",
                   {"status": "paused"}, headers=reg_auth_h)
    report(api_ok(paus) and paus["data"].get("status") == "paused", "follower 暂停自己的跟单")
    _, s5 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "open_long", "amount": 0.001}, headers=auth_h)
    report(api_ok(s5) and s5["data"].get("executed") == 0,
           "暂停后信号不再复制(executed=0)")
    _, rpos5 = http("GET", JAVA + "/trading/positions", headers=reg_auth_h)
    r_btc5 = next((p for p in (rpos5.get("data") or [])
                   if p.get("symbol") == "BTC/USDT" and p.get("amount", 0) > 0), None)
    report(r_btc5 is None, "follower 现货持仓未变化")

    # 12. 负向:非法状态被拒;再恢复跟单
    _, badst = http("PUT", JAVA + f"/personal/follows/{mfollow_id}/status",
                    {"status": "frozen"}, headers=reg_auth_h)
    report(not api_ok(badst), "负向:非法跟单状态被拒", badst.get("message", "")[:50])
    _, resu = http("PUT", JAVA + f"/personal/follows/{mfollow_id}/status",
                   {"status": "active"}, headers=reg_auth_h)
    report(api_ok(resu) and resu["data"].get("status") == "active", "follower 恢复跟单")

    # 13. 换算数量过小 → 复制跳过并产生站内告警(固定倍数×0.1,0.0002 BTC→0.00002,<最小名义额)
    http("PUT", JAVA + "/copy/follow",
         {"publish_id": mpub_id, "mode": "fixed", "multiplier": 0.1}, headers=reg_auth_h)
    _, s6 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "open_long", "amount": 0.0002}, headers=auth_h)
    report(api_ok(s6) and s6["data"].get("executed") == 0 and s6["data"].get("skipped", 0) >= 1,
           "换算数量过小被跳过(executed=0, skipped≥1)")
    http("PUT", JAVA + "/copy/follow",
         {"publish_id": mpub_id, "mode": "balance"}, headers=reg_auth_h)

    # 14. 站内告警:copy_skip 告警到达 → 已读后清零
    _, alerts = http("GET", JAVA + "/personal/alerts", headers=reg_auth_h)
    adata = alerts.get("data") or {}
    report(api_ok(alerts) and len(adata.get("alerts") or []) >= 1
           and adata.get("unread", 0) >= 1, "follower 收到 copy_skip 站内告警",
           f"alerts={len(adata.get('alerts') or [])} unread={adata.get('unread')}")
    _, readit = http("PUT", JAVA + "/personal/alerts/read", headers=reg_auth_h)
    _, alerts2 = http("GET", JAVA + "/personal/alerts", headers=reg_auth_h)
    report(api_ok(readit) and (alerts2.get("data") or {}).get("unread") == 0,
           "告警全部已读后 unread=0")

    # 15. 信号历史(7 个信号全部落库)
    _, shis = http("GET", JAVA + f"/personal/monitors/{pmon_id}/signals", headers=auth_h)
    sigs = shis.get("data") or []
    report(api_ok(shis) and len(sigs) >= 6 and all(s.get("action") for s in sigs),
           "信号历史落库(含 action 统计字段)", f"count={len(sigs)}")

    # 16. 全部平仓:leader 现货多头 + 合约空头一次清零
    _, s7 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "close_all"}, headers=auth_h)
    report(api_ok(s7), "全部平仓信号 close_all 下发成功")
    _, lfpos2 = http("GET", JAVA + "/futures/positions", headers=auth_h)
    l_short2 = next((p for p in (lfpos2.get("data") or [])
                     if p.get("symbol") == "BTC/USDT" and p.get("direction") == "short"
                     and p.get("amount", 0) > 0), None)
    _, lspot2 = http("GET", JAVA + "/trading/positions", headers=auth_h)
    l_btc2 = next((p for p in (lspot2.get("data") or [])
                   if p.get("symbol") == "BTC/USDT" and p.get("amount", 0) > 0), None)
    report(l_short2 is None and l_btc2 is None, "leader 现货+合约全部平仓")

    # 17. 管理端全局风控:一键暂停 → 信号被拒 → 恢复
    _, cst0 = http("GET", JAVA + "/admin/risk/copy-status", headers=ah)
    report(api_ok(cst0) and cst0["data"].get("paused") is False, "初始全局风控状态 paused=false")
    _, ppz = http("PUT", JAVA + "/admin/risk/copy-pause", {"paused": True}, headers=ah)
    report(api_ok(ppz) and ppz["data"].get("paused") is True, "管理端一键暂停全部跟单")
    _, s8 = http("POST", JAVA + f"/personal/monitors/{pmon_id}/signal",
                 {"action": "open_long", "amount": 0.001}, headers=auth_h)
    report(not api_ok(s8) and "暂停" in s8.get("message", ""), "负向:全局暂停期间信号被拒",
           s8.get("message", "")[:50])
    _, ral = http("GET", JAVA + "/admin/risk/alerts?limit=50", headers=ah)
    report(api_ok(ral) and any(a.get("type") == "risk" for a in (ral.get("data") or [])),
           "管理端告警列表含全局风控告警")
    _, rsm = http("PUT", JAVA + "/admin/risk/copy-pause", {"paused": False}, headers=ah)
    report(api_ok(rsm) and rsm["data"].get("paused") is False, "管理端恢复全局跟单")

    # 17b. 策略参数:保存自定义键值对 → 详情回读一致(全人工定义)
    if pmon_id:
        _, pset = http("PUT", JAVA + f"/monitors/{pmon_id}/params",
                       {"params": {"网格间距": "2%", "止损线": "-5%",
                                   "目标收益": "10%"}}, headers=auth_h)
        pset_params = (pset.get("data") or {}).get("params") or ""
        report(api_ok(pset) and "网格间距" in pset_params and "2%" in pset_params,
               "保存策略参数(3 组键值对)", str(pset)[:80])
        _, pdetail = http("GET", JAVA + f"/monitors/{pmon_id}", headers=auth_h)
        pd_params = (pdetail.get("data") or {}).get("params") or ""
        report(api_ok(pdetail) and "止损线" in pd_params and "-5%" in pd_params,
               "监控详情回读策略参数一致")
        _, pset2 = http("PUT", JAVA + f"/monitors/{pmon_id}/params",
                        {"params": {"网格间距": "3%"}}, headers=auth_h)
        report(api_ok(pset2) and "3%" in ((pset2.get("data") or {}).get("params") or ""),
               "覆盖更新策略参数(旧值清除)")
    else:
        report(False, "策略参数保存(前置监控创建失败)")

    # 17c. 负向:参数格式不正确 + 非个人策略设置参数被拒
    _, badfmt = http("PUT", JAVA + f"/monitors/{pmon_id}/params",
                     {"params": "not-a-map"}, headers=auth_h)
    report(not api_ok(badfmt), "负向:参数格式非键值对被拒", badfmt.get("message", "")[:50])
    _, nmon2 = http("POST", JAVA + "/monitors",
                    {"symbol": "BTC/USDT", "strategy": "趋势追踪"}, headers=auth_h)
    nmon2_id = nmon2.get("data", {}).get("id") if api_ok(nmon2) else None
    if nmon2_id:
        _, badstrat = http("PUT", JAVA + f"/monitors/{nmon2_id}/params",
                           {"params": {"网格间距": "2%"}}, headers=auth_h)
        report(not api_ok(badstrat) and "个人策略" in badstrat.get("message", ""),
               "负向:非个人策略设置参数被拒", badstrat.get("message", "")[:50])
        http("DELETE", JAVA + f"/monitors/{nmon2_id}", headers=auth_h)
    else:
        report(False, "负向:非个人策略设置参数被拒(前置监控创建失败)")

    # 18. 清理:下架发布(自动停止跟单)+ 删除监控
    if mpub_id:
        http("DELETE", JAVA + f"/copy/publish/{mpub_id}", headers=auth_h)
    if pmon_id:
        http("DELETE", JAVA + f"/monitors/{pmon_id}", headers=auth_h)

    print("=" * 60)
    print("N. 开源策略量化机器人 (自动带单)")
    print("=" * 60)

    # 广场含 4 个系统机器人(isBot=1)
    _, bsq = http("GET", JAVA + "/copy/published", headers=reg_auth_h)
    bots = [p for p in (bsq.get("data") or []) if p.get("isBot") == 1]
    bot_labels = {"EMA均线交叉", "RSI超买超卖", "网格做市", "布林带突破"}
    report(len(bots) >= 4, "策略广场含 4 个量化机器人",
           f"bots={[(b.get('strategy'), b.get('symbol')) for b in bots]}")
    report(all(b.get("leaderName") and b.get("title") and b.get("strategy") in bot_labels
               for b in bots), "机器人字段齐全(标题/策略/发起人,仅加密标的)",
           f"bad={[b.get('strategy') for b in bots if b.get('strategy') not in bot_labels]}")

    # follower 跟单机器人
    bpid = bots[0]["id"]
    _, bfol = http("PUT", JAVA + "/copy/follow",
                   {"publish_id": bpid, "ratio": 25}, headers=reg_auth_h)
    report(api_ok(bfol) and bfol["data"].get("status") == "active", "follower 跟单机器人(25%)")
    _, bfols = http("GET", JAVA + "/copy/follows", headers=reg_auth_h)
    bfrow = next((f for f in (bfols.get("data") or []) if f.get("publishId") == bpid), None)
    report(bfrow is not None and bfrow.get("title") and bfrow.get("tradeCount") is not None
           and bfrow.get("totalPnl") is not None,
           "我的跟单含机器人条目与盈亏跟踪字段")
    # 清理:停止跟单
    _, bstop = http("DELETE", JAVA + f"/copy/follow/{bfrow['id']}", headers=reg_auth_h)
    report(api_ok(bstop), "停止跟单机器人")

    print("=" * 60)
    print(f"结果: {PASS} 通过 / {FAIL} 失败 / 共 {PASS + FAIL} 项")
    print("=" * 60)
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
