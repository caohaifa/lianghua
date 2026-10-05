package com.aiquant.interceptor;

import com.aiquant.util.JwtUtil;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.Map;
import java.util.Set;

/**
 * 管理员接口鉴权:
 * 1. 校验 JWT 且要求 type=admin;
 * 2. 按角色(RBAC)校验接口访问权限(角色 → 允许的路径前缀)。
 * 通过后把 adminId/username/role 放入 request 供 Controller 使用。
 */
@Component
public class AdminInterceptor implements HandlerInterceptor {

    @Autowired
    private JwtUtil jwtUtil;

    /** 角色权限表:角色 → 允许访问的 /admin/** 路径前缀(super_admin 放行全部) */
    private static final Map<String, Set<String>> ROLE_PERMISSIONS = Map.of(
            "super_admin", Set.of("*"),
            // 运营:用户(冻结/解冻)、交易查询、策略、公告、看板、审计(只读)
            "ops", Set.of(
                    "/admin/users",
                    "/admin/trades",
                    "/admin/content/strategies",
                    "/admin/content/announcements",
                    "/admin/system/dashboard",
                    "/admin/system/audit-logs"),
            // 合规:用户风险等级调整、策略审核、看板、审计
            "compliance", Set.of(
                    "/admin/users",
                    "/admin/content/strategies",
                    "/admin/system/dashboard",
                    "/admin/system/audit-logs"),
            // 财务:计费、交易查询、看板、审计
            "finance", Set.of(
                    "/admin/billing",
                    "/admin/trades",
                    "/admin/system/dashboard",
                    "/admin/system/audit-logs")
    );

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return deny(response, 401, "未登录");
        }
        Claims claims;
        try {
            claims = jwtUtil.parseToken(authHeader.substring(7));
        } catch (Exception e) {
            return deny(response, 401, "Token无效或已过期");
        }
        if (!"admin".equals(claims.get("type"))) {
            return deny(response, 403, "无管理员权限");
        }
        String role = String.valueOf(claims.get("role"));
        String uri = request.getRequestURI();
        // RBAC:按角色校验路径前缀
        if (!hasPermission(role, uri)) {
            return deny(response, 403, "当前角色无此操作权限");
        }
        request.setAttribute("adminId", claims.get("adminId"));
        request.setAttribute("username", claims.get("username"));
        request.setAttribute("role", role);
        return true;
    }

    private boolean hasPermission(String role, String uri) {
        Set<String> allowed = ROLE_PERMISSIONS.get(role);
        if (allowed == null) {
            return false;
        }
        if (allowed.contains("*")) {
            return true;
        }
        // 去掉 context-path(/api/v1) 前缀,取 /admin 起的路径
        int idx = uri.indexOf("/admin");
        String path = idx >= 0 ? uri.substring(idx) : uri;
        return allowed.stream().anyMatch(path::startsWith);
    }

    private boolean deny(HttpServletResponse response, int status, String message) throws Exception {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"code\":" + status + ",\"message\":\"" + message + "\"}");
        return false;
    }
}
