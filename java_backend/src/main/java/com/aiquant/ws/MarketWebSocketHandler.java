package com.aiquant.ws;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

/**
 * 行情 WebSocket 推送 Handler
 * 客户端连接 /ws/market 后,服务端定时推送行情快照
 */
public class MarketWebSocketHandler extends TextWebSocketHandler {

    private final Set<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.add(session);
        System.out.println("[WS] 客户端连接: " + session.getId() + ", 当前在线: " + sessions.size());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
        System.out.println("[WS] 客户端断开: " + session.getId() + ", 剩余在线: " + sessions.size());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        // 客户端可发送订阅指令: {"action":"subscribe","symbols":["BTC/USDT"]}
        System.out.println("[WS] 收到消息: " + message.getPayload());
    }

    /**
     * 向所有连接推送行情快照
     */
    public void broadcast(Map<String, Object> data) {
        if (sessions.isEmpty()) return;
        try {
            String json = objectMapper.writeValueAsString(data);
            TextMessage message = new TextMessage(json);
            for (WebSocketSession session : sessions) {
                if (session.isOpen()) {
                    try {
                        session.sendMessage(message);
                    } catch (IOException e) {
                        System.err.println("[WS] 推送失败: " + e.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("[WS] 序列化失败: " + e.getMessage());
        }
    }
}
