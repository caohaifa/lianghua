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
        /** filled=全部成交 / pending=挂出等待 / rejected=拒单 / partial=部分成交 / unknown=结果未知待对账 */
        private String status;
        private boolean filled;
        private Double fillPrice;
        private Double fillAmount;
        private String message;

        public static FillResult filled(double price, double amount) {
            return new FillResult("filled", true, price, amount, "filled");
        }

        public static FillResult pending(String message) {
            return new FillResult("pending", false, null, 0.0, message);
        }

        /** 交易所拒单(终态,需人工确认后重下) */
        public static FillResult rejected(String message) {
            return new FillResult("rejected", false, null, 0.0, message);
        }

        /** 部分成交:成交部分已返回,剩余继续在交易所撮合 */
        public static FillResult partial(double price, double amount, String message) {
            return new FillResult("partial", true, price, amount, message);
        }

        /** 提交超时/结果未知:不可重试不可撤单,只能对账 */
        public static FillResult unknown(String message) {
            return new FillResult("unknown", false, null, 0.0, message);
        }
    }
}
