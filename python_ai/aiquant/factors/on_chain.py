"""
因子 3: 链上信号 (On-Chain Signals)
分析大资金流向、交易所净流入流出
"""
import random
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class OnChainFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "链上信号"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        # TODO: 实际实现
        # 1. 调用 Glassnode API 获取链上数据
        # 2. 计算交易所净流入/流出
        # 3. 分析大资金地址动向

        net_flow = random.uniform(-500, 500)  # 模拟净流入(BTC)
        if net_flow < -100:  # 流出交易所(看涨)
            direction = SignalDirection.LONG
            status = FactorStatus.PASS
            score = min(abs(net_flow) / 500, 1.0)
        elif net_flow > 100:  # 流入交易所(看跌)
            direction = SignalDirection.SHORT
            status = FactorStatus.PASS
            score = min(net_flow / 500, 1.0)
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING
            score = 0.2

        return FactorResult(
            name=self.name,
            direction=direction,
            status=status,
            score=score,
            detail=f"交易所净流入 {net_flow:+.0f} BTC",
            metadata={"net_flow": net_flow},
        )
