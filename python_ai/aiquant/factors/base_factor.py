"""
因子基类
"""
from abc import ABC, abstractmethod
from ..models.factors import FactorResult, DecisionContext


class BaseFactor(ABC):
    """决策因子基类"""

    @property
    @abstractmethod
    def name(self) -> str:
        """因子名称"""
        ...

    @abstractmethod
    async def evaluate(self, context: DecisionContext) -> FactorResult:
        """评估因子,返回结果"""
        ...
