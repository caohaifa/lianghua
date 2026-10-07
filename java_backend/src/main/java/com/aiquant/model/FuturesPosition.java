package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 合约持仓(t_futures_position):单向持仓,多/空二选一。
 */
@Data
public class FuturesPosition {
    private Long id;
    private String userId;
    private String symbol;
    private String direction;   // long=多 / short=空
    private Double amount;
    private Double entryPrice;
    private Integer leverage;
    private Double margin;      // 占用保证金
    private Integer status;     // 0持仓中 1已平仓
    private LocalDateTime openedAt;
    private LocalDateTime closedAt;
}
