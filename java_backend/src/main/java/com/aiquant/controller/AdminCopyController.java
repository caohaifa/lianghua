package com.aiquant.controller;

import com.aiquant.mapper.StrategyPublishMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Set;

import static com.aiquant.controller.AdminUserController.pageResult;

/**
 * 运营后台 · 跟单审核
 * 会员发布的策略(pending)需管理员通过(published)后才在客户端策略广场展示。
 */
@RestController
@RequestMapping("/admin/copy")
public class AdminCopyController {

    /** 审核动作白名单 */
    private static final Set<String> REVIEW_ACTIONS = Set.of("published", "rejected");

    @Autowired
    private StrategyPublishMapper publishMapper;
    @Autowired
    private AuditLogService auditLogService;

    @GetMapping("/publishes")
    public ApiResponse<Map<String, Object>> publishes(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                publishMapper.listForAdmin(status, offset, size),
                publishMapper.countForAdmin(status), page, size));
    }

    /** 审核:通过(published) / 驳回(rejected) */
    @PutMapping("/publishes/{id}/status")
    public ApiResponse<Void> review(@PathVariable Long id,
                                    @RequestBody Map<String, String> body,
                                    HttpServletRequest request) {
        String status = body.get("status");
        if (!REVIEW_ACTIONS.contains(status)) {
            return ApiResponse.error(400, "审核动作不合法(published/rejected)");
        }
        if (publishMapper.selectById(id) == null) {
            return ApiResponse.error(404, "发布不存在");
        }
        publishMapper.updateStatus(id, status);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "review_copy_publish", String.valueOf(id),
                Map.of("status", status),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }
}
