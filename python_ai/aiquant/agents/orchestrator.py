"""
Agent 编排器
管理四个 Agent 的生命周期和协同通信
"""
import asyncio
import logging
from .decision_agent import DecisionAgent
from .execution_agent import ExecutionAgent
from .monitoring_agent import MonitoringAgent
from .backtesting_agent import BacktestingAgent

logger = logging.getLogger(__name__)


class AgentOrchestrator:
    """多 Agent 编排器"""

    def __init__(self):
        self.decision_agent = DecisionAgent()
        self.execution_agent = ExecutionAgent()
        self.monitoring_agent = MonitoringAgent()
        self.backtesting_agent = BacktestingAgent()
        self._tasks: list[asyncio.Task] = []

    async def start(self):
        """启动所有 Agent"""
        logger.info("[Orchestrator] 启动四 Agent 协同框架")
        self._tasks = [
            asyncio.create_task(self.decision_agent.run(), name="decision"),
            asyncio.create_task(self.execution_agent.run(), name="execution"),
            asyncio.create_task(self.monitoring_agent.run(), name="monitoring"),
            asyncio.create_task(self.backtesting_agent.run(), name="backtesting"),
        ]

    async def stop(self):
        """停止所有 Agent"""
        for task in self._tasks:
            task.cancel()
        logger.info("[Orchestrator] 已停止")

    def get_all_status(self) -> list[dict]:
        """获取所有 Agent 状态"""
        return [
            self.decision_agent.get_info(),
            self.execution_agent.get_info(),
            self.monitoring_agent.get_info(),
            self.backtesting_agent.get_info(),
        ]

    async def submit_decision_task(self, context_data: dict):
        """提交决策任务"""
        from .base_agent import AgentTask
        task = AgentTask(
            task_id=f"decision-{asyncio.get_event_loop().time():.0f}",
            task_type="decision",
            payload=context_data,
        )
        await self.decision_agent.submit_task(task)

    async def submit_backtest_task(self, payload: dict):
        """提交回测任务"""
        from .base_agent import AgentTask
        task = AgentTask(
            task_id=f"backtest-{asyncio.get_event_loop().time():.0f}",
            task_type="backtest",
            payload=payload,
        )
        await self.backtesting_agent.submit_task(task)
