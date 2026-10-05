package com.aiquant.util;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;

/**
 * API Secret 落库加解密(AES/CBC/PKCS5Padding + 随机 IV)。
 * 密文格式: Base64( IV(16B) + 密文 )。
 * 密钥由配置 security.api-key-secret 注入(生产环境用环境变量覆盖)。
 */
@Component
public class AesUtil {

    private final SecretKeySpec keySpec;
    private final SecureRandom random = new SecureRandom();

    public AesUtil(@Value("${security.api-key-secret:aiquant-default-api-key-secret!}") String secret) {
        // 归一化为 16 字节 AES-128 密钥:不足补 0,超出截断
        byte[] raw = secret.getBytes(StandardCharsets.UTF_8);
        byte[] key = Arrays.copyOf(raw, 16);
        this.keySpec = new SecretKeySpec(key, "AES");
    }

    public String encrypt(String plain) {
        if (plain == null) return null;
        try {
            byte[] iv = new byte[16];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, new IvParameterSpec(iv));
            byte[] encrypted = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] combined = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new RuntimeException("敏感信息加密失败");
        }
    }

    public String decrypt(String cipherText) {
        if (cipherText == null) return null;
        try {
            byte[] combined = Base64.getDecoder().decode(cipherText);
            byte[] iv = Arrays.copyOfRange(combined, 0, 16);
            byte[] encrypted = Arrays.copyOfRange(combined, 16, combined.length);
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, keySpec, new IvParameterSpec(iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("敏感信息解密失败");
        }
    }

    /** 脱敏展示: 前4后4, 中间打码 */
    public static String mask(String plain) {
        if (plain == null || plain.length() < 8) return "****";
        return plain.substring(0, 4) + "****" + plain.substring(plain.length() - 4);
    }
}
