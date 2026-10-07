"""
因子 4: 技术形态 (Technical Patterns)
基于趋势分析 + 波动率收缩/扩张 + 价格结构识别形态
"""
import numpy as np
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class TechnicalPatternFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "技术形态"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        prices = context.historical_prices

        if len(prices) < 20:
            return FactorResult(
                name=self.name,
                direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING,
                score=0.0,
                detail=f"数据不足(需≥20根,当前{len(prices)}根)",
            )

        prices_arr = np.array(prices)

        # 1) 趋势方向: 线性回归斜率
        n = min(len(prices_arr), 50)
        recent = prices_arr[-n:]
        x = np.arange(n)
        slope = float(np.polyfit(x, recent, 1)[0])
        norm_slope = slope / prices_arr[-1] if prices_arr[-1] > 0 else 0

        # 2) 波动率: 近期 vs 历史
        changes = np.abs(np.diff(recent))
        recent_vol = float(np.mean(changes[-10:])) if len(changes) >= 10 else float(np.mean(changes))
        hist_vol = float(np.mean(changes))
        vol_contraction = recent_vol / hist_vol if hist_vol > 0 else 1.0

        # 3) 价格结构: 寻找摆动高低点
        chunk = len(recent) // 3
        if chunk < 2:
            chunk = 2
        seg1 = recent[:chunk]
        seg2 = recent[chunk:2*chunk]
        seg3 = recent[2*chunk:]

        highs = [float(np.max(s)) for s in [seg1, seg2, seg3]]
        lows = [float(np.min(s)) for s in [seg1, seg2, seg3]]

        # 4) 形态分类
        pattern = "震荡"
        confidence = 0.3

        if norm_slope > 0.001:
            if highs[0] <= highs[1] <= highs[2] and lows[0] <= lows[1] <= lows[2]:
                pattern = "上升趋势"
                confidence = min(0.5 + abs(norm_slope) * 50, 0.9)
            elif vol_contraction < 0.7:
                pattern = "三角形突破"
                confidence = min(0.5 + (1 - vol_contraction) * 0.5, 0.85)
            elif highs[2] > highs[0] and lows[2] > lows[0]:
                pattern = "上升趋势"
                confidence = min(0.4 + abs(norm_slope) * 30, 0.8)
        elif norm_slope < -0.001:
            if highs[0] >= highs[1] >= highs[2] and lows[0] >= lows[1] >= lows[2]:
                pattern = "下降趋势"
                confidence = min(0.5 + abs(norm_slope) * 50, 0.9)
            elif abs(lows[0] - lows[2]) / lows[0] < 0.02 and highs[1] > lows[0] * 1.02:
                # 双底:两个低点接近(差距<2%),中间高点明显高于低点
                pattern = "双底"
                confidence = 0.65
            elif highs[2] < highs[0] and highs[2] < highs[1] and lows[2] < lows[0]:
                pattern = "头肩顶"
                confidence = 0.65
            else:
                pattern = "下降趋势"
                confidence = min(0.4 + abs(norm_slope) * 30, 0.8)
        else:
            if vol_contraction < 0.6:
                pattern = "三角形整理"
                confidence = 0.5
            else:
                pattern = "震荡"
                confidence = 0.3

        # 方向判定
        if pattern in ("上升趋势", "三角形突破", "双底"):
            direction = SignalDirection.LONG
            status = FactorStatus.PASS if confidence > 0.5 else FactorStatus.WARNING
        elif pattern in ("下降趋势", "头肩顶"):
            direction = SignalDirection.SHORT
            status = FactorStatus.PASS if confidence > 0.5 else FactorStatus.WARNING
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING

        return FactorResult(
            name=self.name,
            direction=direction,
            status=status,
            score=confidence,
            detail=f"形态={pattern}, 斜率={norm_slope:+.4f}, 波动比={vol_contraction:.2f}",
            metadata={
                "pattern": pattern,
                "confidence": confidence,
                "norm_slope": norm_slope,
                "vol_contraction": vol_contraction,
            },
        )
