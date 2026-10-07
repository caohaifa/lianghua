package com.aiquant.controller;

import com.aiquant.mapper.AnnouncementMapper;
import com.aiquant.mapper.BannerMapper;
import com.aiquant.mapper.FaqMapper;
import com.aiquant.mapper.PushNotificationMapper;
import com.aiquant.mapper.StrategyMapper;
import com.aiquant.mapper.UserMapper;
import com.aiquant.model.Announcement;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.Banner;
import com.aiquant.model.Faq;
import com.aiquant.model.PushNotification;
import com.aiquant.model.Strategy;
import com.aiquant.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
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
    private BannerMapper bannerMapper;
    @Autowired
    private FaqMapper faqMapper;
    @Autowired
    private PushNotificationMapper pushMapper;
    @Autowired
    private UserMapper userMapper;
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
        if (body.getName() == null || body.getName().isBlank()) {
            return ApiResponse.error(400, "策略名称必填");
        }
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
    public ApiResponse<Void> updateStrategy(@PathVariable Long id, @RequestBody Strategy body,
                                            HttpServletRequest request) {
        Strategy existing = strategyMapper.selectById(id);
        if (existing == null) return ApiResponse.error(404, "策略不存在");
        if (body.getName() == null || body.getName().isBlank()) {
            return ApiResponse.error(400, "策略名称必填");
        }
        body.setId(id);
        strategyMapper.update(body);   // update 不改 status/gray_percent,状态只能经 /status 状态机
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "update_strategy", String.valueOf(id),
                Map.of("name", body.getName() == null ? "" : body.getName()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    /** 策略状态流转:review 待审核 / gray 灰度(带放量比例) / online 上架 / offline 下架 */
    @PutMapping("/strategies/{id}/status")
    public ApiResponse<Void> updateStrategyStatus(@PathVariable Long id,
                                                  @RequestBody Map<String, Object> body,
                                                  HttpServletRequest request) {
        String status = String.valueOf(body.get("status"));
        Strategy existing = strategyMapper.selectById(id);
        if (existing == null) {
            return ApiResponse.error(404, "策略不存在");
        }
        // 状态机约束:禁止跳步(必须按 draft→review→gray→online↔offline 流转)
        if (!ALLOWED_TRANSITIONS.getOrDefault(existing.getStatus(), Set.of()).contains(status)) {
            return ApiResponse.error(400,
                    "非法状态流转:" + existing.getStatus() + " → " + status);
        }
        // grayPercent:容错解析 + 钳制 0~100;上架视为全量(100),退回草稿/待审核清零
        int grayPercent;
        if ("online".equals(status)) {
            grayPercent = 100;
        } else if ("draft".equals(status) || "review".equals(status)) {
            grayPercent = 0;
        } else {
            try {
                grayPercent = body.get("grayPercent") == null ? 0
                        : Integer.parseInt(String.valueOf(body.get("grayPercent")));
            } catch (NumberFormatException e) {
                grayPercent = 0;
            }
            grayPercent = Math.max(0, Math.min(100, grayPercent));
        }
        strategyMapper.updateStatus(id, status, grayPercent);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "update_strategy_status", String.valueOf(id),
                Map.of("from", existing.getStatus(), "to", status, "grayPercent", grayPercent),
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

    // ══════════════ 轮播图 Banner ══════════════

    @GetMapping("/banners")
    public ApiResponse<Map<String, Object>> banners(
            @RequestParam(required = false) String title,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                bannerMapper.list(title, status, offset, size),
                bannerMapper.count(title, status), page, size));
    }

    @PostMapping("/banners")
    public ApiResponse<Void> createBanner(@RequestBody Banner body, HttpServletRequest request) {
        body.setCreator(String.valueOf(request.getAttribute("username")));
        bannerMapper.insert(body);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "create_banner", String.valueOf(body.getId()),
                Map.of("title", body.getTitle() == null ? "" : body.getTitle()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    @PutMapping("/banners/{id}")
    public ApiResponse<Void> updateBanner(@PathVariable Long id, @RequestBody Banner body,
                                          HttpServletRequest request) {
        body.setId(id);
        bannerMapper.update(body);
        return ApiResponse.success(null);
    }

    @PutMapping("/banners/{id}/status")
    public ApiResponse<Void> toggleBanner(@PathVariable Long id, @RequestBody Map<String, Object> body,
                                          HttpServletRequest request) {
        int status = Integer.parseInt(String.valueOf(body.get("status")));
        bannerMapper.updateStatus(id, status);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "toggle_banner", String.valueOf(id),
                Map.of("status", status), request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    // ══════════════ FAQ/帮助中心 ══════════════

    @GetMapping("/faqs")
    public ApiResponse<Map<String, Object>> faqs(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                faqMapper.list(category, keyword, status, offset, size),
                faqMapper.count(category, keyword, status), page, size));
    }

    @GetMapping("/faqs/categories")
    public ApiResponse<List<String>> faqCategories() {
        return ApiResponse.success(faqMapper.selectCategories());
    }

    @PostMapping("/faqs")
    public ApiResponse<Void> createFaq(@RequestBody Faq body, HttpServletRequest request) {
        body.setCreator(String.valueOf(request.getAttribute("username")));
        faqMapper.insert(body);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "create_faq", String.valueOf(body.getId()),
                Map.of("question", body.getQuestion() == null ? "" : body.getQuestion()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    @PutMapping("/faqs/{id}")
    public ApiResponse<Void> updateFaq(@PathVariable Long id, @RequestBody Faq body) {
        body.setId(id);
        faqMapper.update(body);
        return ApiResponse.success(null);
    }

    // ══════════════ 推送通知 ══════════════

    @GetMapping("/push-notifications")
    public ApiResponse<Map<String, Object>> pushNotifications(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                pushMapper.list(keyword, status, offset, size),
                pushMapper.count(keyword, status), page, size));
    }

    @PostMapping("/push-notifications")
    public ApiResponse<Void> createPush(@RequestBody PushNotification body, HttpServletRequest request) {
        body.setCreator(String.valueOf(request.getAttribute("username")));
        pushMapper.insert(body);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "create_push", String.valueOf(body.getId()),
                Map.of("title", body.getTitle() == null ? "" : body.getTitle()),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    @PutMapping("/push-notifications/{id}")
    public ApiResponse<Void> updatePush(@PathVariable Long id, @RequestBody PushNotification body) {
        body.setId(id);
        pushMapper.update(body);
        return ApiResponse.success(null);
    }

    /** 立即发送推送(计算目标用户数并标记已发送) */
    @PostMapping("/push-notifications/{id}/send")
    public ApiResponse<Map<String, Object>> sendPush(@PathVariable Long id, HttpServletRequest request) {
        PushNotification push = pushMapper.selectById(id);
        if (push == null) return ApiResponse.error(404, "推送不存在");
        if (push.getStatus() == 2) return ApiResponse.error(400, "已发送,不可重复发送");
        if (push.getStatus() == 3) return ApiResponse.error(400, "已取消");

        int targetCount = estimateTargetCount(push.getTargetType(), push.getTargetValue());
        pushMapper.markSent(id, 2, LocalDateTime.now(), targetCount);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "send_push", String.valueOf(id),
                Map.of("title", push.getTitle(), "targetCount", targetCount),
                request.getRemoteAddr());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", id);
        result.put("sentCount", targetCount);
        result.put("sentAt", LocalDateTime.now().toString());
        return ApiResponse.success(result);
    }

    @PostMapping("/push-notifications/{id}/cancel")
    public ApiResponse<Void> cancelPush(@PathVariable Long id, HttpServletRequest request) {
        pushMapper.markSent(id, 3, null, 0);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "cancel_push", String.valueOf(id), Map.of(), request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    /** 估算推送目标人数 */
    private int estimateTargetCount(String targetType, String targetValue) {
        if (targetType == null || "all".equals(targetType)) {
            return (int) userMapper.countAll();
        }
        if ("risk_level".equals(targetType) && targetValue != null) {
            String[] levels = targetValue.split(",");
            int count = 0;
            for (String level : levels) {
                count += userMapper.countByRiskLevel(level.trim());
            }
            return count;
        }
        if ("user_ids".equals(targetType) && targetValue != null) {
            return targetValue.split(",").length;
        }
        return 0;
    }
}
