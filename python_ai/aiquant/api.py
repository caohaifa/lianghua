"""
FastAPI 服务 - AI 服务入口
对接 Java 后端,提供 AI 决策接口
"""
import asyncio
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from .agents.orchestrator import AgentOrchestrator
from .models.factors import DecisionContext

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="AI Quant AI Service", version="1.0.0")
orchestrator = AgentOrchestrator()


@app.on_event("startup")
async def startup():
    await orchestrator.start()
    logger.info("AI 服务启动完成")


@app.on_event("shutdown")
async def shutdown():
    await orchestrator.stop()
    logger.info("AI 服务已关闭")


@app.get("/health")
async def health():
    return {"status": "ok", "agents": orchestrator.get_all_status()}


@app.get("/agents/status")
async def agent_status():
    return {"agents": orchestrator.get_all_status()}


class DecisionRequest(BaseModel):
    symbol: str
    current_price: float
    historical_prices: list[float]
    volume_history: list[float] = []
    position_side: str | None = None
    account_balance: float = 0.0
    risk_level: str = "R3"


@app.post("/decision")
async def make_decision(req: DecisionRequest):
    """触发五因子门控决策"""
    context = DecisionContext(
        symbol=req.symbol,
        current_price=req.current_price,
        historical_prices=req.historical_prices,
        volume_history=req.volume_history,
        position_side=req.position_side,
        account_balance=req.account_balance,
        risk_level=req.risk_level,
    )
    result = await orchestrator.decision_agent.make_decision(context)
    return result


class BacktestRequest(BaseModel):
    strategy_name: str
    symbol: str
    period: str = "1Y"


@app.post("/backtest")
async def submit_backtest(req: BacktestRequest):
    """提交回测任务"""
    await orchestrator.submit_backtest_task(req.model_dump())
    return {"status": "submitted", "message": "回测任务已提交"}
