"""
因子 5: 风险收益比 (Risk-Reward Ratio)
计算当前开仓的预期收益与最大亏损的比值
"""
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext
from ..config import RISK_REWARD_MIN


class RiskRewardFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "风险收益比"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        prices = context.historical_prices
        if len(prices) < 10:
            return FactorResult(
                name=self.name,
                direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING,
                score=0.0,
                detail="数据不足",
            )

        current = context.current_price
        # 计算 ATR 作为止损参考
        recent_prices = prices[-14:] if len(prices) >= 14 else prices
        price_changes = [abs(recent_prices[i] - recent_prices[i - 1]) for i in range(1, len(recent_prices))]
        atr = sum(price_changes) / len(price_changes) if price_changes else current * 0.02

        stop_loss = current - 2 * atr  # 止损
        target = current + 3 * atr     # 目标

        risk = current - stop_loss
        reward = target - current
        rr_ratio = reward / risk if risk > 0 else 0

        if rr_ratio >= RISK_REWARD_MIN:
            direction = SignalDirection.LONG  # 风险收益比好,偏向做多
            status = FactorStatus.PASS
            detail = f"RR={rr_ratio:.2f} >= {RISK_REWARD_MIN}, 止损={stop_loss:.2f}, 目标={target:.2f}"
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.FAIL
            detail = f"RR={rr_ratio:.2f} < {RISK_REWARD_MIN}, 风险收益比不足"

        return FactorResult(
            name=self.name,
            direction=direction,
            status=status,
            score=rr_ratio,
            detail=detail,
            metadata={"rr_ratio": rr_ratio, "stop_loss": stop_loss, "target": target, "atr": atr},
        )
