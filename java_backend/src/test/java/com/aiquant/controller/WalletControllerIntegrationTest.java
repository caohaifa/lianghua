package com.aiquant.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 钱包功能集成测试:走完整 HTTP 链路 (MockMvc → Controller → Service → MyBatis → 内存 H2),
 * 含注册鉴权、充值、提现、流水查询及各负向场景。
 *
 * 注意:运行前需停止开发服务器(释放 6379 端口给内嵌 Redis、避免文件库冲突);
 * 测试使用独立内存 H2 实例,数据互不干扰。
 */
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:h2:mem:wallet_test;MODE=MySQL;CASE_INSENSITIVE_IDENTIFIERS=TRUE;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.sql.init.schema-locations=classpath:schema-h2.sql",
        "spring.sql.init.mode=always",
        "spring.sql.init.continue-on-error=true"
})
class WalletControllerIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private StringRedisTemplate redis;
    @Autowired private ObjectMapper om;

    private static final String PWD = "test123456";
    private static int counter = 0;
    private String phone;
    private String token;

    @BeforeEach
    void setUp() throws Exception {
        // 每个测试用唯一手机号,避免内存库中重复注册
        phone = "139" + String.format("%08d", ++counter);
        // 注册新用户(先写入短信验证码,再调注册接口拿 token)
        redis.opsForValue().set("sms:code:" + phone, "123456", 5, TimeUnit.MINUTES);

        MvcResult reg = mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"" + phone + "\",\"code\":\"123456\",\"password\":\"" + PWD + "\",\"invite_code\":\"AIQUANT2026\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();
        token = om.readTree(reg.getResponse().getContentAsString())
                .path("data").path("access_token").asText();
        assertNotNull(token, "注册应返回 access_token");
    }

    private String authHeader() {
        return "Bearer " + token;
    }

    // ═══════════════ 充值 deposit ═══════════════

    @Test
    @DisplayName("充值 USDT 成功 → 余额增加,返回 balance_after")
    void deposit_usdt_success() throws Exception {
        MvcResult r = mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":1000,\"channel\":\"USDT-TRC20\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.type").value("deposit"))
                .andExpect(jsonPath("$.data.currency").value("USDT"))
                .andExpect(jsonPath("$.data.amount").value(1000))
                .andReturn();

        double balAfter = om.readTree(r.getResponse().getContentAsString())
                .path("data").path("balance_after").asDouble();
        // 初始 USDT 账户 100000 + 充值 1000
        assertEquals(101000.0, balAfter, 0.001, "充值后余额应为 101000");
    }

    @Test
    @DisplayName("充值 CNY 成功 → 余额增加")
    void deposit_cny_success() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"CNY\",\"amount\":5000,\"channel\":\"支付宝\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("deposit"))
                .andExpect(jsonPath("$.data.balance_after").value(1005000.0)); // 初始 1000000 + 5000
    }

    @Test
    @DisplayName("充值负向:非法币种返回 400")
    void deposit_invalidCurrency_400() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"BTC\",\"amount\":100}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("USDT 或 CNY")));
    }

    @Test
    @DisplayName("充值负向:金额为 0 返回 400")
    void deposit_zeroAmount_400() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("大于 0")));
    }

    @Test
    @DisplayName("充值负向:超过单笔上限(100万)返回 400")
    void deposit_exceedsMax_400() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":1000001}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("单笔充值上限")));
    }

    // ═══════════════ 提现 withdraw ═══════════════

    @Test
    @DisplayName("提现成功 → 余额扣减")
    void withdraw_success() throws Exception {
        // 先充值 2000,初始 100000 → 102000
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":2000,\"channel\":\"TRC20\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/wallet/withdraw")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":500,\"network\":\"ERC20\",\"address\":\"TTestAddr\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.type").value("withdraw"))
                .andExpect(jsonPath("$.data.balance_after").value(101500.0)); // 102000 - 500
    }

    @Test
    @DisplayName("提现负向:余额不足返回 400")
    void withdraw_insufficientBalance_400() throws Exception {
        // 初始 USDT 余额 100000,提 200000(在 500万上限内但余额不足)
        mockMvc.perform(post("/wallet/withdraw")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":200000,\"network\":\"TRC20\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("余额不足")));
    }

    @Test
    @DisplayName("提现负向:超过单笔上限(500万)返回 400")
    void withdraw_exceedsMax_400() throws Exception {
        mockMvc.perform(post("/wallet/withdraw")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":5000001,\"network\":\"TRC20\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("单笔提现上限")));
    }

    // ═══════════════ 流水 transactions ═══════════════

    @Test
    @DisplayName("流水查询:充值+提现后,列表含两条记录且倒序")
    void transactions_containsDepositAndWithdraw() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":300,\"channel\":\"TRC20\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/wallet/withdraw")
                        .header("Authorization", authHeader())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":100,\"network\":\"TRC20\",\"address\":\"T\"}"))
                .andExpect(status().isOk());

        MvcResult r = mockMvc.perform(get("/wallet/transactions")
                        .header("Authorization", authHeader())
                        .param("currency", "USDT")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andReturn();

        JsonNode list = om.readTree(r.getResponse().getContentAsString()).path("data");
        assertTrue(list.isArray() && list.size() >= 2, "流水至少 2 条");
        // 倒序:最新的(提现)在前
        assertEquals("withdraw", list.get(0).path("type").asText());
        assertEquals("deposit", list.get(1).path("type").asText());
        // 字段完整性
        JsonNode first = list.get(0);
        assertTrue(first.has("id") && first.has("amount") && first.has("channel")
                && first.has("status") && first.has("created_at"));
    }

    @Test
    @DisplayName("流水查询:默认 currency=USDT")
    void transactions_defaultCurrency() throws Exception {
        mockMvc.perform(get("/wallet/transactions")
                        .header("Authorization", authHeader()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200));
    }

    // ═══════════════ 鉴权 ═══════════════

    @Test
    @DisplayName("未携带 Token → 401")
    void noToken_401() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":100}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("未登录"));
    }

    @Test
    @DisplayName("无效 Token → 401")
    void invalidToken_401() throws Exception {
        mockMvc.perform(post("/wallet/deposit")
                        .header("Authorization", "Bearer invalid.token.value")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currency\":\"USDT\",\"amount\":100}"))
                .andExpect(status().isUnauthorized());
    }
}
