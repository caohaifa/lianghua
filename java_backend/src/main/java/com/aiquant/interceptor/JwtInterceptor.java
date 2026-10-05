package com.aiquant.interceptor;

import com.aiquant.mapper.UserMapper;
import com.aiquant.model.User;
import com.aiquant.util.JwtUtil;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtInterceptor implements HandlerInterceptor {

    @Autowired
    private JwtUtil jwtUtil;
    @Autowired
    private UserMapper userMapper;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            response.setStatus(401);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"code\":401,\"message\":\"未登录\"}");
            return false;
        }

        String token = authHeader.substring(7);
        Claims claims;
        try {
            // 解析即校验(签名/过期),避免 validate + parse 重复解析两次
            claims = jwtUtil.parseToken(token);
        } catch (Exception e) {
            response.setStatus(401);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"code\":401,\"message\":\"Token无效或已过期\"}");
            return false;
        }

        String userId = claims.getSubject();
        // 实时校验账号状态:运营冻结后,已签发的 token 立即失效(避免冻结后 24h 内仍可交易)
        User user = userMapper.selectByUserId(userId);
        if (user == null) {
            return deny(response, 401, "账号不存在");
        }
        if (user.getStatus() != null && user.getStatus() != 0) {
            return deny(response, 401, "账号已被冻结");
        }

        request.setAttribute("userId", userId);
        request.setAttribute("phone", claims.get("phone"));
        return true;
    }

    private boolean deny(HttpServletResponse response, int status, String message) throws Exception {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"code\":" + status + ",\"message\":\"" + message + "\"}");
        return false;
    }
}
