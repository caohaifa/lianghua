package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.FuturesOrder;
import com.aiquant.service.FuturesService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 合约交易接口:账户 / 持仓 / 开仓 / 平仓 / 划转 / 成交记录(USDT 本位永续)
 */
@RestController
@RequestMapping("/futures")
public class FuturesController {

    @Autowired
    private FuturesService futuresService;

    @GetMapping("/account")
    public ApiResponse<Map<String, Object>> account(HttpServletRequest request) {
        return ApiResponse.success(futuresService.getAccountView(uid(request)));
    }

    @GetMapping("/positions")
    public ApiResponse<List<Map<String, Object>>> positions(HttpServletRequest request) {
        return ApiResponse.success(futuresService.listPositions(uid(request)));
    }

    /** 市价开仓:symbol / direction(long|short) / leverage(1-125) / amount(币数量) */
    @PostMapping("/order")
    public ApiResponse<FuturesOrder> open(@RequestBody Map<String, Object> body,
                                          HttpServletRequest request) {
        FuturesOrder order = futuresService.openPosition(
                uid(request),
                (String) body.get("symbol"),
                (String) body.get("direction"),
                toInt(body.get("leverage"), 10),
                toDouble(body.get("amount"), 0));
        return ApiResponse.success(order);
    }

    /** 平仓:position_id 必填,amount 省略=全部平仓 */
    @PostMapping("/close")
    public ApiResponse<FuturesOrder> close(@RequestBody Map<String, Object> body,
                                           HttpServletRequest request) {
        Object posId = body.get("position_id");
        if (posId == null) throw new RuntimeException("position_id 不能为空");
        Double amount = body.get("amount") == null ? null : toDouble(body.get("amount"), 0);
        return ApiResponse.success(futuresService.closePosition(
                uid(request), ((Number) posId).longValue(), amount));
    }

    /** 资金划转:direction=in(现货→合约) / out(合约→现货) */
    @PostMapping("/transfer")
    public ApiResponse<Map<String, Object>> transfer(@RequestBody Map<String, Object> body,
                                                     HttpServletRequest request) {
        return ApiResponse.success(futuresService.transfer(
                uid(request),
                (String) body.get("direction"),
                toDouble(body.get("amount"), 0)));
    }

    @GetMapping("/orders")
    public ApiResponse<List<FuturesOrder>> orders(@RequestParam(defaultValue = "50") int limit,
                                                  HttpServletRequest request) {
        return ApiResponse.success(futuresService.listOrders(uid(request), limit));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }

    private double toDouble(Object v, double def) {
        if (v == null) return def;
        if (v instanceof Number n) return n.doubleValue();
        return Double.parseDouble(v.toString());
    }

    private int toInt(Object v, int def) {
        if (v == null) return def;
        if (v instanceof Number n) return n.intValue();
        return Integer.parseInt(v.toString());
    }
}
