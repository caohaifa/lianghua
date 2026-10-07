"""
因子 3: 链上信号 (On-Chain Signals)
使用成交量变化作为资金流向的代理指标。
(生产环境应接入 Glassnode / 交易所链上数据 API)
"""
import numpy as np
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class OnChainFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "链上信号"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        volumes = context.volume_history
        prices = context.historical_prices

        if len(prices) < 5:
            return FactorResult(
                name=self.name,
                direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING,
                score=0.0,
                detail="数据不足",
            )

        # 无成交量时以价格变化率代替
        if len(volumes) < 5:
            prices_arr = np.array(prices)
            changes = np.diff(prices_arr[-10:]) if len(prices_arr) >= 10 else np.diff(prices_arr)
            avg_change = float(np.mean(changes)) if len(changes) > 0 else 0
            norm = abs(avg_change) / prices_arr[-1] if prices_arr[-1] > 0 else 0
            if avg_change > 0:
                direction = SignalDirection.LONG
                status = FactorStatus.PASS if norm > 0.005 else FactorStatus.WARNING
            elif avg_change < 0:
                direction = SignalDirection.SHORT
                status = FactorStatus.PASS if norm > 0.005 else FactorStatus.WARNING
            else:
                direction = SignalDirection.NEUTRAL
                status = FactorStatus.WARNING
            return FactorResult(
                name=self.name, direction=direction, status=status,
                score=min(norm * 100, 1.0),
                detail=f"价格代理: 平均变化={avg_change:+.4f}",
                metadata={"avg_change": avg_change},
            )

        vol_arr = np.array(volumes)
        recent_vol = np.mean(vol_arr[-5:])
        avg_vol = np.mean(vol_arr)

        if avg_vol == 0:
            return FactorResult(
                name=self.name, direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING, score=0.0, detail="无成交量数据",
            )

        # 量比: >1 放量(资金流入交易所→看跌), <1 缩量(资金流出交易所→看涨)
        vol_ratio = float(recent_vol / avg_vol)
        # 结合价格方向确认: 放量+跌=资金流出交易所(看涨); 放量+涨=资金流入交易所(看跌)
        price_change = (prices[-1] - prices[-5]) / prices[-5] if len(prices) >= 5 else 0

        if vol_ratio > 1.3:
            # 放量: 结合价格方向判断
            if price_change < -0.01:
                direction = SignalDirection.LONG  # 放量下跌=资金流出交易所=看涨
                status = FactorStatus.PASS
                score = min((vol_ratio - 1) * 0.5, 1.0)
            elif price_change > 0.01:
                direction = SignalDirection.SHORT  # 放量上涨=资金流入交易所=看跌
                status = FactorStatus.PASS
                score = min((vol_ratio - 1) * 0.5, 1.0)
            else:
                direction = SignalDirection.NEUTRAL
                status = FactorStatus.WARNING
                score = 0.2
        elif vol_ratio < 0.7:
            # 缩量: 市场平静
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING
            score = 0.2
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING
            score = 0.3

        return FactorResult(
            name=self.name, direction=direction, status=status,
            score=score,
            detail=f"量比={vol_ratio:.2f}, 价格变化={price_change:+.2%}",
            metadata={"vol_ratio": vol_ratio, "price_change": price_change},
        )
