package com.aiquant.service;

import com.aiquant.mapper.AccountMapper;
import com.aiquant.mapper.WalletTransactionMapper;
import com.aiquant.model.Account;
import com.aiquant.model.WalletTransaction;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * WalletService 单元测试:充值/提现/流水的业务逻辑与边界校验。
 * 使用 Mockito 隔离 AccountMapper、WalletTransactionMapper,只测服务层纯逻辑。
 */
@ExtendWith(MockitoExtension.class)
class WalletServiceTest {

    @Mock private AccountMapper accountMapper;
    @Mock private WalletTransactionMapper txMapper;
    @Mock private StringRedisTemplate redisTemplate;
    @Mock private ValueOperations<String, String> valueOps;

    @InjectMocks private WalletService walletService;

    private static final String USER = "user-test-001";

    @BeforeEach
    void setUp() {
        // insert 后回填主键(模拟 @Options(useGeneratedKeys))。
        // 部分校验类用例不会走到 insert,故使用 lenient 避免严格桩异常。
        lenient().doAnswer(inv -> {
            WalletTransaction tx = inv.getArgument(0);
            tx.setId(1001L);
            return 1;
        }).when(txMapper).insert(any(WalletTransaction.class));

        // Redis 桩:限频/日限计数一律读空(视为首次),TTL 读 -1(触发 set 分支)
        lenient().when(redisTemplate.opsForValue()).thenReturn(valueOps);
        lenient().when(valueOps.get(anyString())).thenReturn(null);
        lenient().when(redisTemplate.getExpire(anyString())).thenReturn(-1L);
    }

    private Account account(double balance) {
        Account a = new Account();
        a.setUserId(USER);
        a.setCurrency("USDT");
        a.setBalance(balance);
        return a;
    }

    // ═══════════════ 充值 deposit ═══════════════

    @Test
    @DisplayName("充值成功:账户已存在 → 增加余额,流水入账,返回 balance_after")
    void deposit_success_existingAccount() {
        when(accountMapper.selectByUserAndCurrency(USER, "USDT"))
                .thenReturn(account(5000d))
                .thenReturn(account(5500d)); // 充值后余额

        Map<String, Object> vo = walletService.deposit(USER, "USDT", 500d, "USDT-TRC20");

        assertEquals("deposit", vo.get("type"));
        assertEquals(500d, vo.get("amount"));
        assertEquals(5500d, vo.get("balance_after"));
        assertEquals("completed", vo.get("status"));
        assertNotNull(vo.get("created_at"));

        verify(accountMapper).addBalance(USER, "USDT", 500d);
        verify(accountMapper, never()).initUsdt(any());
        verify(txMapper).insert(any(WalletTransaction.class));
    }

    @Test
    @DisplayName("充值成功:账户不存在 → 懒初始化 USDT 账户")
    void deposit_success_accountNotInited() {
        when(accountMapper.selectByUserAndCurrency(USER, "USDT"))
                .thenReturn(null)              // ensureAccount 查到空 → initUsdt
                .thenReturn(account(100000d));  // vo 查询返回初始余额

        walletService.deposit(USER, "USDT", 1000d, "银行卡");

        verify(accountMapper).initUsdt(USER);
        verify(accountMapper, never()).initCny(any());
    }

    @Test
    @DisplayName("充值成功:CNY 账户不存在 → 懒初始化 CNY 账户")
    void deposit_success_cnyAccountNotInited() {
        when(accountMapper.selectByUserAndCurrency(USER, "CNY"))
                .thenReturn(null).thenReturn(account(1000000d));

        walletService.deposit(USER, "CNY", 1000d, "支付宝");

        verify(accountMapper).initCny(USER);
        verify(accountMapper, never()).initUsdt(any());
    }

    @Test
    @DisplayName("充值:渠道为空时默认 simulation")
    void deposit_nullChannel_defaultsToSimulation() {
        when(accountMapper.selectByUserAndCurrency(any(), any()))
                .thenReturn(account(0d)).thenReturn(account(0d));

        ArgumentCaptor<WalletTransaction> cap = ArgumentCaptor.forClass(WalletTransaction.class);
        walletService.deposit(USER, "USDT", 10d, null);
        verify(txMapper).insert(cap.capture());
        assertEquals("simulation", cap.getValue().getChannel());
    }

    @Test
    @DisplayName("充值负向:非法币种抛出")
    void deposit_invalidCurrency_throws() {
        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> walletService.deposit(USER, "BTC", 100d, "TRC20"));
        assertTrue(ex.getMessage().contains("USDT 或 CNY"));
        verifyNoInteractions(txMapper);
    }

    @Test
    @DisplayName("充值负向:金额为 0 抛出")
    void deposit_zeroAmount_throws() {
        assertThrows(RuntimeException.class,
                () -> walletService.deposit(USER, "USDT", 0d, "TRC20"));
    }

    @Test
    @DisplayName("充值负向:金额为负抛出")
    void deposit_negativeAmount_throws() {
        assertThrows(RuntimeException.class,
                () -> walletService.deposit(USER, "USDT", -10d, "TRC20"));
    }

    @Test
    @DisplayName("充值负向:超过单笔上限(100万)抛出")
    void deposit_exceedsMax_throws() {
        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> walletService.deposit(USER, "USDT", 1_000_001d, "TRC20"));
        assertTrue(ex.getMessage().contains("单笔充值上限"));
        verifyNoInteractions(txMapper);
    }

    // ═══════════════ 提现 withdraw ═══════════════

    @Test
    @DisplayName("提现成功:余额充足 → 原子扣款,流水入账,记账限频/日限")
    void withdraw_success() {
        when(accountMapper.debitIfSufficient(USER, "USDT", 300d)).thenReturn(1);
        when(accountMapper.selectByUserAndCurrency(USER, "USDT")).thenReturn(account(700d)); // vo 扣后余额

        Map<String, Object> vo = walletService.withdraw(USER, "USDT", 300d,
                "TWithdrawAddr", "ERC20");

        assertEquals("withdraw", vo.get("type"));
        assertEquals(300d, vo.get("amount"));
        assertEquals(700d, vo.get("balance_after"));

        verify(accountMapper).debitIfSufficient(USER, "USDT", 300d);
        verify(valueOps).set(startsWith("withdraw:daily:"), eq("300.0"), eq(25L), any());
    }

    @Test
    @DisplayName("提现成功:网络为空默认 TRC20,地址为空默认空串")
    void withdraw_nullNetworkAndAddress() {
        when(accountMapper.debitIfSufficient(any(), any(), anyDouble())).thenReturn(1);
        when(accountMapper.selectByUserAndCurrency(any(), any())).thenReturn(account(1000d));

        ArgumentCaptor<WalletTransaction> cap = ArgumentCaptor.forClass(WalletTransaction.class);
        walletService.withdraw(USER, "USDT", 10d, null, null);
        verify(txMapper).insert(cap.capture());
        assertEquals("TRC20", cap.getValue().getChannel());
        assertEquals("", cap.getValue().getAddress());
    }

    @Test
    @DisplayName("提现负向:余额不足(原子扣款返回0)抛出,且不记日限")
    void withdraw_insufficientBalance_throws() {
        when(accountMapper.debitIfSufficient(USER, "USDT", 100d)).thenReturn(0);

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> walletService.withdraw(USER, "USDT", 100d, "addr", "TRC20"));
        assertTrue(ex.getMessage().contains("余额不足"));
        verifyNoInteractions(txMapper);
        verify(valueOps, never()).set(startsWith("withdraw:daily:"), anyString(), anyLong(), any());
    }

    @Test
    @DisplayName("提现负向:账户不存在(扣款0行)抛余额不足")
    void withdraw_accountNull_throws() {
        when(accountMapper.debitIfSufficient(any(), any(), anyDouble())).thenReturn(0);
        assertThrows(RuntimeException.class,
                () -> walletService.withdraw(USER, "USDT", 10d, "addr", "TRC20"));
    }

    @Test
    @DisplayName("提现负向:超过单笔上限(500万)抛出")
    void withdraw_exceedsMax_throws() {
        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> walletService.withdraw(USER, "USDT", 5_000_001d, "addr", "TRC20"));
        assertTrue(ex.getMessage().contains("单笔提现上限"));
        verifyNoInteractions(txMapper);
    }

    @Test
    @DisplayName("提现负向:非法币种抛出")
    void withdraw_invalidCurrency_throws() {
        assertThrows(RuntimeException.class,
                () -> walletService.withdraw(USER, "BTC", 1d, "addr", "TRC20"));
    }

    // ═══════════════ 流水 list ═══════════════

    @Test
    @DisplayName("流水查询:返回 snake_case 字段映射")
    void list_mapsFieldsToSnakeCase() {
        WalletTransaction tx = new WalletTransaction();
        tx.setId(7L);
        tx.setType("deposit");
        tx.setCurrency("USDT");
        tx.setAmount(500d);
        tx.setChannel("TRC20");
        tx.setAddress("");
        tx.setStatus("completed");
        tx.setCreatedAt(java.time.LocalDateTime.now());
        when(txMapper.selectByUser(USER, "USDT", 50, 0)).thenReturn(List.of(tx));

        List<Map<String, Object>> list = walletService.list(USER, "USDT", 0, 50);

        assertEquals(1, list.size());
        Map<String, Object> m = list.get(0);
        assertEquals(7L, m.get("id"));
        assertEquals("deposit", m.get("type"));
        assertEquals(500d, m.get("amount"));
        assertEquals("TRC20", m.get("channel"));
        assertNotNull(m.get("created_at"));
    }

    @Test
    @DisplayName("流水查询:currency 为空时默认 USDT")
    void list_nullCurrency_defaultsUsdt() {
        when(txMapper.selectByUser(any(), eq("USDT"), anyInt(), anyInt())).thenReturn(List.of());
        walletService.list(USER, null, 1, 10);
        verify(txMapper).selectByUser(USER, "USDT", 10, 10);
    }

    @Test
    @DisplayName("流水查询:currency 空白字符串默认 USDT")
    void list_blankCurrency_defaultsUsdt() {
        when(txMapper.selectByUser(any(), eq("USDT"), anyInt(), anyInt())).thenReturn(List.of());
        walletService.list(USER, "   ", 1, 10);
        verify(txMapper).selectByUser(USER, "USDT", 10, 10);
    }

    @Test
    @DisplayName("流水查询:size 超过 200 时被钳制为 200")
    void list_limitClampedTo200() {
        when(txMapper.selectByUser(any(), any(), anyInt(), anyInt())).thenReturn(List.of());
        walletService.list(USER, "USDT", 1, 999);
        verify(txMapper).selectByUser(USER, "USDT", 200, 200);
    }

    @Test
    @DisplayName("流水查询:size 小于 1 时被钳制为 1")
    void list_limitClampedToOne() {
        when(txMapper.selectByUser(any(), any(), anyInt(), anyInt())).thenReturn(List.of());
        walletService.list(USER, "USDT", 1, 0);
        verify(txMapper).selectByUser(USER, "USDT", 1, 1);
    }

    @Test
    @DisplayName("流水查询:page 为负时钳制为 0(偏移量为 0)")
    void list_negativePage_clampedToZeroOffset() {
        when(txMapper.selectByUser(any(), any(), anyInt(), anyInt())).thenReturn(List.of());
        walletService.list(USER, "USDT", -1, 10);
        verify(txMapper).selectByUser(USER, "USDT", 10, 0);
    }
}
