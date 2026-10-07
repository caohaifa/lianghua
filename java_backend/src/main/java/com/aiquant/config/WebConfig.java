package com.aiquant.config;

import com.aiquant.interceptor.AdminInterceptor;
import com.aiquant.interceptor.JwtInterceptor;
import com.aiquant.interceptor.RateLimitInterceptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Autowired
    private RateLimitInterceptor rateLimitInterceptor;
    @Autowired
    private JwtInterceptor jwtInterceptor;
    @Autowired
    private AdminInterceptor adminInterceptor;
    /** 允许跨域来源,逗号分隔;开发态默认 *,生产由 cors.allowed-origins 注入正式域名白名单 */
    @org.springframework.beans.factory.annotation.Value("${cors.allowed-origins:*}")
    private String allowedOrigins;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 敏感接口限流(最先执行,保护登录/短信/注册等入口接口)
        registry.addInterceptor(rateLimitInterceptor)
                .addPathPatterns("/**");
        // 普通用户接口
        registry.addInterceptor(jwtInterceptor)
                .addPathPatterns("/**")
                .excludePathPatterns(
                        "/auth/health",
                        "/auth/login",
                        "/auth/register",
                        "/auth/sms/send",
                        "/auth/refresh",
                        "/auth/captcha",
                        "/auth/password/reset",
                        "/admin/**",
                        "/actuator/**",
                        "/error"
                );
        // 运营后台接口(独立鉴权,要求管理员 Token)
        registry.addInterceptor(adminInterceptor)
                .addPathPatterns("/admin/**")
                .excludePathPatterns("/admin/login");
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins(allowedOrigins.split(","))
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .maxAge(3600);
    }
}
