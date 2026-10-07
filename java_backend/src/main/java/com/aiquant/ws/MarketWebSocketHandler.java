package com.aiquant.ws;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

/**
 * 行情 WebSocket 推送 Handler
 * 客户端连接 /ws/market 后可发送订阅指令:
 *   {"action":"subscribe","symbols":["BTC/USDT","ETH/USDT"]}
 *   {"action":"unsubscribe","symbols":["BTC/USDT"]}
 *   {"action":"subscribe_all"}  ← 订阅全部(默认行为)
 * 未发送订阅指令的客户端默认接收全部标的推送(向后兼容)。
 */
public class MarketWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(MarketWebSocketHandler.class);

    private final Set<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
    /** 每个 session 订阅的 symbol 集合;空集合 = 订阅全部(默认) */
    private final Map<String, Set<String>> subscriptions = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public MarketWebSocketHandler(MeterRegistry meterRegistry) {
        // WS 在线连接数指标(aiquant_ws_online),供 Prometheus 抓取
        Gauge.builder("aiquant_ws_online", sessions, s -> s.size())
                .description("WebSocket 在线连接数").register(meterRegistry);
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.add(session);
        log.info("[WS] 客户端连接: {}, 当前在线: {}", session.getId(), sessions.size());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
        subscriptions.remove(session.getId());
        log.info("[WS] 客户端断开: {}, 剩余在线: {}", session.getId(), sessions.size());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        try {
            JsonNode root = objectMapper.readTree(message.getPayload());
            String action = root.path("action").asText("");
            String sid = session.getId();
            switch (action) {
                case "subscribe" -> {
                    Set<String> subs = subscriptions.computeIfAbsent(sid, k -> ConcurrentHashMap.newKeySet());
                    JsonNode arr = root.path("symbols");
                    if (arr.isArray()) {
                        for (JsonNode s : arr) subs.add(s.asText());
                    }
                    log.debug("[WS] {} subscribe: {}", sid, subs);
                }
                case "unsubscribe" -> {
                    Set<String> subs = subscriptions.get(sid);
                    if (subs != null) {
                        JsonNode arr = root.path("symbols");
                        if (arr.isArray()) {
                            for (JsonNode s : arr) subs.remove(s.asText());
                        }
                    }
                }
                case "subscribe_all" -> subscriptions.remove(sid);
                default -> log.debug("[WS] 未知指令: {}", message.getPayload());
            }
        } catch (Exception e) {
            log.warn("[WS] 解析订阅消息失败: {}", e.getMessage());
        }
    }

    /**
     * 向所有连接推送行情快照(按订阅过滤)
     */
    public void broadcast(Map<String, Object> data) {
        if (sessions.isEmpty()) return;
        @SuppressWarnings("unchecked")
        Map<String, Object> fullData = (Map<String, Object>) data.get("data");

        for (WebSocketSession session : sessions) {
            if (!session.isOpen()) continue;
            try {
                Set<String> subs = subscriptions.get(session.getId());
                Map<String, Object> filtered;
                if (subs == null || subs.isEmpty()) {
                    // 未订阅 / 订阅全部 → 发送完整数据
                    filtered = fullData;
                } else {
                    filtered = new LinkedHashMap<>();
                    for (String sym : subs) {
                        Object tick = fullData.get(sym);
                        if (tick != null) filtered.put(sym, tick);
                    }
                    if (filtered.isEmpty()) continue; // 该客户端无关注标的的新数据
                }
                Map<String, Object> payload = new HashMap<>();
                payload.put("type", "tick");
                payload.put("data", filtered);
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(payload)));
            } catch (IOException e) {
                log.warn("[WS] 推送失败: {}", e.getMessage());
            }
        }
    }
}
