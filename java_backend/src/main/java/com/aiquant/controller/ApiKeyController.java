package com.aiquant.controller;

import com.aiquant.mapper.BrokerAccountMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.BrokerAccount;
import com.aiquant.util.AesUtil;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.*;

/**
 * 交易所 API Key 管理。
 * secret_key 落库前 AES 加密;接口只返回脱敏后的 api_key,永不回传 secret。
 */
@RestController
@RequestMapping("/api-keys")
public class ApiKeyController {

    private static final Set<String> SUPPORTED = Set.of("binance", "okx");

    @Autowired
    private BrokerAccountMapper brokerAccountMapper;
    @Autowired
    private AesUtil aesUtil;

    @GetMapping
    public ApiResponse<List<Map<String, Object>>> list(HttpServletRequest request) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (BrokerAccount a : brokerAccountMapper.selectByUser(uid(request))) {
            Map<String, Object> vo = new LinkedHashMap<>();
            vo.put("id", a.getId());
            vo.put("exchange", a.getExchange());
            vo.put("api_key_masked", AesUtil.mask(a.getApiKey()));
            vo.put("status", a.getStatus());
            vo.put("created_at", a.getCreatedAt());
            result.add(vo);
        }
        return ApiResponse.success(result);
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> bind(@RequestBody Map<String, String> body,
                                                 HttpServletRequest request) {
        String exchange = body.get("exchange");
        String apiKey = body.get("api_key");
        String secretKey = body.get("secret_key");
        if (exchange == null || !SUPPORTED.contains(exchange)) {
            throw new RuntimeException("暂仅支持 binance / okx 交易所");
        }
        if (apiKey == null || apiKey.isBlank() || secretKey == null || secretKey.isBlank()) {
            throw new RuntimeException("API Key 与 Secret 不能为空");
        }
        BrokerAccount account = new BrokerAccount();
        account.setUserId(uid(request));
        account.setExchange(exchange);
        account.setApiKey(apiKey.trim());
        account.setSecretKey(aesUtil.encrypt(secretKey.trim()));
        String passphrase = body.get("passphrase");
        account.setPassphrase(passphrase == null || passphrase.isBlank()
                ? null : aesUtil.encrypt(passphrase.trim()));
        account.setPermissions("trade,read");
        brokerAccountMapper.insert(account);
        return ApiResponse.success(Map.of(
                "id", account.getId(),
                "exchange", exchange,
                "api_key_masked", AesUtil.mask(apiKey.trim())));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, String>> unbind(@PathVariable Long id,
                                                   HttpServletRequest request) {
        if (brokerAccountMapper.deleteByIdAndUser(id, uid(request)) == 0) {
            throw new RuntimeException("API Key 不存在或已删除");
        }
        return ApiResponse.success(Map.of("status", "deleted"));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
