package com.aiquant.service.market;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 真实行情数据提供者
 * - 加密货币:币安官方公共数据域 data-api.binance.vision(无需 API Key、与 binance.com 同格式)
 * - A 股:新浪财经实时行情 hq.sinajs.cn(GB18030 编码),K 线走 money.finance.sina.com.cn
 *
 * 所有拉取失败均向上抛出异常,由调用方决定保留上一次缓存;本类不做静默造假。
 */
@Component
public class RealMarketDataProvider {

    private static final Logger log = LoggerFactory.getLogger(RealMarketDataProvider.class);

    private static final String BINANCE_BASE = "https://data-api.binance.vision";
    private static final String SINA_HQ = "https://hq.sinajs.cn/list=";
    private static final String SINA_KLINE =
            "https://money.finance.sina.com.cn/quotes_service/api/json_v2.php/CN_MarketData.getKLineData";

    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(8))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();

    // 内部 crypto symbol -> 币安 symbol(BTC/USDT -> BTCUSDT)
    private static final Map<String, String> CRYPTO_TO_BINANCE = Map.ofEntries(
            Map.entry("BTC/USDT", "BTCUSDT"),
            Map.entry("ETH/USDT", "ETHUSDT"),
            Map.entry("SOL/USDT", "SOLUSDT"),
            Map.entry("BNB/USDT", "BNBUSDT"),
            Map.entry("XRP/USDT", "XRPUSDT"),
            Map.entry("DOGE/USDT", "DOGEUSDT"),
            Map.entry("ADA/USDT", "ADAUSDT"),
            Map.entry("AVAX/USDT", "AVAXUSDT"),
            Map.entry("DOT/USDT", "DOTUSDT"),
            Map.entry("LINK/USDT", "LINKUSDT"),
            Map.entry("TRX/USDT", "TRXUSDT"),
            Map.entry("LTC/USDT", "LTCUSDT"),
            Map.entry("TON/USDT", "TONUSDT"),
            Map.entry("ATOM/USDT", "ATOMUSDT"),
            Map.entry("NEAR/USDT", "NEARUSDT"),
            Map.entry("SHIB/USDT", "SHIBUSDT"),
            Map.entry("UNI/USDT", "UNIUSDT"),
            Map.entry("XLM/USDT", "XLMUSDT"),
            Map.entry("FIL/USDT", "FILUSDT"),
            Map.entry("APT/USDT", "APTUSDT"),
            Map.entry("ARB/USDT", "ARBUSDT"),
            Map.entry("OP/USDT", "OPUSDT"),
            Map.entry("INJ/USDT", "INJUSDT"),
            Map.entry("SUI/USDT", "SUIUSDT"),
            Map.entry("PEPE/USDT", "PEPEUSDT"),
            Map.entry("AAVE/USDT", "AAVEUSDT"),
            Map.entry("ALGO/USDT", "ALGOUSDT"),
            Map.entry("FTM/USDT", "FTMUSDT"),
            Map.entry("EOS/USDT", "EOSUSDT"),
            Map.entry("GRT/USDT", "GRTUSDT"));

    // 内部 A 股 symbol -> 新浪带交易所前缀代码
    private static final Map<String, String> ASHARE_TO_SINA = Map.ofEntries(
            Map.entry("000001", "sh000001"),
            Map.entry("000300", "sh000300"),
            Map.entry("399001", "sz399001"),
            Map.entry("399006", "sz399006"),
            Map.entry("000688", "sh000688"),
            Map.entry("600519", "sh600519"),
            Map.entry("300750", "sz300750"),
            Map.entry("002594", "sz002594"),
            Map.entry("601318", "sh601318"),
            Map.entry("600036", "sh600036"),
            Map.entry("000858", "sz000858"),
            Map.entry("601012", "sh601012"),
            Map.entry("300059", "sz300059"),
            Map.entry("688981", "sh688981"),
            Map.entry("000333", "sz000333"),
            Map.entry("000016", "sh000016"),
            Map.entry("000905", "sh000905"),
            Map.entry("600030", "sh600030"),
            Map.entry("600276", "sh600276"),
            Map.entry("600887", "sh600887"),
            Map.entry("601888", "sh601888"),
            Map.entry("600900", "sh600900"),
            Map.entry("601899", "sh601899"),
            Map.entry("002415", "sz002415"),
            Map.entry("000063", "sz000063"),
            Map.entry("002475", "sz002475"),
            Map.entry("601088", "sh601088"),
            Map.entry("600028", "sh600028"),
            Map.entry("601668", "sh601668"),
            Map.entry("603288", "sh603288"));

    // 内部周期 -> 币安 interval
    private static final Map<String, String> BINANCE_INTERVAL = Map.of(
            "1m", "1m", "5m", "5m", "1h", "1h", "1d", "1d");
    // 内部周期 -> 新浪 scale(分钟;日K用240)
    private static final Map<String, Integer> SINA_SCALE = Map.of(
            "1m", 1, "5m", 5, "1h", 60, "1d", 240);

    private static final DateTimeFormatter SINA_TS_FULL =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final DateTimeFormatter SINA_TS_DAY =
            DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final ZoneId ZONE = ZoneId.systemDefault();

    @PostConstruct
    void warmUp() {
        // 仅触发一次异步预热,不阻塞启动
        new Thread(() -> {
            try { fetchCryptoQuotes(); } catch (Exception e) {
                log.warn("加密行情预热失败,将等待定时重试: {}", e.getMessage());
            }
            try { fetchAShareQuotes(); } catch (Exception e) {
                log.warn("A股行情预热失败,将等待定时重试: {}", e.getMessage());
            }
        }, "market-warmup").start();
    }

    // ─────────────────────────── 加密行情 ───────────────────────────

    /** 拉取全部所需 crypto 实时快照,返回 内部symbol -> Quote字段Map */
    public Map<String, Map<String, Object>> fetchCryptoQuotes() throws Exception {
        // 用 symbols 参数只拉所需标的(约1秒),避免全市场3000+标的的大响应阻塞调度线程
        StringBuilder arr = new StringBuilder("[");
        CRYPTO_TO_BINANCE.values().forEach(v -> arr.append('"').append(v).append("\","));
        arr.setCharAt(arr.length() - 1, ']');
        String url = BINANCE_BASE + "/api/v3/ticker/24hr?symbols="
                + URLEncoder.encode(arr.toString(), StandardCharsets.UTF_8);
        JsonNode root = readJson(url);

        Map<String, String> binanceToInternal = new LinkedHashMap<>();
        CRYPTO_TO_BINANCE.forEach((k, v) -> binanceToInternal.put(v, k));

        Map<String, Map<String, Object>> result = new LinkedHashMap<>();
        long now = System.currentTimeMillis();
        for (JsonNode t : root) {
            String bs = t.path("symbol").asText("");
            String internal = binanceToInternal.get(bs);
            if (internal == null) continue;
            Map<String, Object> q = new LinkedHashMap<>();
            q.put("price", Double.parseDouble(t.path("lastPrice").asText("0")));
            q.put("change", Double.parseDouble(t.path("priceChangePercent").asText("0")));
            q.put("volume", Double.parseDouble(t.path("volume").asText("0"))); // 基础币成交量
            q.put("timestamp", now);
            result.put(internal, q);
        }
        if (result.size() < CRYPTO_TO_BINANCE.size()) {
            throw new IllegalStateException("币安返回的 crypto 标的不完整: "
                    + result.size() + "/" + CRYPTO_TO_BINANCE.size());
        }
        return result;
    }

    /** 拉取 crypto K 线(OHLCV) */
    public List<Map<String, Object>> fetchCryptoKline(String internalSymbol,
                                                      String period, int limit) throws Exception {
        String bs = CRYPTO_TO_BINANCE.get(internalSymbol);
        if (bs == null) throw new IllegalArgumentException("非 crypto 标的: " + internalSymbol);
        String interval = BINANCE_INTERVAL.get(period);
        if (interval == null) throw new RuntimeException("不支持的周期: " + period);
        limit = Math.max(1, Math.min(limit, 500));
        String url = BINANCE_BASE + "/api/v3/klines?symbol=" + bs
                + "&interval=" + interval + "&limit=" + limit;
        JsonNode rows = readJson(url);

        List<Map<String, Object>> bars = new ArrayList<>(limit);
        for (JsonNode k : rows) {
            Map<String, Object> bar = new LinkedHashMap<>();
            bar.put("time", k.get(0).asLong());
            bar.put("open", k.get(1).asDouble());
            bar.put("high", k.get(2).asDouble());
            bar.put("low", k.get(3).asDouble());
            bar.put("close", k.get(4).asDouble());
            bar.put("volume", k.get(5).asDouble());
            bars.add(bar);
        }
        return bars;
    }

    // ─────────────────────────── A 股行情 ───────────────────────────

    /** 拉取全部所需 A 股实时快照,返回 内部symbol -> Quote字段Map */
    public Map<String, Map<String, Object>> fetchAShareQuotes() throws Exception {
        // 拼接所有代码一次性请求
        StringBuilder codes = new StringBuilder();
        ASHARE_TO_SINA.values().forEach(c -> codes.append(c).append(','));
        String raw = fetchString(SINA_HQ + codes, true);

        Map<String, Map<String, Object>> result = new LinkedHashMap<>();
        long now = System.currentTimeMillis();
        for (String line : raw.split("\n")) {
            int eq = line.indexOf('=');
            if (eq < 0) continue;
            String varName = line.substring(line.indexOf("hq_str_") + 7, eq); // 如 sh600519
            int q1 = line.indexOf('"'), q2 = line.lastIndexOf('"');
            if (q1 < 0 || q2 <= q1) continue;
            String payload = line.substring(q1 + 1, q2);
            if (payload.isEmpty()) continue;
            String[] f = payload.split(",");
            // 字段: 0名称 1今开 2昨收 3现价 4最高 5最低 ... 8成交量(股) 9成交额
            double prevClose = parseD(f, 2);
            double price = parseD(f, 3);
            if (price <= 0) price = prevClose; // 未开盘时取昨收
            double changePct = prevClose > 0 ? (price - prevClose) / prevClose * 100 : 0;
            double volume = parseD(f, 8);

            Map<String, Object> q = new LinkedHashMap<>();
            q.put("name", f[0]);
            q.put("price", price);
            q.put("change", changePct);
            q.put("volume", volume);
            q.put("timestamp", now);
            result.put(toInternalAshare(varName), q);
        }
        if (result.size() < ASHARE_TO_SINA.size()) {
            throw new IllegalStateException("新浪返回的 A 股标的不完整: "
                    + result.size() + "/" + ASHARE_TO_SINA.size());
        }
        return result;
    }

    /** 拉取 A 股 K 线(OHLCV) */
    public List<Map<String, Object>> fetchAShareKline(String internalSymbol,
                                                      String period, int limit) throws Exception {
        String sinaCode = ASHARE_TO_SINA.get(internalSymbol);
        if (sinaCode == null) throw new IllegalArgumentException("非 A 股标的: " + internalSymbol);
        Integer scale = SINA_SCALE.get(period);
        if (scale == null) throw new RuntimeException("不支持的周期: " + period);
        limit = Math.max(1, Math.min(limit, 500));
        String url = SINA_KLINE + "?symbol=" + sinaCode
                + "&scale=" + scale + "&datalen=" + limit;
        JsonNode rows = readJson(url);

        boolean daily = scale == 240;
        List<Map<String, Object>> bars = new ArrayList<>(limit);
        for (JsonNode k : rows) {
            long time = parseSinaTime(k.path("day").asText(""), daily);
            Map<String, Object> bar = new LinkedHashMap<>();
            bar.put("time", time);
            bar.put("open", k.path("open").asDouble(0));
            bar.put("high", k.path("high").asDouble(0));
            bar.put("low", k.path("low").asDouble(0));
            bar.put("close", k.path("close").asDouble(0));
            bar.put("volume", k.path("volume").asDouble(0));
            bars.add(bar);
        }
        return bars;
    }

    // ─────────────────────────── 工具方法 ───────────────────────────

    /** 判断 symbol 所属市场 */
    public static boolean isCrypto(String internalSymbol) {
        return internalSymbol != null && internalSymbol.contains("/");
    }

    private String toInternalAshare(String sinaCode) {
        return ASHARE_TO_SINA.entrySet().stream()
                .filter(e -> e.getValue().equals(sinaCode))
                .map(Map.Entry::getKey).findFirst().orElse(sinaCode);
    }

    private static double parseD(String[] f, int i) {
        if (i >= f.length) return 0;
        try { return Double.parseDouble(f[i].trim()); } catch (Exception e) { return 0; }
    }

    private long parseSinaTime(String text, boolean daily) {
        try {
            LocalDateTime ldt = daily
                    ? java.time.LocalDate.parse(text, SINA_TS_DAY).atStartOfDay()
                    : LocalDateTime.parse(text, SINA_TS_FULL);
            return ldt.atZone(ZONE).toInstant().toEpochMilli();
        } catch (Exception e) {
            return System.currentTimeMillis();
        }
    }

    private JsonNode readJson(String url) throws Exception {
        return mapper.readTree(fetchString(url, false));
    }

    private String fetchString(String url, boolean gb18030) throws Exception {
        // 远端偶发抖动/限流:失败重试一次(间隔 500ms),提高定时拉取与K线的稳定性
        Exception last = null;
        for (int attempt = 0; attempt < 2; attempt++) {
            if (attempt > 0) {
                try { Thread.sleep(500); } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }
            try {
                HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                        .timeout(Duration.ofSeconds(12))
                        // 新浪实时行情需带 Referer,否则可能被拒
                        .header("Referer", "https://finance.sina.com.cn")
                        .GET().build();
                HttpResponse<byte[]> resp = http.send(req, HttpResponse.BodyHandlers.ofByteArray());
                if (resp.statusCode() / 100 != 2) {
                    throw new IllegalStateException("HTTP " + resp.statusCode() + " for " + url);
                }
                java.nio.charset.Charset cs = gb18030
                        ? java.nio.charset.Charset.forName("GB18030")
                        : StandardCharsets.UTF_8;
                return new String(resp.body(), cs);
            } catch (Exception e) {
                last = e;
            }
        }
        throw last;
    }
}
