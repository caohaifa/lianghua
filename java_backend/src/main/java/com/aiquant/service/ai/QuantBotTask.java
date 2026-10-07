package com.aiquant.service.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 量化机器人调度器:每 20s 执行一轮机器人自动交易。
 * 开关 ai.bot-enabled(dev 默认开)。
 */
@Component
public class QuantBotTask {

    @Autowired
    private QuantBotEngine quantBotEngine;

    @Value("${ai.bot-enabled:true}")
    private boolean enabled;

    @Scheduled(fixedDelayString = "${ai.bot-interval-ms:20000}", initialDelay = 15_000)
    public void tick() {
        if (enabled) {
            quantBotEngine.executeAll();
        }
    }
}
