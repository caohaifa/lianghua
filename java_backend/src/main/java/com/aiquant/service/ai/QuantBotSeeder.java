package com.aiquant.service.ai;

import com.aiquant.mapper.AccountMapper;
import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.QuantBotMapper;
import com.aiquant.mapper.StrategyPublishMapper;
import com.aiquant.mapper.UserMapper;
import com.aiquant.model.Monitor;
import com.aiquant.model.QuantBot;
import com.aiquant.model.StrategyPublish;
import com.aiquant.model.User;
import com.aiquant.util.PasswordHasher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * 启动播种:幂等创建 4 个开源策略量化机器人(EMA交叉/RSI/网格/布林突破,仅加密货币)。
 * 每个机器人 = 系统用户(10万USDT) + bot 监控 + 自动审核通过的发布。
 * 已存在(按 bot user_id 判定)则跳过。
 */
@Component
@Order(20)
public class QuantBotSeeder implements ApplicationRunner {

    private record BotDef(String userId, String phone, String nickname, String strategyKey,
                          String strategyLabel, String symbol, String title, String description) {}

    private static final List<BotDef> BOTS = List.of(
            new BotDef("bot_ema", "10000000001", "EMA 交叉机器人", "ema_cross",
                    "EMA均线交叉", "BTC/USDT",
                    "EMA 交叉机器人 · BTC 自动带单",
                    "参考 freqtrade EMA12/26 金叉策略,15m 周期自动买卖"),
            new BotDef("bot_rsi", "10000000002", "RSI 反转机器人", "rsi_rev",
                    "RSI超买超卖", "ETH/USDT",
                    "RSI 反转机器人 · ETH 自动带单",
                    "RSI14 低于30买入、高于70卖出,震荡市自动反转"),
            new BotDef("bot_grid", "10000000003", "网格做市机器人", "grid",
                    "网格做市", "BTC/USDT",
                    "BTC 网格做市机器人 · 自动低买高卖",
                    "参考 Hummingbot 网格策略,2% 间距5档自动做市"),
            new BotDef("bot_boll", "10000000004", "布林突破机器人", "boll_break",
                    "布林带突破", "ETH/USDT",
                    "布林突破机器人 · ETH 自动带单",
                    "突破布林上轨买入、跌回中轨卖出,捕捉趋势启动")
    );

    @Autowired private UserMapper userMapper;
    @Autowired private AccountMapper accountMapper;
    @Autowired private MonitorMapper monitorMapper;
    @Autowired private StrategyPublishMapper publishMapper;
    @Autowired private QuantBotMapper quantBotMapper;

    @Override
    public void run(ApplicationArguments args) {
        for (BotDef def : BOTS) {
            try {
                if (userMapper.selectByUserId(def.userId()) != null) continue;
                seedOne(def);
                System.out.println("[BOT] 已创建机器人: " + def.nickname());
            } catch (Exception e) {
                System.out.println("[BOT] 机器人播种失败 " + def.userId() + ": " + e.getMessage());
            }
        }
    }

    private void seedOne(BotDef def) {
        // 1. 系统用户(随机密码,不允许登录入口)
        User u = new User();
        u.setUserId(def.userId());
        u.setPhone(def.phone());
        u.setNickname(def.nickname());
        u.setPasswordHash(PasswordHasher.encode(UUID.randomUUID().toString()));
        userMapper.insert(u);
        userMapper.updateRiskLevel(def.userId(), "R2");
        userMapper.markAgreementSigned(def.userId());

        // 2. 现货账户(10 万 USDT 模拟金)
        accountMapper.initUsdt(def.userId());

        // 3. bot 监控
        Monitor m = new Monitor();
        m.setUserId(def.userId());
        m.setSymbol(def.symbol());
        m.setStrategy(def.strategyLabel());
        monitorMapper.insertBot(m);

        // 4. 自动审核通过的发布
        StrategyPublish p = new StrategyPublish();
        p.setLeaderId(def.userId());
        p.setMonitorId(m.getId());
        p.setTitle(def.title());
        p.setDescription(def.description());
        p.setStrategy(def.strategyLabel());
        p.setSymbol(def.symbol());
        publishMapper.insertBotPublish(p);

        // 5. 机器人登记
        QuantBot bot = new QuantBot();
        bot.setBotUserId(def.userId());
        bot.setMonitorId(m.getId());
        bot.setStrategyKey(def.strategyKey());
        bot.setSymbol(def.symbol());
        bot.setConfigJson("{}");
        quantBotMapper.insert(bot);
    }
}
