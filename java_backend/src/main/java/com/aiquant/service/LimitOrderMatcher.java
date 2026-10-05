package com.aiquant.service;

import com.aiquant.mapper.OrderMapper;
import com.aiquant.model.Order;
import com.aiquant.model.Quote;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 限价单撮合引擎(模拟):每 2 秒随行情节拍扫描全部挂单,
 * 价格触达的限价单按限价成交(复用 TradingService 的成交入账逻辑)。
 * 独立于 MarketService 调度,避免 MarketService ↔ TradingService 循环依赖。
 */
@Component
public class LimitOrderMatcher {

    @Autowired
    private OrderMapper orderMapper;
    @Autowired
    private MarketService marketService;
    @Autowired
    private TradingService tradingService;

    @Scheduled(fixedRate = 2000)
    public void match() {
        List<Order> pending = orderMapper.selectAllPending();
        if (pending.isEmpty()) return;
        for (Order order : pending) {
            try {
                Quote quote = marketService.getQuote(order.getSymbol());
                if (quote == null) continue;
                boolean filled = tradingService.fillPendingOrder(order, quote.getPrice());
                if (filled) {
                    System.out.println("[MATCH] 限价单成交: " + order.getOrderId() + " "
                            + order.getSide() + " " + order.getSymbol() + " @ " + order.getPrice());
                }
            } catch (Exception e) {
                // 单笔撮合失败不影响其他订单,下轮重试
                System.out.println("[MATCH] 限价单撮合异常: " + order.getOrderId() + " - " + e.getMessage());
            }
        }
    }
}
