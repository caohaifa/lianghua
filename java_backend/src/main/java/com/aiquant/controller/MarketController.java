package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.Quote;
import com.aiquant.service.MarketService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/market")
public class MarketController {

    @Autowired
    private MarketService marketService;

    @GetMapping("/quotes")
    public ApiResponse<List<Quote>> getQuotes() {
        return ApiResponse.success(marketService.getQuotes());
    }

    /** 手动触发立即拉取真实行情(下拉刷新时可调用) */
    @PostMapping("/refresh")
    public ApiResponse<Void> refresh() {
        marketService.refreshNow();
        return ApiResponse.success(null);
    }

    @GetMapping("/quote/{symbol}")
    public ApiResponse<Quote> getQuote(@PathVariable String symbol) {
        Quote quote = marketService.getQuote(symbol);
        if (quote == null) {
            return ApiResponse.error(404, "行情不存在");
        }
        return ApiResponse.success(quote);
    }

    /**
     * K 线历史(OHLCV)。symbol 走 query 参数以支持 "BTC/USDT" 这类带斜杠标的。
     * period: 1m/5m/1h/1d;limit: 1-500,默认 120。
     */
    @GetMapping("/kline")
    public ApiResponse<List<java.util.Map<String, Object>>> getKline(
            @RequestParam String symbol,
            @RequestParam(defaultValue = "1m") String period,
            @RequestParam(defaultValue = "120") int limit) {
        List<java.util.Map<String, Object>> kline = marketService.getKline(symbol, period, limit);
        if (kline == null) {
            return ApiResponse.error(404, "行情不存在");
        }
        return ApiResponse.success(kline);
    }
}
