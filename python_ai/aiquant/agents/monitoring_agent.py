"""
监控 Agent
10 分钟检查一次: 持仓状态 / 风控阈值 / 策略运行
"""
import asyncio
import logging
from .base_agent import BaseAgent, AgentStatus

logger = logging.getLogger(__name__)


class MonitoringAgent(BaseAgent):
    def __init__(self):
        super().__init__("监控 Agent")

    async def run(self):
        self.status = AgentStatus.ONLINE
        logger.info(f"[{self.name}] 启动, 10分钟检查间隔")
        while True:
            await self._check_all()
            await asyncio.sleep(600)  # 10 分钟

    async def _check_all(self):
        """全量检查"""
        await self._check_positions()
        await self._check_risk_status()
        await self._check_strategy_status()

    async def _check_positions(self):
        """检查持仓状态"""
        # TODO: 调用后端获取持仓列表
        logger.info(f"[{self.name}] 检查持仓状态")

    async def _check_risk_status(self):
        """检查风控阈值"""
        # TODO: 检查日亏损是否接近熔断
        logger.info(f"[{self.name}] 检查风控状态")

    async def _check_strategy_status(self):
        """检查策略运行状态"""
        # TODO: 检查策略是否正常运行
        logger.info(f"[{self.name}] 检查策略状态")
