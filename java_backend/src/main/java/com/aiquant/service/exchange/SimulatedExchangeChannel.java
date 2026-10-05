package com.aiquant.service.exchange;

import com.aiquant.model.Quote;
import com.aiquant.service.MarketService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 模拟交易通道:以 MarketService 实时行情撮合。
 *   市价单 → 立即按现价成交
 *   限价单 → 买价≥现价 / 卖价≤现价 立即成交,否则挂出(pending)
 */
@Component
public class SimulatedExchangeChannel implements ExchangeChannel {

    @Autowired
    private MarketService marketService;

    @Override
    public String channelName() {
        return "sim";
    }

    @Override
    public FillResult placeOrder(ChannelOrderRequest req) {
        Quote quote = marketService.getQuote(req.getSymbol());
        if (quote == null) {
            throw new RuntimeException("标的 " + req.getSymbol() + " 无行情,不可交易");
        }
        double current = quote.getPrice();

        if ("market".equals(req.getOrderType())) {
            return FillResult.filled(current, req.getAmount());
        }
        // 限价单:价格达到即成交
        boolean canFill = "buy".equals(req.getSide())
                ? req.getPrice() >= current
                : req.getPrice() <= current;
        if (canFill) {
            return FillResult.filled(current, req.getAmount());
        }
        return FillResult.pending("限价未达现价,订单已挂出");
    }
}
