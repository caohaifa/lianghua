package com.aiquant.service.ai;

import java.util.List;

/**
 * 技术指标计算(复刻 freqlight/freqtrade 常用内置指标):EMA / RSI(Wilder)/ 布林带。
 * 输入为 K 线收盘价序列(时间正序),纯函数无外部依赖。
 */
public final class IndicatorCalc {

    private IndicatorCalc() {}

    /** EMA 序列(与输入等长):首 period 根以 SMA 递推,之后标准 EMA。 */
    public static double[] ema(List<Double> closes, int period) {
        int n = closes.size();
        double[] out = new double[n];
        if (n == 0) return out;
        double sum = 0;
        for (int i = 0; i < n; i++) {
            sum += closes.get(i);
            if (i < period - 1) {
                out[i] = sum / (i + 1);
            } else {
                if (i == period - 1) {
                    out[i] = sum / period;
                } else {
                    double k = 2.0 / (period + 1);
                    out[i] = closes.get(i) * k + out[i - 1] * (1 - k);
                }
            }
        }
        return out;
    }

    /** RSI(Wilder 平滑,周期 14);前 period 根返回 50(中性)。 */
    public static double[] rsi(List<Double> closes, int period) {
        int n = closes.size();
        double[] out = new double[n];
        if (n == 0) return out;
        double avgGain = 0, avgLoss = 0;
        for (int i = 0; i < n; i++) {
            if (i == 0) {
                out[i] = 50;
                continue;
            }
            double diff = closes.get(i) - closes.get(i - 1);
            double gain = Math.max(diff, 0);
            double loss = Math.max(-diff, 0);
            if (i <= period) {
                avgGain += gain;
                avgLoss += loss;
                if (i == period) {
                    avgGain /= period;
                    avgLoss /= period;
                    out[i] = rsiFrom(avgGain, avgLoss);
                } else {
                    out[i] = 50;
                }
            } else {
                avgGain = (avgGain * (period - 1) + gain) / period;
                avgLoss = (avgLoss * (period - 1) + loss) / period;
                out[i] = rsiFrom(avgGain, avgLoss);
            }
        }
        return out;
    }

    private static double rsiFrom(double avgGain, double avgLoss) {
        if (avgLoss == 0) return 100;
        double rs = avgGain / avgLoss;
        return 100 - 100 / (1 + rs);
    }

    /** 最后一根的布林带 [mid, upper, lower](SMA ± mult×总体标准差)。 */
    public static double[] bollinger(List<Double> closes, int period, double mult) {
        int n = closes.size();
        if (n < period) {
            double mean = closes.isEmpty() ? 0 : closes.stream().mapToDouble(Double::doubleValue).average().orElse(0);
            return new double[]{mean, mean, mean};
        }
        double sum = 0;
        for (int i = n - period; i < n; i++) sum += closes.get(i);
        double mid = sum / period;
        double var = 0;
        for (int i = n - period; i < n; i++) {
            double d = closes.get(i) - mid;
            var += d * d;
        }
        double sd = Math.sqrt(var / period);
        return new double[]{mid, mid + mult * sd, mid - mult * sd};
    }
}
