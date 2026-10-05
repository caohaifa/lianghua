"""
配置管理
"""
import os
from dotenv import load_dotenv

load_dotenv()

# ══════════════════════════════════════════════
# LLM 配置
# ══════════════════════════════════════════════
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4-turbo")

# ══════════════════════════════════════════════
# 后端通信
# ══════════════════════════════════════════════
BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://localhost:8080/api/v1")

# ══════════════════════════════════════════════
# 交易所
# ══════════════════════════════════════════════
OKX_API_KEY = os.getenv("OKX_API_KEY", "")
OKX_SECRET_KEY = os.getenv("OKX_SECRET_KEY", "")
OKX_PASSPHRASE = os.getenv("OKX_PASSPHRASE", "")

# ══════════════════════════════════════════════
# 风控参数(与 Java 后端保持一致)
# ══════════════════════════════════════════════
SINGLE_LOSS_RATIO = 0.02        # 单笔最大亏损 2%
DAILY_LOSS_CIRCUIT_BREAKER = 0.03  # 日亏损熔断 3%
MAX_POSITIONS = 5               # 最大持仓数
CHECK_INTERVAL_SEC = 600       # 检查间隔 10 分钟

# ══════════════════════════════════════════════
# 五因子门控阈值
# ══════════════════════════════════════════════
FACTOR_THRESHOLD = 3            # 至少 3/5 因子同方向确认
RISK_REWARD_MIN = 1.5           # 风险收益比最低要求
