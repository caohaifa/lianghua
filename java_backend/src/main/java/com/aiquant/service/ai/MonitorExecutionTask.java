package com.aiquant.service.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * AI 自动执行调度器:周期扫描 running 监控 → AI 决策 → 下单。
 * 开关 ai.auto-trade-enabled(dev 默认开);间隔 ai.execution-interval-ms 默认 15s。
 */
@Component
public class MonitorExecutionTask {

    @Autowired
    private MonitorExecutionService monitorExecutionService;

    @Value("${ai.auto-trade-enabled:true}")
    private boolean enabled;

    @Scheduled(fixedDelayString = "${ai.execution-interval-ms:15000}", initialDelay = 10_000)
    public void tick() {
        if (enabled) {
            monitorExecutionService.executeAll();
        }
    }
}
