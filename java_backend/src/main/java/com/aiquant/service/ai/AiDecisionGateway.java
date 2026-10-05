package com.aiquant.service.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

/**
 * Python AI 服务网关:调用 /decision 五因子决策。
 * AI 离线/超时/坏响应 → 返回 null(调用方跳过本轮,不影响交易主流程)。
 * 注意:Python 返回为裸 JSON 字典,无 ApiResponse 包装。
 */
@Component
public class AiDecisionGateway {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    @Value("${ai.service-url:http://localhost:8000}")
    private String serviceUrl;

    /**
     * 请求五因子决策。
     *
     * @param payload 字段与 Python DecisionRequest 一致:
     *                symbol/current_price/historical_prices/volume_history/position_side/account_balance/risk_level
     * @return {action,direction,confidence,reason};失败 null
     */
    public Map<String, Object> decide(Map<String, Object> payload) {
        try {
            String body = objectMapper.writeValueAsString(payload);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(serviceUrl + "/decision"))
                    .timeout(Duration.ofSeconds(5))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpResponse<String> resp = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200) return null;
            @SuppressWarnings("unchecked")
            Map<String, Object> result = objectMapper.readValue(resp.body(), Map.class);
            return result.containsKey("action") ? result : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 代理 Python GET /agents/status。
     *
     * @return {agents:[{name,status,tasks_done,tasks_pending}]};失败返回空 agents
     */
    public Map<String, Object> agentsStatus() {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(serviceUrl + "/agents/status"))
                    .timeout(Duration.ofSeconds(5))
                    .GET()
                    .build();
            HttpResponse<String> resp = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200) return Map.of("agents", java.util.List.of());
            @SuppressWarnings("unchecked")
            Map<String, Object> result = objectMapper.readValue(resp.body(), Map.class);
            result.putIfAbsent("agents", java.util.List.of());
            return result;
        } catch (Exception e) {
            return Map.of("agents", java.util.List.of());
        }
    }
}
