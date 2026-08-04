# backend/schemas.py
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# ---------- News ----------
class NewsCreate(BaseModel):
    title:      str  = Field(..., max_length=500)
    summary:    str  = ""
    category:   str  # exhibition / event / release / partner / trade / toy
    region:     str  = ""
    city:       str  = ""
    source_id:  Optional[int] = None
    source_url: str
    source_name:str  = ""
    impact:     float = 7.0
    tags:       List[str] = []
    status:     str  = "review"

class NewsUpdate(BaseModel):
    title:      Optional[str] = None
    summary:    Optional[str] = None
    category:   Optional[str] = None
    impact:     Optional[float] = None
    status:     Optional[str] = None
    tags:       Optional[List[str]] = None

class NewsOut(BaseModel):
    id:         int
    title:      str
    summary:    str
    category:   str
    region:     str
    city:       str
    source_name:str
    source_url: str
    impact:     float
    status:     str
    published_at: Optional[datetime]
    tags:       List[str]
    created_at: datetime

    class Config: from_attributes = True

class NewsList(BaseModel):
    total:  int
    items:  List[NewsOut]

# ---------- Reports ----------
class ReportGen(BaseModel):
    type:       str = "daily"           # daily / weekly / monthly
    start_date: Optional[str] = None    # 可选日期范围
    end_date:   Optional[str] = None

class ReportOut(BaseModel):
    id:         int
    title:      str
    type:       str
    content:    dict
    news_ids:   List[int]
    status:     str
    published_at: Optional[datetime]
    created_at: datetime

    class Config: from_attributes = True

# ---------- Scrape ----------
class ScrapeTrigger(BaseModel):
    source_id:  Optional[int] = None    # None = 全部源

class ScrapeResult(BaseModel):
    source:     str
    crawled:    int
    new_items:  int
    status:     str  # ok / error
