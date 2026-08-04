# backend/models.py
from sqlalchemy import Column, Integer, String, Text, DECIMAL, Boolean, TIMESTAMP, ForeignKey, JSON, ARRAY, Date
from sqlalchemy.dialects.postgresql import ARRAY as PG_ARRAY
from sqlalchemy.orm import DeclarativeBase, relationship
from sqlalchemy.sql import func

class Base(DeclarativeBase): pass

class Source(Base):
    __tablename__ = "sources"
    id             = Column(Integer, primary_key=True)
    name           = Column(String(100), nullable=False)
    url            = Column(String(300))
    language       = Column(String(10), default="zh")
    type           = Column(String(30), default="media")
    is_active      = Column(Boolean, default=True)
    last_crawled_at = Column(TIMESTAMP)
    created_at     = Column(TIMESTAMP, default=func.now())

class News(Base):
    __tablename__ = "news"
    id             = Column(Integer, primary_key=True)
    title          = Column(String(500), nullable=False)
    summary        = Column(Text)
    category       = Column(String(20), nullable=False)
    region         = Column(String(30), default="")
    city           = Column(String(60), default="")
    source_id      = Column(Integer, ForeignKey("sources.id"))
    source_url     = Column(String(800), unique=True)
    source_name    = Column(String(100))
    impact         = Column(DECIMAL(3,1), default=7.0)
    thumb_img      = Column(String(300))
    status         = Column(String(20), default="review")
    published_at   = Column(TIMESTAMP)
    tags           = Column(JSON, default=[])
    created_at     = Column(TIMESTAMP, default=func.now())
    updated_at     = Column(TIMESTAMP, default=func.now())
    source         = relationship("Source", lazy="joined")

class Report(Base):
    __tablename__ = "reports"
    id             = Column(Integer, primary_key=True)
    title          = Column(String(300))
    type           = Column(String(20), default="daily")
    content        = Column(JSON, default={})
    news_ids       = Column(PG_ARRAY(Integer), default=[])
    status         = Column(String(20), default="draft")
    published_at   = Column(TIMESTAMP)
    pdf_url        = Column(String(300))
    created_at     = Column(TIMESTAMP, default=func.now())

class User(Base):
    __tablename__ = "users"
    id             = Column(Integer, primary_key=True)
    username       = Column(String(60), unique=True, nullable=False)
    email          = Column(String(120), unique=True)
    password_hash  = Column(String(255))
    role           = Column(String(20), default="editor")
    tier           = Column(String(20), default="free")
    avatar_url     = Column(String(300))
    is_active      = Column(Boolean, default=True)
    created_at     = Column(TIMESTAMP, default=func.now())

class Collection(Base):
    __tablename__ = "collections"
    id             = Column(Integer, primary_key=True)
    user_id        = Column(Integer, ForeignKey("users.id"))
    news_id        = Column(Integer, ForeignKey("news.id"))
    created_at     = Column(TIMESTAMP, default=func.now())

class Subscription(Base):
    __tablename__ = "subscriptions"
    id             = Column(Integer, primary_key=True)
    user_id        = Column(Integer, ForeignKey("users.id"))
    keyword        = Column(String(120))
    type           = Column(String(20), default="keyword")
    created_at     = Column(TIMESTAMP, default=func.now())

class Event(Base):
    __tablename__ = "events"
    id             = Column(Integer, primary_key=True)
    title          = Column(String(300))
    event_type     = Column(String(30), default="exhibition")
    location       = Column(String(150))
    event_date     = Column(Date)
    source_url     = Column(String(500))
    news_id        = Column(Integer, ForeignKey("news.id"))
    created_at     = Column(TIMESTAMP, default=func.now())
