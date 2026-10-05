package com.aiquant.service;

import com.aiquant.mapper.AuditLogMapper;
import com.aiquant.model.AuditLog;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * 审计日志:所有后台敏感操作统一落库留痕(合规要求保留 ≥ 5 年)。
 * detail 用 Jackson 序列化为 JSON,避免手动拼字符串导致非法 JSON。
 */
@Service
public class AuditLogService {

    @Autowired
    private AuditLogMapper auditLogMapper;
    @Autowired
    private ObjectMapper objectMapper;

    public void record(String actorId, String action, String resource,
                       Map<String, Object> detail, String ip) {
        AuditLog log = new AuditLog();
        log.setActorId(actorId);
        log.setActorType(1); // 1=运营
        log.setAction(action);
        log.setResource(resource);
        log.setDetailJson(toJson(detail));
        log.setIp(ip);
        auditLogMapper.insert(log);
    }

    private String toJson(Map<String, Object> detail) {
        if (detail == null || detail.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(detail);
        } catch (JsonProcessingException e) {
            return "{\"error\":\"序列化失败\"}";
        }
    }
}
