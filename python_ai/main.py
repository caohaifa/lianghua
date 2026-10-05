"""
AI 量化多 Agent 框架 - 入口
启动 FastAPI 服务
"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "aiquant.api:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
