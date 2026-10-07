package com.aiquant.controller;

import com.aiquant.mapper.AiStatsMapper;
import com.aiquant.mapper.FuturesPositionMapper;
import com.aiquant.mapper.PositionMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.FuturesPosition;
import com.aiquant.model.Position;
import com.aiquant.model.Quote;
import com.aiquant.service.MarketService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 量化首页接口:累计收益 / 今日收益 / 运行策略 / 胜率。
 */
@RestController
@RequestMapping("/ai")
public class AiController {

    @Autowired
    private AiStatsMapper aiStatsMapper;
    @Autowired
    private PositionMapper positionMapper;
    @Autowired
    private FuturesPositionMapper futuresPositionMapper;
    @Autowired
    private MarketService marketService;

    @GetMapping("/summary")
    public ApiResponse<Map<String, Object>> summary(HttpServletRequest request) {
        String userId = (String) request.getAttribute("userId");

        double totalPnl = aiStatsMapper.sumSpotRealized(userId)
                + aiStatsMapper.sumFuturesRealized(userId);
        double todayPnl = aiStatsMapper.sumSpotTodayPnl(userId)
                + aiStatsMapper.sumFuturesTodayPnl(userId);

        Map<String, Object> spot = aiStatsMapper.spotClosedStats(userId);
        Map<String, Object> futures = aiStatsMapper.futuresClosedStats(userId);
        long total = ((Number) spot.get("total")).longValue()
                + ((Number) futures.get("total")).longValue();
        long wins = ((Number) spot.get("wins")).longValue()
                + ((Number) futures.get("wins")).longValue();

        // 浮盈计算: 现货持仓 + 合约持仓
        double unrealizedPnl = 0;
        List<Position> openPositions = positionMapper.selectOpenByUser(userId);
        for (Position p : openPositions) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q != null) {
                unrealizedPnl += (q.getPrice() - p.getEntryPrice()) * p.getAmount();
            }
        }
        List<FuturesPosition> openFutures = futuresPositionMapper.selectOpenByUser(userId);
        for (FuturesPosition fp : openFutures) {
            Quote q = marketService.getQuote(fp.getSymbol());
            if (q != null) {
                double multiplier = "short".equals(fp.getDirection()) ? -1 : 1;
                unrealizedPnl += (q.getPrice() - fp.getEntryPrice()) * fp.getAmount() * multiplier;
            }
        }

        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("total_pnl", Math.round(totalPnl * 1e8) / 1e8);
        vo.put("today_pnl", Math.round(todayPnl * 1e8) / 1e8);
        vo.put("unrealized_pnl", Math.round(unrealizedPnl * 1e8) / 1e8);
        vo.put("running_strategies", aiStatsMapper.countRunningMonitors(userId));
        vo.put("closed_trades", total);
        vo.put("win_rate", total > 0 ? Math.round(wins * 10000.0 / total) / 100d : 0);
        return ApiResponse.success(vo);
    }
}
