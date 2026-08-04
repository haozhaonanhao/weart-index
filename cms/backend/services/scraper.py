# backend/services/scraper.py — 定向爬虫服务（框架）
import asyncio, re
from datetime import datetime
import httpx
from bs4 import BeautifulSoup

SOURCES = {
    "ARTnews":    {"url":"https://www.artnews.com/",                      "type":"rss"},
    "ARTnews2":   {"url":"https://www.artnews.com/page/2/",              "type":"html"},
    "雅昌":        {"url":"https://news.artron.net/",                     "type":"html"},
    "Hypebeast":  {"url":"https://hypebeast.cn/",                        "type":"html"},
}

CAT_KEYWORDS = {
    "exhibition": ["展览","展出","个展","双年展","艺博会","博览会","biennial","exhibition","fair","gallery show"],
    "event":      ["任命","争议","诉讼","预算","预算","裁","budget","lawsuit","appoint","dies","逝世"],
    "release":    ["发布","推出","新作","系列","collection","release","launch"],
    "partner":    ["联名","合作","品牌","跨界","collaboration","brand","uniqlo","nike","louis vuitton"],
    "trade":      ["成交","拍卖","售出","市场","auction","sold","market","price","record"],
    "toy":        ["公仔","人偶","bearbrick","kaws","figure","toy","pop mart","labubu","vinyl"]
}

async def crawl_source(source_name: str, source_url: str, source_type: str = "html") -> list:
    """抓取单个源，返回新闻条目列表 [{title, url}]"""
    async with httpx.AsyncClient(timeout=30, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }) as client:
        resp = await client.get(source_url)
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "html.parser")
        items = []
        for a in soup.find_all("a", href=True):
            title = a.get_text(strip=True)
            if len(title) >= 15:
                items.append({"title": title, "url": a["href"]})
        return items


def auto_category(title: str) -> str:
    """基于标题关键词自动分类"""
    title_lower = title.lower()
    for cat, kws in CAT_KEYWORDS.items():
        for kw in kws:
            if kw in title_lower:
                return cat
    return "event"  # 默认归类为事件
