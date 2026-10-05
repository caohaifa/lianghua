package com.aiquant.util;

import javax.imageio.ImageIO;
import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.UUID;

/**
 * 图形验证码生成器(Java 2D 实现,无第三方依赖)
 * 输出 4 位字符 + 干扰线,PNG Base64(data-uri 格式,前端可直接 Image.memory 展示)
 * 验证码文本由 Redis 存储(5 分钟有效),见 AuthService
 */
public final class CaptchaGenerator {

    private static final SecureRandom RANDOM = new SecureRandom();
    // 去掉易混淆字符 I O 0 1
    private static final char[] CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();
    private static final int WIDTH = 120;
    private static final int HEIGHT = 44;

    private CaptchaGenerator() {
    }

    /**
     * @param id          验证码 ID(前端回传用)
     * @param code        验证码文本(仅存 Redis,勿返回给前端)
     * @param imageBase64 data-uri 格式 Base64 PNG
     */
    public record Captcha(String id, String code, String imageBase64) {}

    public static Captcha generate() {
        StringBuilder code = new StringBuilder(4);
        for (int i = 0; i < 4; i++) {
            code.append(CHARS[RANDOM.nextInt(CHARS.length)]);
        }

        BufferedImage image = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        try {
            // 深色背景(与 APP 主题一致)
            g.setColor(new Color(0x1C, 0x23, 0x33));
            g.fillRect(0, 0, WIDTH, HEIGHT);
            // 干扰线
            g.setStroke(new BasicStroke(1.2f));
            for (int i = 0; i < 6; i++) {
                g.setColor(randomColor());
                g.drawLine(RANDOM.nextInt(WIDTH), RANDOM.nextInt(HEIGHT),
                        RANDOM.nextInt(WIDTH), RANDOM.nextInt(HEIGHT));
            }
            // 验证码字符
            g.setFont(new Font("Arial", Font.BOLD, 28));
            for (int i = 0; i < 4; i++) {
                g.setColor(randomLightColor());
                g.drawString(String.valueOf(code.charAt(i)), 12 + i * 26, 30 + RANDOM.nextInt(8));
            }
            // 噪点
            for (int i = 0; i < 60; i++) {
                image.setRGB(RANDOM.nextInt(WIDTH), RANDOM.nextInt(HEIGHT), randomColor().getRGB());
            }
        } finally {
            g.dispose();
        }

        String base64;
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            ImageIO.write(image, "png", out);
            base64 = "data:image/png;base64," + Base64.getEncoder().encodeToString(out.toByteArray());
        } catch (Exception e) {
            throw new IllegalStateException("生成验证码图片失败", e);
        }
        return new Captcha(UUID.randomUUID().toString().replace("-", ""), code.toString(), base64);
    }

    private static Color randomColor() {
        return new Color(RANDOM.nextInt(256), RANDOM.nextInt(256), RANDOM.nextInt(256));
    }

    private static Color randomLightColor() {
        return new Color(180 + RANDOM.nextInt(76), 180 + RANDOM.nextInt(76), 180 + RANDOM.nextInt(76));
    }
}
