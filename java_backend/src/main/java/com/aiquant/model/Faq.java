package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class Faq {
    private Long id;
    private String category;   // account / trading / futures / ai / copy / other
    private String question;
    private String answer;
    private Integer sortOrder;
    private Integer status;    // 0=隐藏 1=显示
    private String creator;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
