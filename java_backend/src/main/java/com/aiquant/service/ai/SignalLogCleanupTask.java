package com.aiquant.service.ai;

import com.aiquant.mapper.SignalLogMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * 信号历史清理:每天 03:10 删除 7 天前的 t_signal_log 流水,防止无限增长。
 * 机器人每 20s、用户监控每 15s 各追加一条,长期量大,需定期回收。
 */
@Component
public class SignalLogCleanupTask {

    private static final int RETAIN_DAYS = 7;

    @Autowired private SignalLogMapper signalLogMapper;

    @Scheduled(cron = "0 10 3 * * ?")
    public void cleanup() {
        int removed = signalLogMapper.deleteAllBefore(LocalDateTime.now().minusDays(RETAIN_DAYS));
        if (removed > 0) {
            System.out.println("[SIGNAL-LOG] 清理 " + RETAIN_DAYS + " 天前历史 " + removed + " 条");
        }
    }
}
