package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.service.AuthService;
import com.aiquant.util.CaptchaGenerator;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/auth")
public class AuthController {

    /** 健康检查(无需鉴权,用于负载均衡/运维探活) */
    @GetMapping("/health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.success(Map.of("status", "UP", "time", System.currentTimeMillis()));
    }

    @Autowired
    private AuthService authService;
    @Autowired
    private StringRedisTemplate redisTemplate;
    /**
     * 开发态开关:无真实短信网关时把验证码通过 mock_code 回传(前端弹窗展示)。
     * 生产环境必须设为 false 并接入真实短信网关(AuthService.sendSmsCode 内 TODO)。
     */
    @org.springframework.beans.factory.annotation.Value("${sms.mock-return-code:true}")
    private boolean smsMockReturnCode;

    /**
     * 获取图形验证码(发送短信前置校验)
     * 返回 {captcha_id, image: Base64 PNG}
     */
    @GetMapping("/captcha")
    public ApiResponse<Map<String, Object>> captcha() {
        CaptchaGenerator.Captcha captcha = CaptchaGenerator.generate();
        redisTemplate.opsForValue().set("captcha:id:" + captcha.id(), captcha.code(), 5, TimeUnit.MINUTES);
        return ApiResponse.success(Map.of(
                "captcha_id", captcha.id(),
                "image", captcha.imageBase64()
        ));
    }

    /**
     * 发送短信验证码(60s 限频、图形校验前置)
     * 无真实短信网关:开发环境把验证码通过 mock_code 直接回传,前端弹窗展示;
     * 将来接入真实短信后,移除该字段即可。
     */
    @PostMapping("/sms/send")
    public ApiResponse<Map<String, Object>> sendSms(@RequestBody Map<String, String> body) {
        String code = authService.sendSmsCode(body.get("phone"), body.get("captcha_id"), body.get("captcha_code"));
        return ApiResponse.success(smsMockReturnCode ? Map.of("mock_code", code) : Map.of());
    }

    /**
     * 注册(手机号+验证码+邀请码;密码可选,向后兼容)
     */
    @PostMapping("/register")
    public ApiResponse<Map<String, Object>> register(@RequestBody Map<String, String> body) {
        AuthService.RegisterResult result = authService.register(
                body.get("phone"), body.get("code"), body.get("password"), body.get("invite_code"));
        return ApiResponse.success(Map.of(
                "access_token", result.accessToken(),
                "user", Map.of(
                        "user_id", result.userId(),
                        "phone", result.phone(),
                        "nickname", result.nickname()
                )
        ));
    }

    /**
     * 登录(密码登录 或 验证码登录),携带设备指纹参与异地风控
     */
    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody Map<String, String> body,
                                                  HttpServletRequest request) {
        String deviceFp = firstNonBlank(body.get("device_fp"), request.getHeader("X-Device-Fp"));
        AuthService.LoginResult result = authService.login(
                body.get("phone"), body.get("password"), body.get("code"),
                deviceFp, request.getRemoteAddr());

        // 风控:新设备/异地 → 触发二次验证
        if (result.needSecondVerify()) {
            return ApiResponse.success(Map.of(
                    "need_second_verify", true,
                    "risk_level", 2,
                    "device_model", "未知设备",
                    "ip", result.loginIp() != null ? result.loginIp() : "",
                    "city", result.loginCity() != null ? result.loginCity() : ""
            ));
        }
        return ApiResponse.success(Map.of(
                "access_token", result.accessToken(),
                "refresh_token", result.refreshToken(),
                "user", Map.of(
                        "user_id", result.userId(),
                        "phone", result.phone(),
                        "nickname", result.nickname(),
                        "risk_level", result.riskLevel() != null ? result.riskLevel() : "",
                        "agreement_signed", result.agreementSigned()
                )
        ));
    }

    /**
     * 刷新 Token(JWT 过期时,用 RefreshToken 换新 JWT)
     */
    @PostMapping("/refresh")
    public ApiResponse<Map<String, Object>> refresh(@RequestBody Map<String, String> body) {
        AuthService.TokenPair pair = authService.refreshToken(body.get("refresh_token"));
        return ApiResponse.success(Map.of(
                "access_token", pair.accessToken(),
                "refresh_token", pair.refreshToken()
        ));
    }

    /**
     * 重置密码(短信验证码 + 新密码)
     */
    @PostMapping("/password/reset")
    public ApiResponse<Map<String, String>> resetPassword(@RequestBody Map<String, String> body) {
        authService.resetPassword(body.get("phone"), body.get("code"), body.get("new_password"));
        return ApiResponse.success(Map.of("status", "ok"));
    }

    /**
     * 风险测评(答题 → 输出 R1~R5 等级)
     */
    @PostMapping("/risk/assessment")
    public ApiResponse<Map<String, Object>> riskAssessment(@RequestBody Map<String, Object> body,
                                                            HttpServletRequest request) {
        String userId = (String) request.getAttribute("userId");
        @SuppressWarnings("unchecked")
        List<Integer> answers = (List<Integer>) body.get("answers");
        String level = authService.submitRiskAssessment(userId, answers);
        return ApiResponse.success(Map.of("risk_level", level));
    }

    /**
     * 协议签署(手写签名 Base64 + 已勾选协议列表,服务端加时间戳/环境/内容哈希存证)
     */
    @PostMapping("/agreement/sign")
    public ApiResponse<Map<String, Object>> signAgreement(@RequestBody Map<String, Object> body,
                                                           HttpServletRequest request) {
        String userId = (String) request.getAttribute("userId");
        String signature = (String) body.get("signature");
        @SuppressWarnings("unchecked")
        List<String> agreements = (List<String>) body.get("agreements");
        String sealTime = authService.signAgreement(userId, signature, agreements,
                request.getRemoteAddr(), request.getHeader("User-Agent"));
        return ApiResponse.success(Map.of("seal_time", sealTime));
    }

    /** 当前用户专属邀请码(= userId,新用户注册时填入可建立邀请关系) */
    @GetMapping("/invite-code")
    public ApiResponse<Map<String, String>> inviteCode(HttpServletRequest request) {
        String userId = (String) request.getAttribute("userId");
        return ApiResponse.success(Map.of("invite_code", authService.getUserInviteCode(userId)));
    }

    private static String firstNonBlank(String a, String b) {
        return (a != null && !a.isBlank()) ? a : b;
    }
}
