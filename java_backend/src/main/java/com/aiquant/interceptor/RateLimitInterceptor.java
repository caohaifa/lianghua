package com.aiquant.interceptor;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;

/**
 * 敏感接口限流(渗透测试前置:防暴力破解/短信轰炸)。
 * 固定窗口计数:Redis INCR + EXPIRE,key = ratelimit:{path}:{ip}。
 * 覆盖无鉴权即可调用的入口接口;短信另有手机号维度 60s 限频,两层叠加。
 */
@Component
public class RateLimitInterceptor implements HandlerInterceptor {

    private final StringRedisTemplate redisTemplate;

    /** 限流开关(压测时可临时关闭) */
    @Value("${rate-limit.enabled:true}")
    private boolean enabled;

    /** 固定窗口时长(秒) */
    @Value("${rate-limit.window-seconds:60}")
    private int windowSeconds;

    /** 各入口窗口内最大次数 */
    @Value("${rate-limit.sms-send:15}")
    private int smsSendLimit;
    @Value("${rate-limit.login:30}")
    private int loginLimit;
    @Value("${rate-limit.register:15}")
    private int registerLimit;
    @Value("${rate-limit.password-reset:10}")
    private int passwordResetLimit;

    public RateLimitInterceptor(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /** 路径 → 窗口内限次;未映射路径不限流(null) */
    private Integer limitOf(String path) {
        return switch (path) {
            case "/auth/sms/send" -> smsSendLimit;
            case "/auth/login", "/admin/login" -> loginLimit;
            case "/auth/register" -> registerLimit;
            case "/auth/password/reset" -> passwordResetLimit;
            default -> null;
        };
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        if (!enabled || "OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        // 去掉 context path(/api/v1),得到控制器映射路径
        String uri = request.getRequestURI();
        String ctx = request.getContextPath();
        String path = (ctx != null && !ctx.isEmpty() && uri.startsWith(ctx))
                ? uri.substring(ctx.length()) : uri;
        Integer limit = limitOf(path);
        if (limit == null) {
            return true;
        }
        String key = "ratelimit:" + path + ":" + clientIp(request);
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, Duration.ofSeconds(windowSeconds));
        }
        if (count != null && count > limit) {
            response.setStatus(429);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"code\":429,\"message\":\"请求过于频繁,请稍后再试\"}");
            return false;
        }
        return true;
    }

    /** 客户端真实 IP(优先 X-Forwarded-For 首段,Nginx 反代场景) */
    private static String clientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        return request.getRemoteAddr();
    }
}
