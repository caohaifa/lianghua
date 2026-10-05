"""
多 Agent 基类
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional
import asyncio
import time
import logging

logger = logging.getLogger(__name__)


class AgentStatus(Enum):
    ONLINE = "online"
    IDLE = "idle"
    OFFLINE = "offline"


@dataclass
class AgentTask:
    task_id: str
    task_type: str
    payload: dict
    # 注意: 必须用 default_factory,否则所有任务共享类定义时刻的同一时间戳
    created_at: float = field(default_factory=time.time)


class BaseAgent(ABC):
    """Agent 基类"""

    def __init__(self, name: str):
        self.name = name
        self.status = AgentStatus.IDLE
        self.tasks_done = 0
        self.tasks_queue: list[AgentTask] = []

    @abstractmethod
    async def run(self):
        """Agent 主循环"""
        ...

    async def submit_task(self, task: AgentTask):
        """提交任务"""
        self.tasks_queue.append(task)
        logger.info(f"[{self.name}] 收到任务 {task.task_id}")

    def get_info(self) -> dict:
        return {
            "name": self.name,
            "status": self.status.value,
            "tasks_done": self.tasks_done,
            "tasks_pending": len(self.tasks_queue),
        }
