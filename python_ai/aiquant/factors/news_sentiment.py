"""
因子 1: 新闻情绪 (News Sentiment)
使用 FinBERT / LLM 对新闻和社交媒体进行情绪极性打分
"""
import random
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class NewsSentimentFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "新闻情绪"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        # TODO: 实际实现
        # 1. 爬取 RSS / 社媒 / 公告
        # 2. 使用 FinBERT 或 LLM 进行情绪极性打分 (-1 ~ +1)
        # 3. 聚合为方向 + 置信度

        score = random.uniform(-0.8, 0.8)
        if score > 0.3:
            direction = SignalDirection.LONG
            status = FactorStatus.PASS
        elif score < -0.3:
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
            detail=f"情绪得分 {score:.2f}, 来源 RSS+社媒",
            metadata={"sentiment_score": score},
        )
