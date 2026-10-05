package com.aiquant.service;

import com.aiquant.mapper.AdminUserMapper;
import com.aiquant.model.AdminUser;
import com.aiquant.util.JwtUtil;
import com.aiquant.util.PasswordHasher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

/**
 * 管理员认证(含防暴力破解:同一用户名 10 分钟内失败 5 次则锁定)
 */
@Service
public class AdminAuthService {

    @Autowired
    private AdminUserMapper adminUserMapper;
    @Autowired
    private JwtUtil jwtUtil;
    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String FAIL_KEY_PREFIX = "admin:fail:";
    private static final int MAX_FAIL = 5;
    private static final long LOCK_MINUTES = 10;

    /**
     * 管理员登录
     *
     * @return [token, adminUser]
     */
    public LoginResult login(String username, String password) {
        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            throw new RuntimeException("用户名或密码不能为空");
        }
        String failKey = FAIL_KEY_PREFIX + username;
        String failCountStr = redisTemplate.opsForValue().get(failKey);
        int failCount = failCountStr == null ? 0 : Integer.parseInt(failCountStr);
        if (failCount >= MAX_FAIL) {
            throw new RuntimeException("登录失败次数过多,请 " + LOCK_MINUTES + " 分钟后再试");
        }

        AdminUser admin = adminUserMapper.selectByUsername(username);
        if (admin == null || !PasswordHasher.matches(password, admin.getPasswordHash())) {
            // 失败计数+1,失败时才设置过期(避免成功登录后还残留计数)
            int next = failCount + 1;
            redisTemplate.opsForValue().set(failKey, String.valueOf(next), LOCK_MINUTES, TimeUnit.MINUTES);
            throw new RuntimeException("用户名或密码错误");
        }
        // 旧 MD5 哈希登录成功 → 自动升级为 BCrypt 重存
        if (PasswordHasher.isLegacyMd5(admin.getPasswordHash())) {
            adminUserMapper.updatePasswordHash(admin.getId(), PasswordHasher.encode(password));
        }
        if (admin.getStatus() != null && admin.getStatus() != 0) {
            throw new RuntimeException("账号已停用,请联系超级管理员");
        }
        // 登录成功清除失败计数
        redisTemplate.delete(failKey);
        String token = jwtUtil.generateAdminToken(admin.getId(), admin.getUsername(), admin.getRole());
        return new LoginResult(token, admin);
    }

    public record LoginResult(String token, AdminUser admin) {}
}
