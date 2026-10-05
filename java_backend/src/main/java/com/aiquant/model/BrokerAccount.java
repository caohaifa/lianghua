package com.aiquant.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 券商/交易所 API Key(t_broker_account)
 * secret_key 落库前 AES 加密,任何接口不返回明文。
 */
@Data
public class BrokerAccount {
    private Long id;
    private String userId;
    private String exchange;      // binance/okx
    private String apiKey;
    @JsonIgnore  // 密文永不返回给客户端
    private String secretKey;
    @JsonIgnore
    private String passphrase;
    private String permissions;
    private Integer status;       // 0=启用 1=停用
    private LocalDateTime createdAt;
}
