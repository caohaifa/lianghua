"""
因子 2: 量化指标 (Quantitative Indicators)
计算 RSI / MACD / 布林带 / KDJ 等技术指标
"""
import numpy as np
from .base_factor import BaseFactor
from ..models.factors import FactorResult, SignalDirection, FactorStatus, DecisionContext


class QuantIndicatorFactor(BaseFactor):
    @property
    def name(self) -> str:
        return "量化指标"

    async def evaluate(self, context: DecisionContext) -> FactorResult:
        prices = np.array(context.historical_prices)
        # MACD 需要 26 周期数据,convolve 'valid' 模式在 len(prices) < 26 时会得到空数组导致越界
        if len(prices) < 26:
            return FactorResult(
                name=self.name,
                direction=SignalDirection.NEUTRAL,
                status=FactorStatus.WARNING,
                score=0.0,
                detail=f"历史数据不足(需≥26根,当前{len(prices)}根)",
            )

        # 计算 RSI
        rsi = self._calc_rsi(prices, period=14)

        # 计算 MACD
        macd_hist = self._calc_macd_histogram(prices)

        # 布林带位置
        bb_pos = self._calc_boll_position(prices, period=20)

        # 综合判断
        long_signals = 0
        short_signals = 0

        if rsi < 30:
            long_signals += 1
        elif rsi > 70:
            short_signals += 1

        if macd_hist > 0:
            long_signals += 1
        elif macd_hist < 0:
            short_signals += 1

        if bb_pos < 0.2:
            long_signals += 1
        elif bb_pos > 0.8:
            short_signals += 1

        if long_signals > short_signals:
            direction = SignalDirection.LONG
            status = FactorStatus.PASS
            score = long_signals / 3
        elif short_signals > long_signals:
            direction = SignalDirection.SHORT
            status = FactorStatus.PASS
            score = short_signals / 3
        else:
            direction = SignalDirection.NEUTRAL
            status = FactorStatus.WARNING
            score = 0.3

        return FactorResult(
            name=self.name,
            direction=direction,
            status=status,
            score=score,
            detail=f"RSI={rsi:.1f}, MACD柱={macd_hist:.2f}, BB位置={bb_pos:.2f}",
            metadata={"rsi": rsi, "macd_hist": macd_hist, "bb_pos": bb_pos},
        )

    @staticmethod
    def _calc_rsi(prices: np.ndarray, period: int = 14) -> float:
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        avg_gain = np.mean(gains[-period:])
        avg_loss = np.mean(losses[-period:])
        if avg_loss == 0:
            return 100.0
        rs = avg_gain / avg_loss
        return 100 - (100 / (1 + rs))

    @staticmethod
    def _calc_macd_histogram(prices: np.ndarray) -> float:
        ema12 = np.convolve(prices, np.exp(np.linspace(-1, 0, 12) / 12), 'valid')
        ema26 = np.convolve(prices, np.exp(np.linspace(-1, 0, 26) / 26), 'valid')
        macd = ema12[-len(ema26):] - ema26
        signal = np.convolve(macd, np.exp(np.linspace(-1, 0, 9) / 9), 'valid')
        return float(macd[-1] - signal[-1])

    @staticmethod
    def _calc_boll_position(prices: np.ndarray, period: int = 20) -> float:
        recent = prices[-period:]
        mean = np.mean(recent)
        std = np.std(recent)
        upper = mean + 2 * std
        lower = mean - 2 * std
        if upper == lower:
            return 0.5
        return float((prices[-1] - lower) / (upper - lower))
