# backend/routers/reports.py — 日报生成与列表
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from datetime import datetime, date

from ..core.database import get_db
from ..models import News, Report
from ..schemas import ReportGen, ReportOut
from ..services.ai_report import generate_daily_report

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.post("/generate", response_model=ReportOut)
async def generate_report(body: ReportGen = ReportGen(), db: AsyncSession = Depends(get_db)):
    """AI 生成日报/周报/月报"""
    today = date.today()
    start = body.start_date and date.fromisoformat(body.start_date) or today
    end   = body.end_date   and date.fromisoformat(body.end_date)   or start

    news_list = (await db.execute(
        select(News).where(
            News.status == "published",
            News.published_at >= start,
            News.published_at <= end
        ).order_by(News.impact.desc())
    )).scalars().all()

    if not news_list:
        raise HTTPException(400, "no published news in date range")

    # 调用 AI 生成日报结构化内容
    report_content = await generate_daily_report(news_list, body.type, start)

    r = Report(
        title    = f"艺术{body.type}日报 — {start.isoformat()}",
        type     = body.type,
        content  = report_content,
        news_ids = [n.id for n in news_list],
        status   = "draft",
        published_at = func.now() if body.type == "daily" else None
    )
    db.add(r)
    # 日报生成后，将当天新闻标记为已归档（首页不再显示）
    await db.execute(
        update(News).where(News.id.in_([n.id for n in news_list])).values(status="archived")
    )
    await db.commit()
    await db.refresh(r)
    return ReportOut.model_validate(r)


@router.get("")
async def list_reports(
    type:   str = "daily",
    page:   int = Query(1, ge=1),
    size:   int = Query(10, ge=1, le=50),
    db:     AsyncSession = Depends(get_db),
):
    base  = select(Report).where(Report.type == type).order_by(Report.created_at.desc())
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    items = (await db.execute(base.offset((page-1)*size).limit(size))).scalars().all()
    return {"total": total, "items": [ReportOut.model_validate(r) for r in items]}
