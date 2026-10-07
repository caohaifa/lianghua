"""
决策 Agent
五因子门控: 至少 3/5 因子同方向确认,且风险收益比必须通过
"""
import asyncio
import logging
from .base_agent import BaseAgent, AgentStatus, AgentTask
from ..models.factors import (
    DecisionContext, FactorResult, SignalDirection, FactorStatus
)
from ..factors.news_sentiment import NewsSentimentFactor
from ..factors.quant_indicator import QuantIndicatorFactor
from ..factors.on_chain import OnChainFactor
from ..factors.technical_pattern import TechnicalPatternFactor
from ..factors.risk_reward import RiskRewardFactor
from ..config import FACTOR_THRESHOLD

logger = logging.getLogger(__name__)


class DecisionAgent(BaseAgent):
    def __init__(self):
        super().__init__("决策 Agent")
        self.factors = [
            NewsSentimentFactor(),
            QuantIndicatorFactor(),
            OnChainFactor(),
            TechnicalPatternFactor(),
            RiskRewardFactor(),
        ]

    async def run(self):
        """主循环: 事件驱动消费 asyncio.Queue(无任务时挂起,不占 CPU,零空等延迟)"""
        self.status = AgentStatus.ONLINE
        logger.info(f"[{self.name}] 启动, 五因子门控阈值={FACTOR_THRESHOLD}/5")
        while True:
            task = await self.tasks_queue.get()
            try:
                await self._process_task(task)
            except Exception as e:
                logger.error(f"[{self.name}] 主循环异常: {e}")
            finally:
                self.tasks_queue.task_done()

    async def _process_task(self, task: AgentTask):
        """处理决策任务"""
        try:
            context = DecisionContext(**task.payload)
            result = await self.make_decision(context)
            logger.info(f"[{self.name}] 决策完成: {result['action']} ({result['reason']})")
            self.tasks_done += 1
        except Exception as e:
            logger.error(f"[{self.name}] 任务处理失败: {e}")

    async def make_decision(self, context: DecisionContext) -> dict:
        """
        五因子门控决策
        返回: {action, direction, confidence, reason, factors}
        """
        # 并行计算五因子(注:当前五因子均为纯 CPU、无 await,不构成真并发)
        results: list[FactorResult] = await asyncio.gather(
            *[f.evaluate(context) for f in self.factors]
        )

        # 统计各方向确认数
        long_count = sum(1 for r in results if r.direction == SignalDirection.LONG and r.status == FactorStatus.PASS)
        short_count = sum(1 for r in results if r.direction == SignalDirection.SHORT and r.status == FactorStatus.PASS)

        # 风险收益比因子必须通过(第5个因子)
        rr_result = results[4]  # RiskRewardFactor
        rr_pass = rr_result.status == FactorStatus.PASS

        # 门控逻辑
        if not rr_pass:
            return {
                "action": "reject",
                "direction": "none",
                "confidence": 0.0,
                "reason": f"风险收益比未通过(RR={rr_result.score:.2f}),拦截下单",
                "factors": [r.to_dict() for r in results],
            }

        if long_count >= FACTOR_THRESHOLD:
            return {
                "action": "open_long",
                "direction": "long",
                "confidence": long_count / 5,
                "reason": f"{long_count}/5 因子确认做多,风险收益比通过",
                "factors": [r.to_dict() for r in results],
            }
        elif short_count >= FACTOR_THRESHOLD:
            return {
                "action": "open_short",
                "direction": "short",
                "confidence": short_count / 5,
                "reason": f"{short_count}/5 因子确认做空,风险收益比通过",
                "factors": [r.to_dict() for r in results],
            }
        else:
            return {
                "action": "wait",
                "direction": "neutral",
                "confidence": max(long_count, short_count) / 5,
                "reason": f"做多确认={long_count},做空确认={short_count},未达{FACTOR_THRESHOLD}/5门控",
                "factors": [r.to_dict() for r in results],
            }
