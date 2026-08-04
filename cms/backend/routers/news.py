# backend/routers/news.py — 新闻 CRUD
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from ..core.database import get_db
from ..models import News
from ..schemas import NewsCreate, NewsUpdate, NewsOut, NewsList

router = APIRouter(prefix="/api/news", tags=["news"])


@router.get("", response_model=NewsList)
async def list_news(
    page:     int   = Query(1, ge=1),
    size:     int   = Query(50, ge=1, le=200),
    category: str   = Query("all"),
    region:   str   = Query("all"),
    status:   str   = Query("published"),
    date:     str   = Query(""),          # YYYY-MM-DD，默认今天
    q:        str   = Query(""),
    db:       AsyncSession = Depends(get_db),
):
    from datetime import date as dt
    from sqlalchemy import func
    base = select(News)
    if category != "all":        base = base.where(News.category == category)
    if region   != "all":        base = base.where(News.region == region)
    if status:                   base = base.where(News.status == status)
    if q:                        base = base.where(News.title.ilike(f"%{q}%"))
    # 按日期过滤（默认今天）
    filter_date = dt.today() if not date else dt.fromisoformat(date)
    base = base.where(func.date(News.published_at) == filter_date)

    total_q = select(func.count()).select_from(base.subquery())
    total   = (await db.execute(total_q)).scalar() or 0

    items   = (await db.execute(
        base.order_by(News.published_at.desc().nullslast(), News.id.desc())
            .offset((page - 1) * size).limit(size)
    )).scalars().all()

    return NewsList(total=total, items=[NewsOut.model_validate(n) for n in items])


@router.get("/{news_id}", response_model=NewsOut)
async def get_news(news_id: int, db: AsyncSession = Depends(get_db)):
    n = await db.get(News, news_id)
    if not n: raise HTTPException(404, "news not found")
    return NewsOut.model_validate(n)


@router.post("", response_model=NewsOut, status_code=201)
async def create_news(body: NewsCreate, db: AsyncSession = Depends(get_db)):
    n = News(**body.model_dump())
    db.add(n)
    await db.commit()
    await db.refresh(n)
    return NewsOut.model_validate(n)


@router.put("/{news_id}", response_model=NewsOut)
async def update_news(news_id: int, body: NewsUpdate, db: AsyncSession = Depends(get_db)):
    n = await db.get(News, news_id)
    if not n: raise HTTPException(404)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(n, k, v)
    await db.commit()
    await db.refresh(n)
    return NewsOut.model_validate(n)


@router.delete("/{news_id}")
async def delete_news(news_id: int, db: AsyncSession = Depends(get_db)):
    n = await db.get(News, news_id)
    if not n: raise HTTPException(404)
    await db.delete(n)
    await db.commit()
    return {"ok": True}
