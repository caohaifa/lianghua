package com.aiquant.controller;

import com.aiquant.mapper.AnnouncementMapper;
import com.aiquant.model.Announcement;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 用户端公告:只读已发布(status=1)公告,运营后台发布即全网用户可见。
 */
@RestController
@RequestMapping("/announcements")
public class AnnouncementController {

    @Autowired
    private AnnouncementMapper announcementMapper;

    @GetMapping
    public ApiResponse<List<Announcement>> list() {
        return ApiResponse.success(announcementMapper.list(null, 1, 0, 50));
    }
}
