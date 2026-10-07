"""
AI 量化多 Agent 框架 - 入口
启动 FastAPI 服务

环境变量:
  AI_HOST      监听地址,默认 0.0.0.0
  AI_PORT      端口,默认 8000
  AI_RELOAD    开发热重载,true/false(默认 true;生产务必置 false)
  AI_WORKERS   生产进程数,reload 关闭时生效,默认 1(建议 ≈ CPU 核数)
  AI_LOG_LEVEL  日志级别,默认 info
说明: uvicorn 的 reload 与 workers 互斥——开发用 reload,生产用 workers 多进程。
"""
import os
import uvicorn


def _as_bool(v: str) -> bool:
    return v.strip().lower() in ("1", "true", "yes", "on")


if __name__ == "__main__":
    use_reload = _as_bool(os.getenv("AI_RELOAD", "true"))
    workers = max(1, int(os.getenv("AI_WORKERS", "1")))

    kwargs = dict(
        host=os.getenv("AI_HOST", "0.0.0.0"),
        port=int(os.getenv("AI_PORT", "8000")),
        log_level=os.getenv("AI_LOG_LEVEL", "info"),
    )
    # reload 与 workers 不能同时用:开发态热重载,生产态多进程吃满多核
    if use_reload:
        kwargs["reload"] = True
    else:
        kwargs["workers"] = workers

    uvicorn.run("aiquant.api:app", **kwargs)
