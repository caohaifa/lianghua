package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.service.RiskEngine;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/risk")
public class RiskController {

    @Autowired
    private RiskEngine riskEngine;

    @GetMapping("/status")
    public ApiResponse<Map<String, Object>> getStatus(HttpServletRequest request) {
        String userId = (String) request.getAttribute("userId");
        return ApiResponse.success(riskEngine.getRiskStatus(userId));
    }

    @PostMapping("/check")
    public ApiResponse<Map<String, Object>> checkOrder(@RequestBody RiskEngine.OrderRequest order,
                                                        HttpServletRequest request) {
        order.setUserId((String) request.getAttribute("userId"));
        String reason = riskEngine.checkOrder(order);
        if (reason != null) {
            return ApiResponse.success(Map.of("passed", false, "reason", reason));
        }
        return ApiResponse.success(Map.of("passed", true, "reason", ""));
    }
}
