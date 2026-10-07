package com.aiquant.service;

import com.aiquant.mapper.AccountMapper;
import com.aiquant.mapper.WalletTransactionMapper;
import com.aiquant.model.Account;
import com.aiquant.model.WalletTransaction;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * 钱包服务:模拟环境充值(直接入账)/提现(直接出账)+ 流水记录。
 * 真实环境需对接第三方支付/链上网络,此处仅提供模拟能力。
 */
@Service
public class WalletService {

    private static final double MAX_DEPOSIT = 1_000_000d;
    private static final double MAX_WITHDRAW = 5_000_000d;
    /** 1 分钟内最多提现 3 笔 */
    private static final int WITHDRAW_RATE_LIMIT = 3;
    private static final long WITHDRAW_RATE_WINDOW_SECONDS = 60;
    /** 单日累计提现上限 */
    private static final double DAILY_WITHDRAW_LIMIT = 50_000_000d;

    @Autowired private AccountMapper accountMapper;
    @Autowired private WalletTransactionMapper txMapper;
    @Autowired private StringRedisTemplate redisTemplate;

    /** 充值:currency/amount/channel */
    @Transactional
    public Map<String, Object> deposit(String userId, String currency, double amount, String channel) {
        validate(currency, amount);
        if (amount > MAX_DEPOSIT) throw new RuntimeException("单笔充值上限 " + MAX_DEPOSIT + " " + currency);
        ensureAccount(userId, currency);
        accountMapper.addBalance(userId, currency, amount);

        WalletTransaction tx = new WalletTransaction();
        tx.setUserId(userId);
        tx.setCurrency(currency);
        tx.setType("deposit");
        tx.setAmount(amount);
        tx.setChannel(channel == null ? "simulation" : channel);
        tx.setStatus("completed");
        tx.setCreatedAt(LocalDateTime.now());
        txMapper.insert(tx);

        return vo(userId, currency, tx);
    }

    /** 提现:currency/amount/address/network */
    @Transactional
    public Map<String, Object> withdraw(String userId, String currency, double amount,
                                        String address, String network) {
        validate(currency, amount);
        if (amount > MAX_WITHDRAW) throw new RuntimeException("单笔提现上限 " + MAX_WITHDRAW + " " + currency);
        checkWithdrawRateLimit(userId);
        checkDailyWithdrawLimit(userId, currency, amount); // 只读校验,不写 Redis
        // 原子扣款:余额不足(含账户不存在)返回 0 直接失败,此时尚未触碰任何 Redis 计数
        if (accountMapper.debitIfSufficient(userId, currency, amount) == 0) {
            throw new RuntimeException(currency + " 可用余额不足");
        }

        WalletTransaction tx = new WalletTransaction();
        tx.setUserId(userId);
        tx.setCurrency(currency);
        tx.setType("withdraw");
        tx.setAmount(amount);
        tx.setChannel(network == null ? "TRC20" : network);
        tx.setAddress(address == null ? "" : address);
        tx.setStatus("completed");
        tx.setCreatedAt(LocalDateTime.now());
        txMapper.insert(tx);

        // DB 全部成功后再记账:失败提现(余额不足/超上限)不再污染当日额度与限频计数
        recordWithdrawRate(userId);
        recordDailyWithdraw(userId, currency, amount);

        return vo(userId, currency, tx);
    }

    public List<Map<String, Object>> list(String userId, String currency, int page, int size) {
        String cur = (currency == null || currency.isBlank()) ? "USDT" : currency;
        int lim = Math.max(1, Math.min(size, 200));
        int off = Math.max(0, page) * lim;
        List<WalletTransaction> rows = txMapper.selectByUser(userId, cur, lim, off);
        List<Map<String, Object>> list = new java.util.ArrayList<>();
        for (WalletTransaction t : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", t.getId());
            m.put("type", t.getType());
            m.put("currency", t.getCurrency());
            m.put("amount", t.getAmount());
            m.put("channel", t.getChannel());
            m.put("address", t.getAddress());
            m.put("status", t.getStatus());
            m.put("created_at", t.getCreatedAt());
            list.add(m);
        }
        return list;
    }

    // ── 内部 ──

    private void validate(String currency, double amount) {
        if (currency == null || (!"USDT".equals(currency) && !"CNY".equals(currency))) {
            throw new RuntimeException("币种仅支持 USDT 或 CNY");
        }
        if (amount <= 0) throw new RuntimeException("金额必须大于 0");
    }

    private void ensureAccount(String userId, String currency) {
        Account acc = accountMapper.selectByUserAndCurrency(userId, currency);
        if (acc == null) {
            if ("USDT".equals(currency)) accountMapper.initUsdt(userId);
            else accountMapper.initCny(userId);
        }
    }

    // ── 提现限频 ──

    private static final String WITHDRAW_RATE_PREFIX = "withdraw:rate:";
    private static final String WITHDRAW_DAILY_PREFIX = "withdraw:daily:";

    private void checkWithdrawRateLimit(String userId) {
        String key = WITHDRAW_RATE_PREFIX + userId;
        String count = redisTemplate.opsForValue().get(key);
        int current = count == null ? 0 : Integer.parseInt(count);
        if (current >= WITHDRAW_RATE_LIMIT) {
            throw new RuntimeException("提现过于频繁,请 1 分钟后再试");
        }
    }

    private void recordWithdrawRate(String userId) {
        String key = WITHDRAW_RATE_PREFIX + userId;
        Long ttl = redisTemplate.getExpire(key);
        if (ttl == null || ttl < 0) {
            redisTemplate.opsForValue().set(key, "1", WITHDRAW_RATE_WINDOW_SECONDS, TimeUnit.SECONDS);
        } else {
            redisTemplate.opsForValue().increment(key);
        }
    }

    private void checkDailyWithdrawLimit(String userId, String currency, double amount) {
        String key = dailyKey(userId, currency);
        String total = redisTemplate.opsForValue().get(key);
        double current = total == null ? 0 : Double.parseDouble(total);
        if (current + amount > DAILY_WITHDRAW_LIMIT) {
            throw new RuntimeException(currency + " 单日累计提现已达上限 " + DAILY_WITHDRAW_LIMIT);
        }
    }

    /** 提现成功后累计当日额度(INCRBYFLOAT);与只读校验分离,避免失败请求污染计数 */
    private void recordDailyWithdraw(String userId, String currency, double amount) {
        String key = dailyKey(userId, currency);
        Long ttl = redisTemplate.getExpire(key);
        if (ttl == null || ttl < 0) {
            redisTemplate.opsForValue().set(key, String.valueOf(amount), 25, TimeUnit.HOURS);
        } else {
            redisTemplate.opsForValue().increment(key, amount); // Redis INCRBYFLOAT
        }
    }

    private static String dailyKey(String userId, String currency) {
        return WITHDRAW_DAILY_PREFIX + userId + ":" + currency + ":" + java.time.LocalDate.now();
    }

    private Map<String, Object> vo(String userId, String currency, WalletTransaction tx) {
        Account acc = accountMapper.selectByUserAndCurrency(userId, currency);
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("transaction_id", tx.getId());
        vo.put("type", tx.getType());
        vo.put("currency", currency);
        vo.put("amount", tx.getAmount());
        vo.put("balance_after", acc == null ? 0 : acc.getBalance());
        vo.put("status", tx.getStatus());
        vo.put("created_at", tx.getCreatedAt());
        return vo;
    }
}
