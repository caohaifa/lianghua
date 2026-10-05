"""
回测 Agent
策略历史回测 + 过拟合检测 + AI 参数自动迭代
"""
import asyncio
import logging
from .base_agent import BaseAgent, AgentStatus, AgentTask

logger = logging.getLogger(__name__)


class BacktestingAgent(BaseAgent):
    def __init__(self):
        super().__init__("回测 Agent")

    async def run(self):
        self.status = AgentStatus.IDLE
        logger.info(f"[{self.name}] 启动, 等待回测任务")
        while True:
            if self.tasks_queue:
                task = self.tasks_queue.pop(0)
                await self._run_backtest(task)
            await asyncio.sleep(2)

    async def _run_backtest(self, task: AgentTask):
        """执行回测"""
        payload = task.payload
        strategy_name = payload.get("strategy_name")
        symbol = payload.get("symbol")
        period = payload.get("period", "1Y")

        logger.info(f"[{self.name}] 回测: {strategy_name} @ {symbol} 周期={period}")

        # TODO: 使用 backtrader 执行回测
        # TODO: 过拟合检测
        # TODO: AI 参数自动迭代

        result = {
            "strategy": strategy_name,
            "symbol": symbol,
            "period": period,
            "total_return": 0.0,
            "sharpe_ratio": 0.0,
            "max_drawdown": 0.0,
            "win_rate": 0.0,
            "overfitting_risk": False,
        }

        logger.info(f"[{self.name}] 回测完成: 夏普={result['sharpe_ratio']:.2f}")
        self.tasks_done += 1
        return result
