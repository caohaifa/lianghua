"""
执行 Agent
接收决策 Agent 的指令,执行下单/平仓/止盈止损
"""
import asyncio
import logging
from .base_agent import BaseAgent, AgentStatus, AgentTask

logger = logging.getLogger(__name__)


class ExecutionAgent(BaseAgent):
    def __init__(self):
        super().__init__("执行 Agent")

    async def run(self):
        self.status = AgentStatus.ONLINE
        logger.info(f"[{self.name}] 启动")
        while True:
            if self.tasks_queue:
                task = self.tasks_queue.pop(0)
                await self._execute_order(task)
            await asyncio.sleep(0.5)

    async def _execute_order(self, task: AgentTask):
        """
        执行下单
        task.payload 包含: action, symbol, amount, price, stop_loss, strategy_name
        """
        payload = task.payload
        action = payload.get("action")

        logger.info(f"[{self.name}] 执行 {action}: {payload.get('symbol')}")

        if action in ("open_long", "open_short"):
            await self._place_order(payload)
        elif action in ("close_long", "close_short"):
            await self._close_position(payload)
        elif action == "cancel":
            await self._cancel_order(payload)

        self.tasks_done += 1

    async def _place_order(self, payload: dict):
        """下单"""
        # TODO: 调用 Java 后端 /api/v1/trade/order
        # TODO: 算法拆单降冲击成本
        logger.info(f"[{self.name}] 下单: {payload.get('symbol')} {payload.get('direction')} "
                     f"数量={payload.get('amount')} 止损={payload.get('stop_loss')}")

    async def _close_position(self, payload: dict):
        """平仓"""
        logger.info(f"[{self.name}] 平仓: {payload.get('symbol')}")

    async def _cancel_order(self, payload: dict):
        """撤单"""
        logger.info(f"[{self.name}] 撤单: {payload.get('order_id')}")
