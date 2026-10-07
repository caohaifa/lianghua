package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.Order;
import com.aiquant.model.Position;
import com.aiquant.service.TradingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 用户端交易接口:账户总览 / 下单 / 撤单 / 委托 / 持仓 / 模拟实盘切换
 */
@RestController
@RequestMapping("/trading")
public class TradingController {

    @Autowired
    private TradingService tradingService;

    @GetMapping("/account")
    public ApiResponse<Map<String, Object>> account(
            @RequestParam(defaultValue = "USDT") String currency,
            HttpServletRequest request) {
        return ApiResponse.success(tradingService.getAccountOverview(uid(request), currency));
    }

    @GetMapping("/orders")
    public ApiResponse<List<Order>> orders(@RequestParam(defaultValue = "50") int limit,
                                           @RequestParam(required = false) String symbol,
                                           HttpServletRequest request) {
        return ApiResponse.success(tradingService.listOrders(uid(request), symbol, limit));
    }

    @PostMapping("/orders")
    public ApiResponse<Order> placeOrder(@RequestBody Map<String, Object> body,
                                         HttpServletRequest request) {
        Order order = tradingService.placeOrder(
                uid(request),
                (String) body.get("symbol"),
                (String) body.get("side"),
                body.get("order_type") == null ? "market" : (String) body.get("order_type"),
                toDouble(body.get("price")),
                toDouble(body.get("amount")),
                (String) body.get("strategy_name"));
        return ApiResponse.success(order);
    }

    @DeleteMapping("/orders/{orderId}")
    public ApiResponse<Map<String, String>> cancelOrder(@PathVariable String orderId,
                                                        HttpServletRequest request) {
        tradingService.cancelOrder(uid(request), orderId);
        return ApiResponse.success(Map.of("status", "cancelled"));
    }

    @GetMapping("/positions")
    public ApiResponse<List<Position>> positions(HttpServletRequest request) {
        return ApiResponse.success(tradingService.refreshPositions(uid(request)));
    }

    @GetMapping("/mode")
    public ApiResponse<Map<String, Object>> getMode(HttpServletRequest request) {
        return ApiResponse.success(tradingService.getMode(uid(request)));
    }

    @PutMapping("/mode")
    public ApiResponse<Map<String, Object>> switchMode(@RequestBody Map<String, String> body,
                                                       HttpServletRequest request) {
        return ApiResponse.success(tradingService.switchMode(uid(request), body.get("mode")));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }

    private Double toDouble(Object v) {
        if (v == null) return null;
        if (v instanceof Number n) return n.doubleValue();
        return Double.parseDouble(v.toString());
    }
}
