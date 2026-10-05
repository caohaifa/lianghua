"""
五维决策因子模型
对应设计文档: 新闻情绪 / 量化指标 / 链上信号 / 技术形态 / 风险收益比
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class SignalDirection(Enum):
    """信号方向"""
    LONG = "long"       # 做多
    SHORT = "short"     # 做空
    NEUTRAL = "neutral" # 中性/无信号

    @property
    def icon(self) -> str:
        return {SignalDirection.LONG: "🟢", SignalDirection.SHORT: "🔴", SignalDirection.NEUTRAL: "🟡"}[self]


class FactorStatus(Enum):
    """因子门控状态"""
    PASS = "pass"       # 🟢 通过(确认方向)
    WARNING = "warning" # 🟡 警告(待确认)
    FAIL = "fail"        # 🔴 不通过/反向

    @property
    def icon(self) -> str:
        return {FactorStatus.PASS: "🟢", FactorStatus.WARNING: "🟡", FactorStatus.FAIL: "🔴"}[self]


@dataclass
class FactorResult:
    """单因子计算结果"""
    name: str                       # 因子名称
    direction: SignalDirection      # 信号方向
    status: FactorStatus            # 门控状态
    score: float                    # 置信度 0~1
    detail: str = ""                # 详细说明
    metadata: dict = field(default_factory=dict)  # 附加数据

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "direction": self.direction.value,
            "status": self.status.value,
            "icon": self.status.icon,
            "score": self.score,
            "detail": self.detail,
            "metadata": self.metadata,
        }


@dataclass
class DecisionContext:
    """决策上下文 - 传递给每个因子的输入"""
    symbol: str                     # 交易对,如 BTC/USDT
    current_price: float           # 当前价格
    historical_prices: list[float] # 历史价格序列
    volume_history: list[float]    # 成交量序列
    position_side: Optional[str] = None  # 当前持仓方向 long/short/None
    account_balance: float = 0.0   # 账户余额
    risk_level: str = "R3"         # 用户风险等级
