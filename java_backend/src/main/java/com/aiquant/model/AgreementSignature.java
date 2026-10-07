package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 协议签署存证记录(t_agreement_signature)
 */
@Data
public class AgreementSignature {
    private Long id;
    private String userId;
    private String agreements;   // 已签协议ID列表,逗号分隔
    private String signatureImg; // 手写签名 PNG Base64
    private String sealTime;     // 存证时间戳(ISO)
    private String ip;           // 签署时 IP
    private String userAgent;    // 签署时 User-Agent
    private String contentHash;  // SHA-256(userId|agreements|signature|sealTime|ip) 完整性校验
    private LocalDateTime signedAt;
}
