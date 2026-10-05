package com.aiquant.controller;

import com.aiquant.mapper.SubscriptionMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.PlanOrder;
import com.aiquant.model.ProfitSettlement;
import com.aiquant.service.SubscriptionService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 订阅与分成:套餐订阅(模拟支付直连成功) + 月度分成结算记录。
 */
@RestController
public class SubscriptionController {

    /** 套餐价目(上线时由支付网关回调替代模拟扣款) */
    private static final Map<String, Double> PRICES = Map.of(
            "basic:month", 99.0, "basic:year", 999.0,
            "pro:month", 299.0, "pro:year", 2999.0);

    @Autowired
    private SubscriptionMapper subscriptionMapper;
    @Autowired
    private SubscriptionService subscriptionService;
    /**
     * 支付开关:开发态 true=模拟支付直接置 paid;
     * 生产 false=只创建 pending 单,等待支付网关回调验签后才可置 paid(网关未接入前用户无法付费订阅)。
     */
    @org.springframework.beans.factory.annotation.Value("${payment.mock-enabled:true}")
    private boolean paymentMockEnabled;

    @GetMapping("/subscription/status")
    public ApiResponse<Map<String, Object>> status(HttpServletRequest request) {
        PlanOrder active = subscriptionService.getActivePlan(uid(request));
        Map<String, Object> vo = new LinkedHashMap<>();
        if (active == null) {
            vo.put("plan_level", "free");
            vo.put("plan_name", "免费版");
            vo.put("active", false);
        } else {
            vo.put("plan_level", active.getPlanLevel());
            vo.put("plan_name", "basic".equals(active.getPlanLevel()) ? "基础版" : "专业版");
            vo.put("active", true);
            vo.put("period", active.getPeriod());
            vo.put("subscribed_at", active.getCreatedAt());
            int days = "year".equals(active.getPeriod()) ? 365 : 30;
            vo.put("expire_at", active.getCreatedAt().plusDays(days));
        }
        return ApiResponse.success(vo);
    }

    @PostMapping("/subscription/subscribe")
    public ApiResponse<PlanOrder> subscribe(@RequestBody Map<String, String> body,
                                            HttpServletRequest request) {
        String planLevel = body.get("plan_level");
        String period = body.get("period");
        Double price = PRICES.get(planLevel + ":" + period);
        if (price == null) {
            throw new RuntimeException("套餐不合法(basic/pro × month/year)");
        }
        // TODO: 接入真实支付网关,支付回调成功后再置 paid
        PlanOrder order = new PlanOrder();
        order.setUserId(uid(request));
        order.setPlanLevel(planLevel);
        order.setPeriod(period);
        order.setAmount(price);
        if (!paymentMockEnabled) {
            // 生产:创建待支付单,由支付网关异步回调置 paid(回调接口待接入)
            order.setStatus("pending");
            subscriptionMapper.insertPlanOrder(order);
            throw new RuntimeException("支付网关暂未接入,订单已创建(待支付),请稍后再试");
        }
        order.setStatus("paid");
        subscriptionMapper.insertPlanOrder(order);
        return ApiResponse.success(order);
    }

    @GetMapping("/billing/settlements")
    public ApiResponse<List<ProfitSettlement>> settlements(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        return ApiResponse.success(
                subscriptionMapper.selectSettlements(uid(request), Math.min(Math.max(limit, 1), 200)));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
