package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.StrategyFollow;
import com.aiquant.model.StrategyPublish;
import com.aiquant.service.CopyTradingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 跟单系统(用户端):发布策略(待审核) / 策略广场 / 跟单与停止跟单。
 * 广场与跟单仅对后台审核通过(published)的策略开放。
 */
@RestController
@RequestMapping("/copy")
public class CopyTradingController {

    @Autowired
    private CopyTradingService copyTradingService;

    /** 申请发布自己的监控到策略广场 */
    @PostMapping("/publish")
    public ApiResponse<StrategyPublish> publish(@RequestBody Map<String, Object> body,
                                                HttpServletRequest request) {
        Long monitorId = body.get("monitor_id") == null ? null
                : Long.parseLong(String.valueOf(body.get("monitor_id")));
        String title = (String) body.get("title");
        String description = (String) body.get("description");
        return ApiResponse.success(
                copyTradingService.publish(uid(request), monitorId, title, description));
    }

    /** 我的发布(含审核状态:pending/published/rejected/offline) */
    @GetMapping("/my-publish")
    public ApiResponse<List<StrategyPublish>> myPublish(HttpServletRequest request) {
        return ApiResponse.success(copyTradingService.myPublishes(uid(request)));
    }

    /** 策略广场:审核通过的发布列表 */
    @GetMapping("/published")
    public ApiResponse<List<StrategyPublish>> published() {
        return ApiResponse.success(copyTradingService.listPublished());
    }

    /** 下架我的发布 */
    @DeleteMapping("/publish/{id}")
    public ApiResponse<Map<String, String>> unpublish(@PathVariable Long id,
                                                      HttpServletRequest request) {
        copyTradingService.unpublish(uid(request), id);
        return ApiResponse.success(Map.of("status", "offline"));
    }

    /** 跟单(模式: ratio 固定比例 10/25/50/100 / balance 本金比例 / fixed 固定倍数 0.1-10) */
    @PutMapping("/follow")
    public ApiResponse<StrategyFollow> follow(@RequestBody Map<String, Object> body,
                                              HttpServletRequest request) {
        Long publishId = body.get("publish_id") == null ? null
                : Long.parseLong(String.valueOf(body.get("publish_id")));
        Integer ratio = body.get("ratio") == null ? null
                : Integer.parseInt(String.valueOf(body.get("ratio")));
        String mode = (String) body.get("mode");
        Double multiplier = body.get("multiplier") == null ? null
                : Double.parseDouble(String.valueOf(body.get("multiplier")));
        return ApiResponse.success(copyTradingService.follow(uid(request), publishId, mode, ratio, multiplier));
    }

    /** 我的跟单列表 */
    @GetMapping("/follows")
    public ApiResponse<List<StrategyFollow>> myFollows(HttpServletRequest request) {
        return ApiResponse.success(copyTradingService.myFollows(uid(request)));
    }

    /** 停止跟单 */
    @DeleteMapping("/follow/{id}")
    public ApiResponse<Map<String, String>> stopFollow(@PathVariable Long id,
                                                       HttpServletRequest request) {
        copyTradingService.stopFollow(uid(request), id);
        return ApiResponse.success(Map.of("status", "stopped"));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
