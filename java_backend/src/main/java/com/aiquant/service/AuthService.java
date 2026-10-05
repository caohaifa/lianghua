package com.aiquant.service;

import com.aiquant.mapper.UserMapper;
import com.aiquant.model.User;
import com.aiquant.util.JwtUtil;
import com.aiquant.util.PasswordHasher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Service
public class AuthService {

    @Autowired
    private UserMapper userMapper;
    @Autowired
    private JwtUtil jwtUtil;
    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String SMS_CODE_PREFIX = "sms:code:";
    private static final String SMS_CODE_INTERVAL = "sms:interval:";
    private static final String CAPTCHA_PREFIX = "captcha:id:";
    private static final String REFRESH_PREFIX = "auth:refresh:";
    private static final String TRUSTED_DEVICE_PREFIX = "auth:trusted:";
    /** 模拟短信验证码的固定日志文件(无真实短信网关,验证码统一写这里查看) */
    private static final String SMS_LOG_FILE = "sms-codes.log";
    /** RefreshToken 有效期 7 天(秒) */
    private static final long REFRESH_TTL_SECONDS = 7 * 24 * 3600;
    /** 信任设备白名单有效期 7 天(秒) */
    private static final long TRUST_TTL_SECONDS = 7 * 24 * 3600;

    /**
     * 校验图形验证码(captchaId 为空时跳过,向后兼容)
     */
    private void verifyCaptcha(String captchaId, String captchaCode) {
        if (captchaId == null || captchaId.isBlank()) {
            return;
        }
        String key = CAPTCHA_PREFIX + captchaId;
        String saved = redisTemplate.opsForValue().get(key);
        // 一次性使用:无论对错都删除,防止暴力枚举
        redisTemplate.delete(key);
        if (saved == null || captchaCode == null || !saved.equalsIgnoreCase(captchaCode)) {
            throw new RuntimeException("图形验证码错误或已过期");
        }
    }

    /**
     * 发送短信验证码(可选图形验证码前置校验 + 60s 限频)
     *
     * @return 生成的验证码(无真实短信网关,供调用方在开发环境直接回传展示)
     */
    public String sendSmsCode(String phone, String captchaId, String captchaCode) {
        if (captchaId != null && !captchaId.isBlank()) {
            verifyCaptcha(captchaId, captchaCode);
        }
        if (phone == null || !phone.matches("^1\\d{10}$")) {
            throw new RuntimeException("手机号格式不正确");
        }
        String intervalKey = SMS_CODE_INTERVAL + phone;
        if (Boolean.TRUE.equals(redisTemplate.hasKey(intervalKey))) {
            throw new RuntimeException("验证码发送过于频繁,请稍后再试");
        }
        String code = String.format("%06d", (int) (Math.random() * 1000000));
        redisTemplate.opsForValue().set(SMS_CODE_PREFIX + phone, code, 5, TimeUnit.MINUTES);
        redisTemplate.opsForValue().set(intervalKey, "1", 60, TimeUnit.SECONDS);
        // TODO: 调用短信网关发送
        System.out.println("[SMS] 验证码: " + code + " -> " + phone);
        appendSmsLog(phone, code);
        return code;
    }

    /**
     * 模拟短信:把验证码追加写入项目内固定文件 java_backend/sms-codes.log,
     * 开发时直接打开该文件查看,无需翻控制台或临时日志。
     */
    private void appendSmsLog(String phone, String code) {
        String time = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        String line = time + "    手机 " + phone + "    验证码 " + code + System.lineSeparator();
        try {
            Files.writeString(Path.of(SMS_LOG_FILE), line,
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException e) {
            System.out.println("[SMS] 验证码日志文件写入失败: " + e.getMessage());
        }
    }

    /**
     * 注册(手机号+验证码+邀请码;密码可选)
     */
    public RegisterResult register(String phone, String code, String password, String inviteCode) {
        String savedCode = redisTemplate.opsForValue().get(SMS_CODE_PREFIX + phone);
        if (savedCode == null || !savedCode.equals(code)) {
            throw new RuntimeException("验证码错误或已过期");
        }
        if (userMapper.selectByPhone(phone) != null) {
            throw new RuntimeException("该手机号已注册");
        }
        User user = new User();
        user.setUserId(UUID.randomUUID().toString().replace("-", ""));
        user.setPhone(phone);
        String effectivePassword = (password == null || password.isBlank())
                ? UUID.randomUUID().toString().replace("-", "") : password;
        user.setPasswordHash(hashPassword(effectivePassword));
        user.setNickname("量化用户" + phone.substring(phone.length() - 4));
        userMapper.insert(user);
        if (inviteCode != null && !inviteCode.isBlank()) {
            // TODO: 绑定邀请关系(注册时绑定,不可事后修改)
            System.out.println("[INVITE] " + phone + " 使用邀请码 " + inviteCode);
        }

        String token = jwtUtil.generateToken(user.getUserId(), phone);
        redisTemplate.delete(SMS_CODE_PREFIX + phone);
        return new RegisterResult(token, user.getUserId(), phone, user.getNickname());
    }

    /**
     * 登录(密码登录 或 短信验证码登录),含异地/新设备风控判定
     */
    public LoginResult login(String phone, String password, String smsCode, String deviceFp, String ip) {
        User user = userMapper.selectByPhone(phone);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }
        boolean codeLogin = smsCode != null && !smsCode.isBlank();
        if (codeLogin) {
            String savedCode = redisTemplate.opsForValue().get(SMS_CODE_PREFIX + phone);
            redisTemplate.delete(SMS_CODE_PREFIX + phone);
            if (savedCode == null || !savedCode.equals(smsCode)) {
                throw new RuntimeException("验证码错误或已过期");
            }
        } else if (password != null) {
            if (!PasswordHasher.matches(password, user.getPasswordHash())) {
                throw new RuntimeException("手机号或密码错误");
            }
            // 旧 MD5 哈希登录成功 → 自动升级为 BCrypt 重存
            if (PasswordHasher.isLegacyMd5(user.getPasswordHash())) {
                userMapper.updatePasswordHash(user.getUserId(), PasswordHasher.encode(password));
            }
        } else {
            throw new RuntimeException("请输入密码或验证码");
        }
        if (user.getStatus() != 0) {
            throw new RuntimeException("账号已被冻结");
        }

        // 异地登录风控:设备指纹不在信任白名单 → 触发二次验证(验证码登录且信任设备时自动通过)
        String trustedKey = TRUSTED_DEVICE_PREFIX + user.getUserId() + ":" + deviceFp;
        boolean trusted = deviceFp != null && Boolean.TRUE.equals(redisTemplate.hasKey(trustedKey));
        if (deviceFp != null && !trusted && !codeLogin) {
            return LoginResult.needSecondVerify(ip);
        }
        if (codeLogin && deviceFp != null) {
            // 验证码验证通过 → 加入信任白名单 7 天
            redisTemplate.opsForValue().set(trustedKey, "1", TRUST_TTL_SECONDS, TimeUnit.SECONDS);
        }

        String token = jwtUtil.generateToken(user.getUserId(), phone);
        String refreshToken = issueRefreshToken(user.getUserId());
        return LoginResult.success(token, refreshToken, user.getUserId(), phone, user.getNickname(),
                user.getRiskLevel(), Boolean.TRUE.equals(user.getAgreementSigned()));
    }

    /**
     * 刷新 Token:校验 RefreshToken,换发新 JWT + 新 RefreshToken
     */
    public TokenPair refreshToken(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new RuntimeException("RefreshToken 不能为空");
        }
        String userId = jwtUtil.getUserIdFromToken(refreshToken);
        String saved = redisTemplate.opsForValue().get(REFRESH_PREFIX + userId);
        if (saved == null || !saved.equals(refreshToken)) {
            throw new RuntimeException("RefreshToken 无效或已过期");
        }
        User user = userMapper.selectByUserId(userId);
        if (user == null || user.getStatus() != 0) {
            throw new RuntimeException("用户状态异常");
        }
        String newAccess = jwtUtil.generateToken(userId, user.getPhone());
        String newRefresh = issueRefreshToken(userId);
        return new TokenPair(newAccess, newRefresh);
    }

    private String issueRefreshToken(String userId) {
        String token = jwtUtil.generateToken(userId, "");
        redisTemplate.opsForValue().set(REFRESH_PREFIX + userId, token, REFRESH_TTL_SECONDS, TimeUnit.SECONDS);
        return token;
    }

    /**
     * 提交风险测评
     */
    public String submitRiskAssessment(String userId, java.util.List<Integer> answers) {
        int score = answers.stream().mapToInt(Integer::intValue).sum();
        String level = calculateRiskLevel(score);
        userMapper.updateRiskLevel(userId, level);
        return level;
    }

    /**
     * 签署协议(记录签名与协议清单,服务端加时间戳存证)
     * TODO: 调用 CA 证书时间戳 + 存证 OSS
     */
    public String signAgreement(String userId, String signatureBase64, java.util.List<String> agreements) {
        userMapper.markAgreementSigned(userId);
        String sealTime = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        System.out.println("[SIGN] " + userId + " 签署协议 " + agreements +
                " 签名长度=" + (signatureBase64 != null ? signatureBase64.length() : 0));
        return sealTime;
    }

    // ══════════════════════════════════════════════
    // 内部方法
    // ══════════════════════════════════════════════

    private String hashPassword(String password) {
        return PasswordHasher.encode(password);
    }

    private String calculateRiskLevel(int score) {
        if (score <= 10) return "R1";
        if (score <= 20) return "R2";
        if (score <= 25) return "R3";
        if (score <= 30) return "R4";
        return "R5";
    }

    public record RegisterResult(String accessToken, String userId, String phone, String nickname) {}
    public record TokenPair(String accessToken, String refreshToken) {}

    /**
     * 登录结果:success 携带完整信息;needSecondVerify 仅携带风控信息
     */
    public record LoginResult(boolean needSecondVerify,
                              String accessToken, String refreshToken,
                              String userId, String phone, String nickname,
                              String riskLevel, boolean agreementSigned,
                              String loginIp, String loginCity) {
        static LoginResult needSecondVerify(String ip) {
            return new LoginResult(true, null, null, null, null, null, null, false, ip, "未知");
        }
        static LoginResult success(String token, String refresh, String userId, String phone,
                                   String nickname, String riskLevel, boolean agreementSigned) {
            return new LoginResult(false, token, refresh, userId, phone, nickname, riskLevel, agreementSigned, null, null);
        }
    }
}
