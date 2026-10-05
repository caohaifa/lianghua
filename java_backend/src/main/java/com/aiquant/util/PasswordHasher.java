package com.aiquant.util;

import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.util.DigestUtils;

import java.nio.charset.StandardCharsets;

/**
 * 密码哈希:新密码一律 BCrypt;存量 MD5 哈希登录验证通过后由调用方升级重存。
 * BCrypt 哈希以 $2a/$2b/$2y 开头,MD5 为 32 位十六进制,据此区分算法。
 */
public final class PasswordHasher {

    private PasswordHasher() {}

    /** 生成 BCrypt 哈希(强度 10) */
    public static String encode(String raw) {
        return BCrypt.hashpw(raw, BCrypt.gensalt());
    }

    /** 校验:按存储格式自动选择 BCrypt / MD5 */
    public static boolean matches(String raw, String stored) {
        if (raw == null || stored == null) {
            return false;
        }
        if (stored.startsWith("$2")) {
            return BCrypt.checkpw(raw, stored);
        }
        return stored.equals(md5(raw));
    }

    /** 是否为旧版 MD5 哈希(登录成功后可据此升级重存) */
    public static boolean isLegacyMd5(String stored) {
        return stored != null && !stored.startsWith("$2");
    }

    private static String md5(String raw) {
        return DigestUtils.md5DigestAsHex(raw.getBytes(StandardCharsets.UTF_8));
    }
}
