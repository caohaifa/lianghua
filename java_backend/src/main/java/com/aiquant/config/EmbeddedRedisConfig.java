package com.aiquant.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import redis.embedded.RedisServer;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.io.IOException;

/**
 * 嵌入式 Redis:本地开发免安装 Redis 服务器,进程内启动 6379 端口实例。
 * 数据存于内存,重启即清空(验证码/RefreshToken 等临时数据,可接受)。
 * 生产环境设 redis.embedded=false 关闭,改用独立 Redis(spring.redis.host/password)。
 */
@Configuration
@ConditionalOnProperty(name = "redis.embedded", havingValue = "true", matchIfMissing = true)
public class EmbeddedRedisConfig {

    private RedisServer redisServer;

    @PostConstruct
    public void start() {
        try {
            redisServer = new RedisServer(6379);
            redisServer.start();
        } catch (IOException e) {
            throw new IllegalStateException("嵌入式 Redis 启动失败(6379 端口被占用?)", e);
        }
    }

    @PreDestroy
    public void stop() {
        if (redisServer != null && redisServer.isActive()) {
            try {
                redisServer.stop();
            } catch (IOException e) {
                // 关闭失败不影响应用退出
            }
        }
    }
}
