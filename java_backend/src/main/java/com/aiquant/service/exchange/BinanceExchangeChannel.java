package com.aiquant.service.exchange;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

/**
 * Binance 实盘通道(可配置实现)。
 *
 * 凭据来自用户 API Key 管理模块(t_broker_account),下单时注入。
 * exchange.binance.live-enabled=false 时回落到模拟撮合(沙盒全链路演练);
 * 置 true 后按币安 REST 规范直连(base-url 可切 testnet 联调,再切主网)。
 *
 * 异常路径状态机(与 Order 状态对齐):
 *   响应可达但拒单     → ExchangeRejectException → 订单置 rejected(终态)
 *   超时/网络异常       → ExchangeTimeoutException → 订单置 unknown(待对账,禁止自动重试)
 *   全部成交           → FillResult.filled
 *   部分成交           → FillResult.partial(成交部分入账,剩余留在交易所)
 *   挂出未成交         → FillResult.pending(实盘限价单由交易所撮合)
 */
@Component
public class BinanceExchangeChannel implements ExchangeChannel {

    private static final MediaType FORM = MediaType.parse("application/x-www-form-urlencoded");

    @Value("${exchange.binance.base-url:https://api.binance.com}")
    private String baseUrl;

    @Value("${exchange.binance.live-enabled:false}")
    private boolean liveEnabled;

    @Autowired
    private SimulatedExchangeChannel simulatedFallback;

    private final OkHttpClient http = new OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .build();

    private final ObjectMapper mapper = new ObjectMapper();

    /** 每次调用注入凭据(多用户场景,通道本身无状态) */
    public record Credential(String apiKey, String secretKey) {}

    @Override
    public String channelName() {
        return "binance";
    }

    public FillResult placeOrder(ChannelOrderRequest req, Credential credential) {
        if (!liveEnabled) {
            // 沙盒:行情同源撮合,通道标记为 binance,便于上线前全链路演练
            return simulatedFallback.placeOrder(req);
        }
        // 币安符号规则:无斜杠大写(BTC/USDT → BTCUSDT)
        String symbol = req.getSymbol().replace("/", "").toUpperCase();
        String side = "buy".equals(req.getSide()) ? "BUY" : "SELL";
        String type = "market".equals(req.getOrderType()) ? "MARKET" : "LIMIT";

        StringBuilder query = new StringBuilder();
        query.append("symbol=").append(symbol)
                .append("&side=").append(side)
                .append("&type=").append(type);
        if ("LIMIT".equals(type)) {
            query.append("&timeInForce=GTC&price=").append(trimNumber(req.getPrice()));
        }
        query.append("&quantity=").append(trimNumber(req.getAmount()))
                .append("&newOrderRespType=RESULT")
                .append("&timestamp=").append(System.currentTimeMillis())
                .append("&recvWindow=5000");
        String signature = hmacSha256(query.toString(), credential.secretKey());
        String body = query + "&signature=" + signature;

        Request request = new Request.Builder()
                .url(baseUrl + "/api/v3/order")
                .header("X-MBX-APIKEY", credential.apiKey())
                .post(RequestBody.create(body, FORM))
                .build();

        try (Response resp = http.newCall(request).execute()) {
            String text = resp.body() != null ? resp.body().string() : "";
            JsonNode node = mapper.readTree(text);
            if (!resp.isSuccessful()) {
                // 币安错误报文: {"code":-2010,"msg":"Account has insufficient balance..."}
                int code = node.path("code").asInt(resp.code());
                String msg = node.path("msg").asText("HTTP " + resp.code());
                throw new ExchangeRejectException(code, "Binance拒单[" + code + "]: " + msg);
            }
            return parseFill(node);
        } catch (ExchangeRejectException e) {
            throw e;
        } catch (java.io.IOException e) {
            // 超时/网络异常:订单实际状态未知,禁止重试,只能对账
            throw new ExchangeTimeoutException("Binance请求超时,订单状态未知待对账: " + e.getMessage());
        } catch (Exception e) {
            throw new ExchangeTimeoutException("Binance响应解析失败,状态未知待对账: " + e.getMessage());
        }
    }

    @Override
    public FillResult placeOrder(ChannelOrderRequest req) {
        // 无凭据直调(防御):走模拟撮合
        return simulatedFallback.placeOrder(req);
    }

    /** 解析下单响应(newOrderRespType=RESULT):executedQty>0 即有成交 */
    private FillResult parseFill(JsonNode node) {
        String status = node.path("status").asText("");
        double executedQty = node.path("executedQty").asDouble(0);
        // cummulativeQuoteQty / executedQty = 实际均价(部分成交时也成立)
        double cumQuote = node.path("cummulativeQuoteQty").asDouble(0);
        double avgPrice = executedQty > 0 ? cumQuote / executedQty : node.path("price").asDouble(0);

        switch (status) {
            case "FILLED":
                return FillResult.filled(avgPrice, executedQty);
            case "PARTIALLY_FILLED":
            case "PARTIAL_CANCELED":
                return FillResult.partial(avgPrice, executedQty, "部分成交 " + executedQty + ",剩余留在交易所");
            case "NEW":
                return FillResult.pending("限价单已挂出,等待交易所撮合");
            case "EXPIRED":
            case "CANCELED":
            case "REJECTED":
                return FillResult.rejected("Binance订单状态 " + status);
            default:
                return FillResult.unknown("未知订单状态 " + status + ",待对账");
        }
    }

    /** 币安要求数量/价格去掉多余尾零(0.10000000 → 0.1) */
    private static String trimNumber(Double v) {
        if (v == null) return "0";
        return String.valueOf(v).replaceAll("(\\.\\d*?)0+$", "$1").replaceAll("\\.$", "");
    }

    /** 币安 REST 签名:HMAC-SHA256(queryString, secret) 十六进制 */
    public static String hmacSha256(String data, String secret) {
        try {
            javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(
                    secret.getBytes(java.nio.charset.StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(data.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Binance 请求签名失败");
        }
    }
}
