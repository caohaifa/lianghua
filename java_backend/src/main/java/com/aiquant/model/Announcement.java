package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 系统公告(运营后台全量广播)
 */
@Data
public class Announcement {
    private Long id;
    private String title;
    private String content;
    private Integer status;  // 0=草稿 1=已发布 2=已下线
    private String publisherId;
    private LocalDateTime publishedAt;
    private String category; // general / trading / futures / ai / activity
    private Integer pinned;  // 0=普通 1=置顶
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
