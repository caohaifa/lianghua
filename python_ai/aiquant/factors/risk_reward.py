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

        # 多头 RR
        long_sl = current - 2 * atr
        long_tp = current + 3 * atr
        long_risk = current - long_sl
        long_reward = long_tp - current
        long_rr = long_reward / long_risk if long_risk > 0 else 0

        # 空头 RR
        short_sl = current + 2 * atr
        short_tp = current - 3 * atr
        short_risk = short_sl - current
        short_reward = current - short_tp
        short_rr = short_reward / short_risk if short_risk > 0 else 0

        # 取更优的方向
        if long_rr >= short_rr:
            direction = SignalDirection.LONG
            rr_ratio = long_rr
            stop_loss, target = long_sl, long_tp
        else:
            direction = SignalDirection.SHORT
            rr_ratio = short_rr
            stop_loss, target = short_sl, short_tp

        if rr_ratio >= RISK_REWARD_MIN:
            status = FactorStatus.PASS
            side = "多" if direction == SignalDirection.LONG else "空"
            detail = f"RR={rr_ratio:.2f}({side}) >= {RISK_REWARD_MIN}, 止损={stop_loss:.2f}, 目标={target:.2f}"
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
