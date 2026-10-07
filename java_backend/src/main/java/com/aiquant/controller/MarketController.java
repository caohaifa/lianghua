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

    /** 行情总览:加密总市值 / 24h 总成交额 / BTC 占比(行情首页顶部卡片) */
    @GetMapping("/overview")
    public ApiResponse<java.util.Map<String, Object>> overview() {
        return ApiResponse.success(
                com.aiquant.service.market.MarketMeta.overview(marketService.getQuotes()));
    }

    /** 币种品牌色表 {symbol: "#hex"}(币种圆点着色) */
    @GetMapping("/meta")
    public ApiResponse<java.util.Map<String, String>> meta() {
        return ApiResponse.success(com.aiquant.service.market.MarketMeta.colorMap());
    }

    /** 手动触发立即拉取真实行情(下拉刷新时可调用) */
    @PostMapping("/refresh")
    public ApiResponse<Void> refresh() {
        marketService.refreshNow();
        return ApiResponse.success(null);
    }

    /**
     * 单标的行情(query 版):支持 BTC/USDT 等带斜杠标的,与 /kline 传参一致。
     * 旧路径 /quote/{symbol} 保留,仅适用于不含 '/' 的标的(如 A 股代码)。
     */
    @GetMapping("/quote")
    public ApiResponse<Quote> getQuoteByParam(@RequestParam String symbol) {
        Quote quote = marketService.getQuote(symbol);
        if (quote == null) {
            return ApiResponse.error(404, "行情不存在");
        }
        return ApiResponse.success(quote);
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

    /**
     * 盘口订单簿(仅加密标的)。返回 {bids:[[price,qty]...], asks:[[price,qty]...]}。
     * limit: 档位数(币安合法档: 5/10/20/50),默认 20。
     */
    @GetMapping("/depth")
    public ApiResponse<java.util.Map<String, Object>> getDepth(
            @RequestParam String symbol,
            @RequestParam(defaultValue = "20") int limit) {
        try {
            java.util.Map<String, Object> depth = marketService.getDepth(symbol, limit);
            if (depth == null) {
                return ApiResponse.error(404, "行情不存在");
            }
            return ApiResponse.success(depth);
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    /**
     * 最新成交流水(仅加密标的)。返回 [{price, qty, time, isBuyerMaker}]。
     * isBuyerMaker=true 表示主动卖出(前端显红)。
     */
    @GetMapping("/trades")
    public ApiResponse<List<java.util.Map<String, Object>>> getTrades(
            @RequestParam String symbol,
            @RequestParam(defaultValue = "50") int limit) {
        try {
            List<java.util.Map<String, Object>> trades = marketService.getTrades(symbol, limit);
            if (trades == null) {
                return ApiResponse.error(404, "行情不存在");
            }
            return ApiResponse.success(trades);
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }
}
