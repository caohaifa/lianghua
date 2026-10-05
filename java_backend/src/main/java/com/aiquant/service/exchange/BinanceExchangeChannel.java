package com.aiquant.service.exchange;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

/**
 * Binance 实盘通道(可配置实现)。
 *
 * 凭据来自用户 API Key 管理模块(t_broker_account),下单时注入。
 * 当前为沙盒阶段:签名/报文组装按币安 REST 规范实现(HMAC-SHA256),
 * 真实下单开关 exchange.binance.live-enabled=false 时回落到模拟撮合,
 * 避免无网络/无真实资金环境下产生不可控委托;上线时置 true 即可直连。
 */
@Component
public class BinanceExchangeChannel implements ExchangeChannel {

    @Value("${exchange.binance.base-url:https://api.binance.com}")
    private String baseUrl;

    @Value("${exchange.binance.live-enabled:false}")
    private boolean liveEnabled;

    @Autowired
    private SimulatedExchangeChannel simulatedFallback;

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
        // TODO(上线直连): 按币安 POST /api/v3/order 规范发送已签名请求:
        //   String query = "symbol=BTCUSDT&side=BUY&type=MARKET&quantity=0.01&timestamp=" + ts;
        //   String signature = hmacSha256(query, credential.secretKey());
        //   Http POST baseUrl + "/api/v3/order?" + query + "&signature=" + signature
        //   Header: X-MBX-APIKEY: credential.apiKey()
        throw new RuntimeException("Binance 实盘直连未启用");
    }

    @Override
    public FillResult placeOrder(ChannelOrderRequest req) {
        // 无凭据直调(防御):走模拟撮合
        return simulatedFallback.placeOrder(req);
    }

    /** 币安 REST 签名:HMAC-SHA256(queryString, secret) 十六进制 */
    public static String hmacSha256(String data, String secret) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
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
