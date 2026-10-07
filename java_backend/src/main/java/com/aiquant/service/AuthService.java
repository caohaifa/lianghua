package com.aiquant.service;

import com.aiquant.mapper.AgreementSignatureMapper;
import com.aiquant.mapper.UserMapper;
import com.aiquant.model.AgreementSignature;
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
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Service
public class AuthService {

    @Autowired
    private UserMapper userMapper;
    @Autowired
    private AgreementSignatureMapper agreementSignatureMapper;
    @Autowired
    private JwtUtil jwtUtil;
    @Autowired
    private StringRedisTemplate redisTemplate;

    /** 内测邀请码(生产环境必须通过 INVITE_CODE 环境变量注入,留空则不强制邀请码) */
    @org.springframework.beans.factory.annotation.Value("${invite.code:}")
    private String inviteCode;

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
        String code = String.format("%06d", new SecureRandom().nextInt(1000000));
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
     * 内测模式:配置了 invite.code 时邀请码必填且必须匹配;未配置则邀请码选填。
     */
    public RegisterResult register(String phone, String code, String password, String inviteCode) {
        String savedCode = redisTemplate.opsForValue().get(SMS_CODE_PREFIX + phone);
        if (savedCode == null || !savedCode.equals(code)) {
            throw new RuntimeException("验证码错误或已过期");
        }
        if (userMapper.selectByPhone(phone) != null) {
            throw new RuntimeException("该手机号已注册");
        }
        // 邀请码校验与关系绑定(全局内测码 / 用户专属邀请码)
        String invitedBy = resolveInvite(inviteCode);
        User user = new User();
        user.setUserId(UUID.randomUUID().toString().replace("-", ""));
        user.setPhone(phone);
        boolean passwordProvided = password != null && !password.isBlank();
        String effectivePassword = passwordProvided
                ? password : UUID.randomUUID().toString().replace("-", "");
        user.setPasswordHash(hashPassword(effectivePassword));
        user.setNickname("量化用户" + phone.substring(phone.length() - 4));
        user.setInvitedBy(invitedBy);
        userMapper.insert(user);

        String token = jwtUtil.generateToken(user.getUserId(), phone);
        redisTemplate.delete(SMS_CODE_PREFIX + phone);
        // 未设密码时提示用户后续设置
        String hint = passwordProvided ? null : "未设置登录密码,请登录后在设置中补充密码";
        return new RegisterResult(token, user.getUserId(), phone, user.getNickname(), hint);
    }

    /**
     * 邀请码解析(匹配顺序):
     *   1) 全局内测码(invite.code 配置)命中 → 返回 null,不建立邀请关系;
     *   2) 用户专属邀请码(= 邀请人 userId)命中 → 返回邀请人 userId,写入 t_user.invited_by;
     *   3) 均未命中 → 配置了内测码(强制邀请)时拒绝,未配置时忽略无效码(兼容旧客户端)。
     */
    private String resolveInvite(String inviteCode) {
        boolean globalRequired = this.inviteCode != null && !this.inviteCode.isBlank();
        boolean provided = inviteCode != null && !inviteCode.isBlank();
        if (!provided) {
            if (globalRequired) throw new RuntimeException("内测阶段需填写邀请码");
            return null;
        }
        if (globalRequired && this.inviteCode.equals(inviteCode)) {
            return null; // 全局内测码,不建立邀请关系
        }
        User inviter = userMapper.selectByUserId(inviteCode.trim());
        if (inviter != null) {
            return inviter.getUserId(); // 用户专属邀请码 → 绑定邀请关系
        }
        if (globalRequired) throw new RuntimeException("邀请码无效");
        return null;
    }

    /** 当前用户专属邀请码(= userId,新用户注册时填入即可建立邀请关系) */
    public String getUserInviteCode(String userId) {
        return userId;
    }

    /**
     * 重置密码(短信验证码 + 新密码)
     */
    public void resetPassword(String phone, String code, String newPassword) {
        String savedCode = redisTemplate.opsForValue().get(SMS_CODE_PREFIX + phone);
        if (savedCode == null || !savedCode.equals(code)) {
            throw new RuntimeException("验证码错误或已过期");
        }
        if (newPassword == null || newPassword.length() < 6) {
            throw new RuntimeException("新密码至少 6 位");
        }
        User user = userMapper.selectByPhone(phone);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }
        userMapper.updatePasswordHash(user.getUserId(), hashPassword(newPassword));
        redisTemplate.delete(SMS_CODE_PREFIX + phone);
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
     * 签署协议(记录签名、协议清单、签署环境与内容哈希,服务端加时间戳存证)。
     * content_hash = SHA-256(userId|agreements|signatureImg|sealTime|ip),
     * 供事后校验存证未被篡改;CA 可信时间戳与 OSS 长期归档待外部服务接入。
     */
    public String signAgreement(String userId, String signatureBase64, java.util.List<String> agreements,
                                String ip, String userAgent) {
        userMapper.markAgreementSigned(userId);
        String sealTime = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        AgreementSignature sig = new AgreementSignature();
        sig.setUserId(userId);
        sig.setAgreements(String.join(",", agreements));
        sig.setSignatureImg(signatureBase64);
        sig.setSealTime(sealTime);
        sig.setIp(ip);
        sig.setUserAgent(userAgent != null && userAgent.length() > 250
                ? userAgent.substring(0, 250) : userAgent);
        sig.setContentHash(sha256(userId + "|" + sig.getAgreements() + "|" + signatureBase64 + "|" + sealTime + "|" + ip));
        agreementSignatureMapper.insert(sig);
        return sealTime;
    }

    /** SHA-256 十六进制(存证完整性校验;失败不阻断签署,仅缺校验字段) */
    private static String sha256(String data) {
        try {
            byte[] hash = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(data.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
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

    public record RegisterResult(String accessToken, String userId, String phone, String nickname, String passwordHint) {
        public RegisterResult(String accessToken, String userId, String phone, String nickname) {
            this(accessToken, userId, phone, nickname, null);
        }
    }
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
