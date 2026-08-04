# backend/main.py — WeArt Index CMS 入口
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .core.config import DEBUG
from .routers import news, reports, scrape


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时创建表（生产环境用 alembic）
    from .models import Base
    from .core.database import engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="WeArt Index CMS",
    description="当代艺术话语权平台 · 内容管理系统 API",
    version="0.1.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 路由注册
app.include_router(news.router)
app.include_router(reports.router)
app.include_router(scrape.router)


@app.get("/api/health")
async def health():
    return {"status": "ok", "name": "WeArt Index CMS"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=DEBUG)
