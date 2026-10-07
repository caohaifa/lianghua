package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.service.WalletService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 钱包充值/提现接口(模拟环境)。
 */
@RestController
@RequestMapping("/wallet")
public class WalletController {

    @Autowired
    private WalletService walletService;

    /** 充值:currency/amount/channel */
    @PostMapping("/deposit")
    public ApiResponse<Map<String, Object>> deposit(@RequestBody Map<String, Object> body,
                                                    HttpServletRequest request) {
        return ApiResponse.success(walletService.deposit(
                uid(request),
                str(body, "currency", "USDT"),
                toDouble(body.get("amount"), 0),
                (String) body.get("channel")));
    }

    /** 提现:currency/amount/address/network */
    @PostMapping("/withdraw")
    public ApiResponse<Map<String, Object>> withdraw(@RequestBody Map<String, Object> body,
                                                     HttpServletRequest request) {
        return ApiResponse.success(walletService.withdraw(
                uid(request),
                str(body, "currency", "USDT"),
                toDouble(body.get("amount"), 0),
                (String) body.get("address"),
                (String) body.get("network")));
    }

    /** 充值/提现流水(分页) */
    @GetMapping("/transactions")
    public ApiResponse<List<Map<String, Object>>> transactions(
            @RequestParam(defaultValue = "USDT") String currency,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest request) {
        return ApiResponse.success(walletService.list(uid(request), currency, page, size));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }

    private String str(Map<String, Object> body, String key, String def) {
        Object v = body.get(key);
        return v == null ? def : v.toString();
    }

    private double toDouble(Object v, double def) {
        if (v == null) return def;
        if (v instanceof Number n) return n.doubleValue();
        return Double.parseDouble(v.toString());
    }
}
