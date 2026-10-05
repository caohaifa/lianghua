package com.aiquant.controller;

import com.aiquant.mapper.AnnouncementMapper;
import com.aiquant.mapper.StrategyMapper;
import com.aiquant.model.Announcement;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.Strategy;
import com.aiquant.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static com.aiquant.controller.AdminUserController.pageResult;

/**
 * 运营后台 · 内容管理
 * 策略(创建/编辑/审核/灰度/上下架) + 系统公告(草稿/发布/下线,全量广播)
 */
@RestController
@RequestMapping("/admin/content")
public class AdminContentController {

    @Autowired
    private StrategyMapper strategyMapper;
    @Autowired
    private AnnouncementMapper announcementMapper;
    @Autowired
    private AuditLogService auditLogService;

    /** 策略状态机:当前状态 → 允许流转到的状态集合 */
    private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = Map.of(
            "draft", Set.of("review"),
            "review", Set.of("gray", "draft"),
            "gray", Set.of("online", "offline"),
            "online", Set.of("offline"),
            "offline", Set.of("online", "draft")
    );

    // ══════════════ 策略 ══════════════

    @GetMapping("/strategies")
    public ApiResponse<Map<String, Object>> strategies(
            @RequestParam(required = false) String name,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                strategyMapper.list(name, status, offset, size),
                strategyMapper.count(name, status), page, size));
    }

    @PostMapping("/strategies")
    public ApiResponse<Void> createStrategy(@RequestBody Strategy body, HttpServletRequest request) {
        body.setStrategyId(UUID.randomUUID().toString().replace("-", ""));
        body.setStatus(body.getStatus() == null ? "draft" : body.getStatus());
        body.setGrayPercent(body.getGrayPercent() == null ? 0 : body.getGrayPercent());
        body.setCreator(String.valueOf(request.getAttribute("username")));
        strategyMapper.insert(body);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "create_strategy", body.getStrategyId(),
                Map.of("name", body.getName() == null ? "" : body.getName()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    @PutMapping("/strategies/{id}")
    public ApiResponse<Void> updateStrategy(@PathVariable Long id, @RequestBody Strategy body) {
        body.setId(id);
        strategyMapper.update(body);
        return ApiResponse.success(null);
    }

    /** 策略状态流转:review 待审核 / gray 灰度(带放量比例) / online 上架 / offline 下架 */
    @PutMapping("/strategies/{id}/status")
    public ApiResponse<Void> updateStrategyStatus(@PathVariable Long id,
                                                  @RequestBody Map<String, Object> body,
                                                  HttpServletRequest request) {
        String status = String.valueOf(body.get("status"));
        int grayPercent = body.get("grayPercent") == null ? 0 : Integer.parseInt(String.valueOf(body.get("grayPercent")));
        Strategy existing = strategyMapper.selectById(id);
        if (existing == null) {
            return ApiResponse.error(404, "策略不存在");
        }
        // 状态机约束:禁止跳步(必须按 draft→review→gray→online↔offline 流转)
        if (!ALLOWED_TRANSITIONS.getOrDefault(existing.getStatus(), Set.of()).contains(status)) {
            return ApiResponse.error(400,
                    "非法状态流转:" + existing.getStatus() + " → " + status);
        }
        strategyMapper.updateStatus(id, status, grayPercent);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "update_strategy_status", String.valueOf(id),
                Map.of("status", status, "grayPercent", grayPercent),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    // ══════════════ 系统公告 ══════════════

    @GetMapping("/announcements")
    public ApiResponse<Map<String, Object>> announcements(
            @RequestParam(required = false) String title,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                announcementMapper.list(title, status, offset, size),
                announcementMapper.count(title, status), page, size));
    }

    @PostMapping("/announcements")
    public ApiResponse<Void> createAnnouncement(@RequestBody Announcement body, HttpServletRequest request) {
        body.setStatus(body.getStatus() == null ? 0 : body.getStatus());
        body.setPublisherId(String.valueOf(request.getAttribute("username")));
        announcementMapper.insert(body);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "create_announcement", String.valueOf(body.getId()),
                Map.of("title", body.getTitle() == null ? "" : body.getTitle()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    @PutMapping("/announcements/{id}")
    public ApiResponse<Void> updateAnnouncement(@PathVariable Long id,
                                                @RequestBody Announcement body,
                                                HttpServletRequest request) {
        body.setId(id);
        Announcement existing = announcementMapper.selectById(id);
        if (existing == null) {
            return ApiResponse.error(404, "公告不存在");
        }
        // 发布:status 0/2 → 1,记录发布时间与发布人(全量广播)
        if (body.getStatus() != null && body.getStatus() == 1 && existing.getStatus() != 1) {
            body.setPublishedAt(LocalDateTime.now());
            body.setPublisherId(String.valueOf(request.getAttribute("username")));
            auditLogService.record(String.valueOf(request.getAttribute("username")),
                    "publish_announcement", String.valueOf(id),
                    Map.of("title", body.getTitle() == null ? "" : body.getTitle()),
                    request.getRemoteAddr());
        }
        announcementMapper.update(body);
        return ApiResponse.success(null);
    }
}
