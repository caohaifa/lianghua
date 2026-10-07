package com.aiquant.controller;

import com.aiquant.mapper.AdminQueryMapper;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 后台-返佣/团队管理:返佣流水分页查询、推荐人团队聚合(只读)。
 */
@RestController
@RequestMapping("/admin/referral")
public class AdminReferralController {

    @Autowired
    private AdminQueryMapper adminQueryMapper;

    /** 返佣流水分页 */
    @GetMapping("/rewards")
    public ApiResponse<Map<String, Object>> rewards(@RequestParam(defaultValue = "1") int page,
                                                    @RequestParam(defaultValue = "10") int size,
                                                    @RequestParam(required = false) String referrer,
                                                    @RequestParam(required = false) String currency) {
        int offset = (page - 1) * size;
        long total = adminQueryMapper.countAdminRewards(referrer, currency);
        List<Map<String, Object>> list = adminQueryMapper.selectAdminRewards(referrer, currency, size, offset);
        return ApiResponse.success(Map.of("list", list, "total", total));
    }

    /** 推荐人团队聚合(团队人数/活跃/流水/返佣,按返佣降序) */
    @GetMapping("/teams")
    public ApiResponse<Map<String, Object>> teams() {
        List<Map<String, Object>> list = adminQueryMapper.selectAdminTeams();
        return ApiResponse.success(Map.of("list", list, "total", list.size()));
    }
}
