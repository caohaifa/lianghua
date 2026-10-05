package com.aiquant.controller;

import com.aiquant.model.AdminUser;
import com.aiquant.model.ApiResponse;
import com.aiquant.service.AdminAuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 运营后台认证
 */
@RestController
@RequestMapping("/admin")
public class AdminAuthController {

    @Autowired
    private AdminAuthService adminAuthService;

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody Map<String, String> body) {
        AdminAuthService.LoginResult result = adminAuthService.login(body.get("username"), body.get("password"));
        AdminUser admin = result.admin();
        Map<String, Object> data = new HashMap<>();
        data.put("token", result.token());
        Map<String, Object> user = new HashMap<>();
        user.put("id", admin.getId());
        user.put("username", admin.getUsername());
        user.put("realName", admin.getRealName());
        user.put("role", admin.getRole());
        data.put("user", user);
        return ApiResponse.success(data);
    }
}
