package com.aiquant.controller;

import com.aiquant.mapper.ReferralRewardMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.ReferralReward;
import com.aiquant.service.ReferralService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 邀请奖励与团队管理。
 * 规则:被推荐人每笔现货成交,推荐人获交易流水 1% 返佣(USDT/CNY 随交易币种)。
 */
@RestController
@RequestMapping("/referral")
public class ReferralController {

    @Autowired private ReferralRewardMapper rewardMapper;

    /** 邀请奖励汇总 + 明细(最新 50 条) */
    @GetMapping("/summary")
    public ApiResponse<Map<String, Object>> summary(HttpServletRequest request) {
        String uid = (String) request.getAttribute("userId");
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("invite_code", uid); // 专属邀请码 = userId(与 /auth/invite-code 一致)
        vo.put("invited_count", rewardMapper.countInvited(uid));
        vo.put("reward_rate", ReferralService.RATE);
        vo.put("total_reward_usdt", round8(rewardMapper.sumReward(uid, "USDT")));
        vo.put("total_reward_cny", round8(rewardMapper.sumReward(uid, "CNY")));
        vo.put("rewards", flowRows(uid, 50));
        return ApiResponse.success(vo);
    }

    /**
     * 团队管理:团队人数 / 交易总金额 / 成员明细 / 交易流水(详细资金管理)。
     * 团队 = 通过本人邀请码注册的用户(invited_by 关系)。
     */
    @GetMapping("/team")
    public ApiResponse<Map<String, Object>> team(HttpServletRequest request) {
        String uid = (String) request.getAttribute("userId");
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("team_count", rewardMapper.countInvited(uid));
        vo.put("active_count", rewardMapper.countActiveTraders(uid));
        vo.put("total_volume_usdt", round8(rewardMapper.sumVolume(uid, "USDT")));
        vo.put("total_volume_cny", round8(rewardMapper.sumVolume(uid, "CNY")));
        vo.put("total_reward_usdt", round8(rewardMapper.sumReward(uid, "USDT")));
        vo.put("total_reward_cny", round8(rewardMapper.sumReward(uid, "CNY")));

        // 成员流水/返佣聚合(traderid → 统计行)
        Map<String, Map<String, Object>> statMap = new HashMap<>();
        for (Map<String, Object> s : rewardMapper.selectMemberStats(uid)) {
            Map<String, Object> low = lower(s);
            statMap.put(String.valueOf(low.get("traderid")), low);
        }

        // 成员明细:基础信息 + 个人聚合
        List<Map<String, Object>> members = new ArrayList<>();
        for (Map<String, Object> u0 : rewardMapper.selectInvitedUsers(uid, 100)) {
            Map<String, Object> u = lower(u0);
            String memberId = String.valueOf(u.get("userid"));
            Map<String, Object> st = statMap.get(memberId);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("trader", mask(memberId));
            Object nickname = u.get("nickname");
            m.put("nickname", nickname == null || nickname.toString().isBlank()
                    ? null : nickname.toString());
            m.put("phone", maskPhone(String.valueOf(u.get("phone"))));
            m.put("joined_at", u.get("createdat") == null ? null : u.get("createdat").toString());
            m.put("trade_count", st == null ? 0 : (long) num(st, "tradecount"));
            m.put("volume_usdt", round8(st == null ? 0 : num(st, "volusdt")));
            m.put("volume_cny", round8(st == null ? 0 : num(st, "volcny")));
            m.put("reward_usdt", round8(st == null ? 0 : num(st, "rewardusdt")));
            m.put("reward_cny", round8(st == null ? 0 : num(st, "rewardcny")));
            members.add(m);
        }
        vo.put("members", members);
        vo.put("flows", flowRows(uid, 50));
        return ApiResponse.success(vo);
    }

    /** 奖励/交易流水明细行(最新 limit 条) */
    private List<Map<String, Object>> flowRows(String uid, int limit) {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (ReferralReward r : rewardMapper.selectByReferrer(uid, limit)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("trader", mask(r.getTraderId()));
            m.put("symbol", r.getSymbol());
            m.put("currency", r.getCurrency());
            m.put("volume", r.getVolume());
            m.put("reward", r.getReward());
            m.put("created_at", r.getCreatedAt() == null ? null : r.getCreatedAt().toString());
            rows.add(m);
        }
        return rows;
    }

    /** 列标签统一小写,规避 H2(大写)/MySQL 差异 */
    private Map<String, Object> lower(Map<String, Object> m) {
        Map<String, Object> r = new HashMap<>();
        for (Map.Entry<String, Object> e : m.entrySet()) {
            r.put(e.getKey().toLowerCase(), e.getValue());
        }
        return r;
    }

    private double num(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v instanceof Number n ? n.doubleValue() : 0;
    }

    /** 被推荐人脱敏:U1***234 */
    private String mask(String id) {
        if (id == null || id.length() <= 4) return id;
        return id.charAt(0) + "***" + id.substring(id.length() - 3);
    }

    /** 手机号脱敏:138****1234 */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    private double round8(double v) {
        return Math.round(v * 1e8) / 1e8;
    }
}
