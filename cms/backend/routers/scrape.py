# backend/routers/scrape.py — 爬虫触发与来源管理
from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from ..core.database import get_db
from ..models import Source, News
from ..schemas import ScrapeTrigger, ScrapeResult
from ..services.scraper import crawl_source, auto_category

router = APIRouter(prefix="/api/scrape", tags=["scrape"])


@router.post("/trigger")
async def trigger_scrape(
    body: ScrapeTrigger,
    bg: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """触发抓取（异步后台执行）"""
    q = select(Source).where(Source.is_active == True)
    if body.source_id:
        q = q.where(Source.id == body.source_id)
    sources = (await db.execute(q)).scalars().all()

    async def do_scrape():
        for src in sources:
            try:
                items = await crawl_source(src.name, src.url)
                new_count = 0
                for item in items:
                    exists = await db.execute(
                        select(News).where(News.source_url == item["url"])
                    )
                    if exists.scalar():
                        continue
                    n = News(
                        title       = item["title"],
                        category    = auto_category(item["title"]),
                        source_id   = src.id,
                        source_url  = item["url"],
                        source_name = src.name,
                        status      = "review"
                    )
                    db.add(n)
                    new_count += 1
                src.last_crawled_at = datetime.now()
            except Exception as e:
                print(f"scrape error [{src.name}]: {e}")
        await db.commit()

    bg.add_task(do_scrape)
    return {"ok": True, "message": f"triggered {len(sources)} sources, running in background"}


@router.get("/sources")
async def list_sources(db: AsyncSession = Depends(get_db)):
    sources = (await db.execute(select(Source))).scalars().all()
    return [{"id":s.id,"name":s.name,"last_crawled":s.last_crawled_at.isoformat() if s.last_crawled_at else None} for s in sources]
