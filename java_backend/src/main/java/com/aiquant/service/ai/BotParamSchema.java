package com.aiquant.service.ai;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 机器人策略参数模式(单一事实源)。
 *
 * <p>每个策略开放一批可手工调整的参数,统一以 config_json(扁平 JSON 对象)存储;
 * 引擎读取时缺失键回退到这里的默认值,后台保存时按这里的范围校验,前端按这里渲染表单。
 * 三处共用同一份定义,避免默认值/范围漂移。
 */
public final class BotParamSchema {

    private BotParamSchema() {}

    /**
     * 单个参数定义。
     *
     * @param key     config_json 中的键名
     * @param label   表单展示名
     * @param unit    单位/说明(可为空)
     * @param integer 是否整数参数
     * @param min     允许最小值
     * @param max     允许最大值
     * @param step    表单步进
     * @param def     默认值(引擎在缺失该键时使用)
     */
    public record ParamDef(String key, String label, String unit, boolean integer,
                           double min, double max, double step, double def) {}

    private static final Map<String, List<ParamDef>> SCHEMA = new LinkedHashMap<>();

    // 指标类机器人共用的买入资金占用比例
    private static final ParamDef BUY_RATIO =
            new ParamDef("buyRatio", "买入资金比例", "占用可用余额比例(0-1)", false, 0.05, 1, 0.05, 0.95);

    static {
        SCHEMA.put("ema_cross", List.of(
                new ParamDef("emaFast", "EMA 快线周期", "根 K 线", true, 2, 200, 1, 12),
                new ParamDef("emaSlow", "EMA 慢线周期", "根 K 线", true, 3, 300, 1, 26),
                BUY_RATIO));
        SCHEMA.put("rsi_rev", List.of(
                new ParamDef("rsiPeriod", "RSI 周期", "根 K 线", true, 2, 100, 1, 14),
                new ParamDef("rsiBuyBelow", "买入阈值", "RSI 低于该值买入", false, 1, 50, 1, 30),
                new ParamDef("rsiSellAbove", "卖出阈值", "RSI 高于该值卖出", false, 50, 99, 1, 70),
                BUY_RATIO));
        SCHEMA.put("boll_break", List.of(
                new ParamDef("bbPeriod", "布林带周期", "根 K 线", true, 2, 200, 1, 20),
                new ParamDef("bbMult", "标准差倍数", "上/下轨距离", false, 0.5, 5, 0.1, 2),
                BUY_RATIO));
        SCHEMA.put("grid", List.of(
                new ParamDef("gridStep", "网格间距", "相邻档位价格比例(0.02=2%)", false, 0.001, 0.2, 0.005, 0.02),
                new ParamDef("gridDepth", "买档数量", "向下布多少档买单", true, 1, 50, 1, 5),
                new ParamDef("gridSlice", "每档买入额", "USDT", false, 1, 1000000, 50, 500)));
    }

    /** 某策略的参数定义列表(未知策略返回空)。 */
    public static List<ParamDef> of(String strategyKey) {
        return SCHEMA.getOrDefault(strategyKey, List.of());
    }

    /** 全部策略的参数定义,供前端渲染。 */
    public static Map<String, List<ParamDef>> all() {
        return SCHEMA;
    }

    /** 取某策略某参数的默认值;未定义则返回传入的 fallback。 */
    public static double def(String strategyKey, String key, double fallback) {
        for (ParamDef p : of(strategyKey)) {
            if (p.key().equals(key)) return p.def();
        }
        return fallback;
    }

    /**
     * 校验 config_json 是否符合该策略模式:未知键拒绝、数值类型与范围校验。
     * 缺失的键允许(引擎会回退默认值)。返回错误信息;合法返回 null。
     */
    public static String validate(String strategyKey, JsonNode node) {
        List<ParamDef> defs = of(strategyKey);
        if (defs.isEmpty()) return null; // 无参数模式的策略不额外校验

        // 未知键检查
        List<String> allowed = new ArrayList<>();
        for (ParamDef p : defs) allowed.add(p.key());
        var fields = node.fieldNames();
        while (fields.hasNext()) {
            String f = fields.next();
            if (!allowed.contains(f)) return "未知参数: " + f;
        }

        for (ParamDef p : defs) {
            JsonNode v = node.get(p.key());
            if (v == null || v.isNull()) continue;
            double num;
            if (v.isNumber()) {
                num = v.doubleValue();
            } else if (v.isTextual()) {
                try {
                    num = Double.parseDouble(v.asText().trim());
                } catch (Exception e) {
                    return "参数 " + p.key() + " 必须是数字";
                }
            } else {
                return "参数 " + p.key() + " 必须是数字";
            }
            if (p.integer() && num != Math.rint(num)) {
                return "参数 " + p.label() + " 必须为整数";
            }
            if (num < p.min() || num > p.max()) {
                return "参数 " + p.label() + " 需在 " + fmt(p.min()) + " ~ " + fmt(p.max()) + " 之间";
            }
        }
        return null;
    }

    private static String fmt(double d) {
        return d == Math.rint(d) ? String.valueOf((long) d) : String.valueOf(d);
    }
}
