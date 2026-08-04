# backend/services/ai_report.py — AI 日报生成引擎
import httpx, json
from datetime import date
from ..core.config import AI_API_KEY, AI_API_URL

REPORT_PROMPT = """
你是一位资深当代艺术行业分析师。基于以下近期真实报道，生成一份{report_type}的结构化报告。

要求：
1. 输出 JSON 格式
2. 包含以下字段：
   - speed_brief: 数组，5 条核心要闻摘要（每条 {title, category, source}）
   - tracks: 对象，按赛道分组（exhibition/event/release/partner/trade/toy），每组是数组 [{region, title, impact, source_url}]
   - market_data: 数组，交易数据精选 [{label, value, detail}]
   - trend_note: 字符串，行业趋势小结（200 字以内，基于报道提炼真实信号）
   - upcoming: 数组，从报道中提取的近期活动 [{date, title, location, source_url}]
3. 使用中文撰写

以下是本期新闻列表（JSON 数组）：
{news_json}
"""

async def generate_daily_report(news_list, report_type: str = "daily", report_date: date = None):
    """调用 AI API 生成日报内容"""
    news_payload = []
    for n in news_list:
        news_payload.append({
            "title": n.title,
            "category": n.category,
            "region": n.region,
            "city": n.city,
            "summary": n.summary or "",
            "source_name": n.source_name or "",
            "source_url": n.source_url,
            "impact": float(n.impact or 7.0)
        })

    prompt = REPORT_PROMPT.format(
        report_type={"daily":"每日","weekly":"每周","monthly":"每月"}.get(report_type,""),
        news_json=json.dumps(news_payload, ensure_ascii=False, indent=2)
    )

    if not AI_API_KEY:
        # 无 API key 时返回手工模板（演示用）
        return _fallback_report(news_payload, report_type, report_date)

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            f"{AI_API_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {AI_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": "你输出纯 JSON，不接受 markdown 包裹。"},
                    {"role": "user",   "content": prompt}
                ],
                "temperature": 0.4
            }
        )
        resp.raise_for_status()
        raw = resp.json()["choices"][0]["message"]["content"]
        # 清理可能的 markdown json fence
        raw = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        return json.loads(raw)


def _fallback_report(news_payload: list, report_type: str, report_date: date = None):
    """无 AI 时的简版日报（手工模板）"""
    by_cat = {}
    for n in news_payload:
        by_cat.setdefault(n["category"], []).append(n)
    speed = sorted(news_payload, key=lambda x: x.get("impact",0), reverse=True)[:5]

    return {
        "speed_brief": [{"title":n["title"],"category":n["category"],"source":n.get("source_name","")} for n in speed],
        "tracks": {cat: [{"region":it.get("city",""),"title":it["title"],"impact":it.get("impact",7.0),"source_url":it.get("source_url","")} for it in items[:4]] for cat,items in by_cat.items()},
        "market_data": [
            {"label":"报道最高成交额","value":"$62M","detail":"全球最大画作慈善拍（ARTnews）"},
            {"label":"博物馆馆藏变现","value":"$5.4M","detail":"布鲁克林博物馆（雅昌）"}
        ],
        "trend_note": "本期报道呈现：潮玩 IP 加速影视化与品牌化、超级画廊逆势收缩线下版图、博物馆资金来源承压。",
        "upcoming": [
            {"date":"2026","title":"奈良美智 × 卓纳纽约双场地个展","location":"纽约","source_url":""}
        ]
    }
