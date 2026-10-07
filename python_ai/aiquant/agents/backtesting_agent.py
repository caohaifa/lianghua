"""
回测 Agent
基于历史价格序列执行简单策略回测,计算收益/夏普/最大回撤/胜率。
性能要点:
- 事件驱动消费 asyncio.Queue(不再 sleep 忙轮询 / list.pop(0) O(n))
- 回测主计算放工作线程 asyncio.to_thread,避免大序列阻塞 FastAPI 事件循环
- SMA 用前缀和(cumsum) O(n) 计算,替代 np.convolve 的 O(n·window)
"""
import asyncio
import logging
import numpy as np
from .base_agent import BaseAgent, AgentStatus, AgentTask

logger = logging.getLogger(__name__)


class BacktestingAgent(BaseAgent):
    def __init__(self):
        super().__init__("回测 Agent")

    async def run(self):
        self.status = AgentStatus.IDLE
        logger.info(f"[{self.name}] 启动, 等待回测任务")
        while True:
            task = await self.tasks_queue.get()  # 无任务时挂起,不占 CPU
            try:
                await self._run_backtest(task)
            except Exception as e:
                logger.error(f"[{self.name}] 回测任务失败: {e}")
            finally:
                self.tasks_queue.task_done()

    async def _run_backtest(self, task: AgentTask):
        """执行回测"""
        payload = task.payload
        strategy_name = payload.get("strategy_name", "unknown")
        symbol = payload.get("symbol", "unknown")
        period = payload.get("period", "1Y")
        prices = payload.get("prices", [])

        logger.info(f"[{self.name}] 回测: {strategy_name} @ {symbol} 周期={period}")

        if not prices or len(prices) < 30:
            result = {
                "strategy": strategy_name,
                "symbol": symbol,
                "period": period,
                "total_return": 0.0,
                "sharpe_ratio": 0.0,
                "max_drawdown": 0.0,
                "win_rate": 0.0,
                "total_trades": 0,
                "overfitting_risk": False,
                "error": "数据不足(需≥30根K线)",
            }
            self.tasks_done += 1
            return result

        prices_arr = np.array(prices, dtype=float)
        # 重计算放到工作线程,避免阻塞服务事件循环(否则回测期间 /health、/decision 全卡住)
        result = await asyncio.to_thread(
            self._backtest_sma_crossover, prices_arr, strategy_name, symbol, period)

        logger.info(f"[{self.name}] 回测完成: 收益={result['total_return']:.2%} 夏普={result['sharpe_ratio']:.2f}")
        self.tasks_done += 1
        return result

    def _backtest_sma_crossover(self, prices: np.ndarray, strategy: str, symbol: str, period: str) -> dict:
        """
        简单均线交叉策略回测:
        - 短期均线(10)上穿长期均线(30) → 买入
        - 短期均线下穿长期均线 → 卖出
        注意:本方法为纯 CPU 计算,由 _run_backtest 放入工作线程执行。
        """
        short_window = 10
        long_window = 30

        # SMA 用前缀和(O(n))计算,再按同一当前 bar 右对齐
        sma_short = self._rolling_mean(prices, short_window)
        sma_long = self._rolling_mean(prices, long_window)

        offset = long_window - short_window
        sma_short = sma_short[offset:]
        min_len = min(len(sma_short), len(sma_long))
        sma_short = sma_short[:min_len]
        sma_long = sma_long[:min_len]

        # 模拟交易
        position = 0  # 0=空仓, 1=持仓
        entry_price = 0.0
        trades = []  # 每笔交易收益率
        equity = [1.0]  # 净值曲线

        for i in range(1, min_len):
            prev_diff = sma_short[i-1] - sma_long[i-1]
            curr_diff = sma_short[i] - sma_long[i]

            if prev_diff <= 0 < curr_diff and position == 0:
                # 金叉买入
                entry_price = prices[long_window + i - 1] if long_window + i - 1 < len(prices) else prices[-1]
                position = 1
            elif prev_diff >= 0 > curr_diff and position == 1:
                # 死叉卖出
                exit_price = prices[long_window + i - 1] if long_window + i - 1 < len(prices) else prices[-1]
                if entry_price > 0:
                    ret = (exit_price - entry_price) / entry_price
                    trades.append(ret)
                    equity.append(equity[-1] * (1 + ret))
                position = 0

        # 如果还在持仓,按最后价格平仓计算
        if position == 1 and entry_price > 0:
            exit_price = prices[-1]
            ret = (exit_price - entry_price) / entry_price
            trades.append(ret)
            equity.append(equity[-1] * (1 + ret))

        # 计算指标
        total_return = (equity[-1] - 1.0) if equity else 0.0
        total_trades = len(trades)
        win_rate = sum(1 for t in trades if t > 0) / total_trades if total_trades > 0 else 0.0

        # 夏普比率(年化,假设 252 交易日)
        if len(trades) > 1:
            returns = np.array(trades)
            sharpe = float(np.mean(returns) / np.std(returns) * np.sqrt(252 / max(len(prices) / 252, 1))) if np.std(returns) > 0 else 0.0
        else:
            sharpe = 0.0

        # 最大回撤
        equity_arr = np.array(equity)
        peak = np.maximum.accumulate(equity_arr)
        drawdown = (peak - equity_arr) / peak
        max_drawdown = float(np.max(drawdown)) if len(drawdown) > 0 else 0.0

        # 过拟合风险: 交易次数过少或夏普过高
        overfitting_risk = total_trades < 5 or (sharpe > 3.0 and total_trades < 20)

        return {
            "strategy": strategy,
            "symbol": symbol,
            "period": period,
            "total_return": round(total_return, 6),
            "sharpe_ratio": round(sharpe, 4),
            "max_drawdown": round(max_drawdown, 6),
            "win_rate": round(win_rate, 4),
            "total_trades": total_trades,
            "overfitting_risk": overfitting_risk,
        }

    @staticmethod
    def _rolling_mean(arr: np.ndarray, window: int) -> np.ndarray:
        """滚动均值:前缀和实现,返回长度 len(arr)-window+1(与 np.convolve 'valid' 对齐)"""
        c = np.cumsum(np.insert(arr, 0, 0.0))
        return (c[window:] - c[:-window]) / window
