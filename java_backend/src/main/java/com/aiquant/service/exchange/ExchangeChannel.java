package com.aiquant.service.exchange;

import lombok.AllArgsConstructor;
import lombok.Data;

/**
 * 交易所通道抽象:模拟通道 / 真实交易所(Binance 等)统一接口。
 * TradingService 按用户 trading_mode + API Key 凭据路由到具体通道。
 */
public interface ExchangeChannel {

    /** 通道标识: sim / binance */
    String channelName();

    /**
     * 下单
     * @return 成交结果;filled=false 表示限价单挂出等待成交
     */
    FillResult placeOrder(ChannelOrderRequest req);

    @Data
    class ChannelOrderRequest {
        private String symbol;
        private String side;       // buy/sell
        private String orderType;  // market/limit
        private Double price;      // 限价单价格
        private Double amount;
    }

    @Data
    @AllArgsConstructor
    class FillResult {
        private boolean filled;
        private Double fillPrice;
        private Double fillAmount;
        private String message;

        public static FillResult filled(double price, double amount) {
            return new FillResult(true, price, amount, "filled");
        }

        public static FillResult pending(String message) {
            return new FillResult(false, null, 0.0, message);
        }
    }
}
