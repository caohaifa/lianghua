package com.aiquant.controller;

import com.aiquant.mapper.AdminQueryMapper;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 后台-监控总览:全用户监控列表(运行状态/信号数/跟单数)、策略分布。
 */
@RestController
@RequestMapping("/admin/monitors")
public class AdminMonitorController {

    @Autowired
    private AdminQueryMapper adminQueryMapper;

    /** 监控分页(带信号/跟单聚合) */
    @GetMapping
    public ApiResponse<Map<String, Object>> list(@RequestParam(defaultValue = "1") int page,
                                                 @RequestParam(defaultValue = "10") int size,
                                                 @RequestParam(required = false) String strategy,
                                                 @RequestParam(required = false) String status,
                                                 @RequestParam(required = false) String source) {
        int offset = (page - 1) * size;
        long total = adminQueryMapper.countAdminMonitors(strategy, status, source);
        List<Map<String, Object>> list = adminQueryMapper.selectAdminMonitors(strategy, status, source, size, offset);
        return ApiResponse.success(Map.of("list", list, "total", total));
    }

    /** 策略分布(下拉筛选) */
    @GetMapping("/strategies")
    public ApiResponse<List<String>> strategies() {
        return ApiResponse.success(adminQueryMapper.selectMonitorStrategies());
    }
}
