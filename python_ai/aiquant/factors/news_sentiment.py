"""
因子 1: 新闻情绪 (News Sentiment)
使用价格动量 + 成交量变化作为市场情绪的代理指标。
(生产环境应接入 FinBERT / LLM / 新闻 API)
"""
import numpy as np
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class NewsSentimentFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "新闻情绪"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        prices = context.historical_prices
        volumes = context.volume_history

        if len(prices) < 10:
            return FactorResult(
                name=self.name,
                direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING,
                score=0.0,
                detail="数据不足(需≥10根)",
            )

        prices_arr = np.array(prices)

        # 1) 价格动量: 短期(5根) vs 中期(20根)收益率
        short_ret = (prices_arr[-1] - prices_arr[-5]) / prices_arr[-5] if len(prices_arr) >= 5 else 0
        medium_ret = (prices_arr[-1] - prices_arr[-20]) / prices_arr[-20] if len(prices_arr) >= 20 else short_ret
        momentum = 0.6 * short_ret + 0.4 * medium_ret

        # 2) 成交量趋势(如有): 近期放量=情绪增强, 缩量=情绪减弱
        vol_weight = 1.0
        if len(volumes) >= 10:
            vol_arr = np.array(volumes)
            recent_vol = np.mean(vol_arr[-5:])
            avg_vol = np.mean(vol_arr)
            vol_weight = min(recent_vol / avg_vol, 2.0) if avg_vol > 0 else 1.0

        # 综合情绪得分(归一化到 -1 ~ +1)
        score = float(np.clip(momentum * 20 * vol_weight, -1.0, 1.0))

        if score > 0.2:
            direction = SignalDirection.LONG
            status = FactorStatus.PASS
        elif score < -0.2:
            direction = SignalDirection.SHORT
            status = FactorStatus.PASS
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING

        return FactorResult(
            name=self.name,
            direction=direction,
            status=status,
            score=abs(score),
            detail=f"动量={momentum:+.4f}, 量比={vol_weight:.2f}, 综合={score:+.2f}",
            metadata={"momentum": momentum, "vol_weight": vol_weight, "sentiment_score": score},
        )
