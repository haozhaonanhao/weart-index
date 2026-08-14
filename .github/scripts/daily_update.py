#!/usr/bin/env python3
# WeArt Index · 云端每日更新脚本（GitHub Actions 专用）
# 用 Python 标准库实现，无需第三方依赖
import urllib.request, re, html, os, sys, json
from datetime import datetime, timedelta
from html.parser import HTMLParser

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36"}

SOURCES = [
    ("ARTnews",       "https://www.artnews.com/"),
    ("Artforum",      "https://www.artforum.com/"),
    ("Frieze",        "https://www.frieze.com/"),
    ("Hyperallergic", "https://hyperallergic.com/"),
    ("e-flux",        "https://www.e-flux.com/"),
    ("Flash Art",     "https://flash---art.com/"),
    ("ArtDaily",      "https://artdaily.com/"),
    ("Hypebeast",     "https://hypebeast.cn/"),
    ("HB·POPMART",    "https://hypebeast.cn/tags/pop-mart"),
    ("HB·KAWS",       "https://hypebeast.cn/tags/kaws"),
    ("HB·BEARBRICK",  "https://hypebeast.cn/tags/bearbrick"),
    ("雅昌",          "https://news.artron.net/"),
]

CAT_NAMES = {"exhibition":"展览","event":"事件","release":"作品发布","partner":"品牌合作","trade":"交易","toy":"艺术潮玩"}
CAT_TAGS  = {"exhibition":"tag-exhibition","event":"tag-event","release":"tag-release","partner":"tag-partner","trade":"tag-trade","toy":"tag-toy"}

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "ignore")

def strip_tags(s):
    return re.sub(r"<[^>]+>", " ", s)

def classify(title):
    t = title.lower()
    if re.search(r"展览|展出|个展|双年展|艺博会|biennial|exhibition|retrospective|biennale|triennial", t): return "exhibition"
    if re.search(r"成交|拍卖|售出|auction|sold|price record|acquisition|collector", t): return "trade"
    if re.search(r"联名|合作|collaboration|capsule|limited edition|uniqlo|nike|louis vuitton", t): return "partner"
    if re.search(r"公仔|人偶|玩具|潮玩|bearbrick|medicom|pop mart|labubu|molly|blind box|sofubi|kaws|vinyl figure|designer toy", t): return "toy"
    if re.search(r"发布|推出|新作|collection|release|launch|debut|unveil|premiere|drops", t): return "release"
    return "event"

def main():
    today = datetime.now().strftime("%Y-%m-%d")
    today_cn = datetime.now().strftime("%Y年%m月%d日")

    # 1. 抓取
    raw = []
    for name, url in SOURCES:
        try:
            page = fetch(url)
        except Exception as e:
            print(f"  [跳过] {name}: {e}")
            continue
        links = re.findall(r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>', page, re.S)
        count = 0
        for u, t in links:
            title = html.unescape(strip_tags(t)).strip()
            title = re.sub(r"\s+", " ", title)
            if len(title) < 15: continue
            if re.search(r"/(tags?|category|author|about|contact|subscribe|login|beian)/", u, re.I): continue
            # 过滤垃圾条目：社交图标/订阅/导航链接
            if re.search(r"icon link|plus icon|subscribe|sign ?up|newsletter|log ?in|follow us|^\s*menu\s*$|youtube|instagram|twitter|facebook|linkedin|pinterest|tiktok|^icon\b", title, re.I): continue
            if name == "雅昌" and not re.search(r"/20(2[5-9]|[3-9]\d)/", u): continue
            raw.append({"title": title, "url": u, "source": name})
            count += 1
        print(f"  {name}: {count} 条")
    print(f"原始抓取: {len(raw)} 条")

    # 2. 跨天去重（读取现有 news.html 的链接）
    seen = set()
    if os.path.exists("news.html"):
        with open("news.html", encoding="utf-8") as f:
            old = f.read()
        for u in re.findall(r'<a href="(https?://[^"]+)"', old):
            seen.add(u)
        print(f"昨天链接: {len(seen)} 条，重复自动排除")

    items = []
    for it in raw:
        if it["url"] in seen: continue
        seen.add(it["url"])
        cat = "toy" if it["source"].startswith("HB·") else classify(it["title"])
        it["cat"] = cat
        items.append(it)
    print(f"去重后: {len(items)} 条")

    # 3. 精选 40 条（每赛道最多 7 条）
    cats = ["exhibition","event","release","partner","trade","toy"]
    selected = []
    for c in cats:
        pool = [x for x in items if x["cat"] == c]
        selected += pool[:7]
    if len(selected) < 40:
        remaining = [x for x in items if x not in selected]
        selected += remaining[:40 - len(selected)]
    items = selected[:40]
    per = {}
    for x in items: per[x["cat"]] = per.get(x["cat"], 0) + 1
    print(f"精选后: {len(items)} 条 {per}")

    # 4. 生成当日 news.html（40 条，带缩略图占位）
    imgs = [f"news-{i:02d}.jpg" for i in range(1,13)] + [f"toy-{i}.jpg" for i in range(1,5)]
    cards = []
    for i, it in enumerate(items):
        img = imgs[i % len(imgs)]
        tag = CAT_TAGS[it["cat"]]
        cards.append(f"""          <article class="news-card filter-target" data-cat="{it['cat']}" data-region="us-eu" data-time="today">
            <div class="nc-main">
              <div class="nc-meta"><span style="font-size:11.5px;color:var(--muted)">{it['source']} · 今日</span></div>
              <h3><a href="{it['url']}" target="_blank" rel="noopener noreferrer">{html.escape(it['title'])}</a></h3>
              <div class="nc-foot"><span>来源：{it['source']}</span></div>
            </div>
            <div class="nc-thumb"><img src="assets/images/{img}" alt="" /></div>
          </article>""")
    news_html = "\n".join(cards)
    template = """<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>全球资讯 — WeArt Index</title><link rel="stylesheet" href="assets/css/style.css"/></head>
<body data-page="news"><div id="site-header"></div>
<section class="article-hero"><div class="container"><div class="breadcrumb"><a href="index.html">首页</a> / 全球资讯</div>
<h1>全球艺术动态 · %s</h1></div></section>
<section class="section-tight"><div class="container">
<div class="filter-bar">
<div class="filter-group"><span class="f-label">赛道</span><div class="chips"><button class="chip on" data-group="cat" data-value="all">全部</button><button class="chip" data-group="cat" data-value="exhibition">展览</button><button class="chip" data-group="cat" data-value="event">事件</button><button class="chip" data-group="cat" data-value="release">作品发布</button><button class="chip" data-group="cat" data-value="partner">品牌合作</button><button class="chip" data-group="cat" data-value="trade">交易</button><button class="chip" data-group="cat" data-value="toy">艺术潮玩</button></div></div>
<div class="filter-group"><span class="f-label">地区</span><div class="chips"><button class="chip on" data-group="region" data-value="all">全部</button><button class="chip" data-group="region" data-value="cn">国内</button><button class="chip" data-group="region" data-value="us-eu">欧美</button><button class="chip" data-group="region" data-value="me">中东</button></div></div>
</div>
<div id="newsList">%s</div>
</div></section><div id="site-footer"></div><script src="assets/js/main.js"></script></body></html>
""" % (today_cn, news_html)
    with open("news.html", "w", encoding="utf-8") as f:
        f.write(template)
    print(f"news.html 已更新 ({len(items)} 条)")

    # 5. 生成日报归档
    archive = "archive"
    os.makedirs(archive, exist_ok=True)
    report_file = os.path.join(archive, f"{today}-report.html")
    if not os.path.exists(report_file):
        li = "\n".join(f'  <li><a href="{it["url"]}" target="_blank" style="color:var(--ink)">{html.escape(it["title"])}</a></li>' for it in items)
        report = f"""<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"/><title>{today_cn} 艺术日报</title><link rel="stylesheet" href="../assets/css/style.css"/></head><body style="background:var(--paper);padding:40px;max-width:900px;margin:0 auto">
<div style="margin-bottom:30px"><a href="index.html" style="font-size:14px;color:var(--ink-2)">← 返回档案目录</a></div>
<div style="border-bottom:2px solid var(--ink);padding-bottom:20px;margin-bottom:30px"><div style="font-family:monospace;font-size:12px;color:var(--muted)">WeArt Index · 日报存档</div><h1 style="font-size:28px;font-weight:800;margin:10px 0">{today_cn} 艺术日报</h1><p style="color:var(--muted)">当日收录 {len(items)} 条报道。</p></div>
<ol style="line-height:2;font-size:14px">
{li}
</ol><p style="margin-top:40px;font-size:12px;color:var(--muted)">WeArt Index · {today} 自动归档</p></body></html>"""
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)
        # 更新 archive/index.html
        idx = os.path.join(archive, "index.html")
        if os.path.exists(idx):
            with open(idx, encoding="utf-8") as f:
                ic = f.read()
        else:
            ic = f"""<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"/><title>历史日报档案 · WeArt Index</title><link rel="stylesheet" href="../assets/css/style.css"/></head><body style="background:var(--white)"><section class="article-hero"><div class="container"><div class="breadcrumb"><a href="../index.html">首页</a> / 行业日报</div><h1>历史日报档案</h1></div></section><section class="section-tight"><div class="container"><div id="archiveList">
</div></div></section></body></html>"""
        entry = f'            <div class="archive-row"><span class="ar-date">{today_cn}</span><span class="ar-title"><a href="{today}-report.html">{today_cn} 艺术日报 — {len(items)} 条</a></span><span class="ar-kw">WeArt Index</span><span class="ar-go">→</span></div>\n'
        ic = ic.replace('<div id="archiveList">', '<div id="archiveList">\n' + entry)
        with open(idx, "w", encoding="utf-8") as f:
            f.write(ic)
        print(f"日报已生成: {report_file} ({len(items)} 条)")
    else:
        print(f"今日日报已存在，跳过: {report_file}")

    print("=== 完成 ===")

    # 6. 每周日生成周报（汇总本周全部日报）
    if datetime.now().weekday() == 6:
        week_start = datetime.now() - timedelta(days=6)
        weekly = []
        for d in range(7):
            day = (week_start + timedelta(days=d)).strftime("%Y-%m-%d")
            f = os.path.join(archive, f"{day}-report.html")
            if os.path.exists(f):
                weekly.append(day)
        if weekly:
            week_end = datetime.now().strftime("%Y-%m-%d")
            wk_file = os.path.join(archive, f"{week_end}-weekly-report.html")
            if not os.path.exists(wk_file):
                links = []
                for day in weekly:
                    links.append(f'  <li><a href="{day}-report.html" style="color:var(--ink)">{day} 日报</a></li>')
                wrep = f"""<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"/><title>周报 {week_start:%m-%d} ~ {datetime.now():%m-%d} · WeArt Index</title><link rel="stylesheet" href="../assets/css/style.css"/></head><body style="background:var(--paper);padding:40px;max-width:900px;margin:0 auto">
<div style="margin-bottom:30px"><a href="index.html" style="font-size:14px;color:var(--ink-2)">← 返回档案目录</a></div>
<div style="border-bottom:2px solid var(--ink);padding-bottom:20px;margin-bottom:30px"><div style="font-family:monospace;font-size:12px;color:var(--muted)">WeArt Index · 周报</div><h1 style="font-size:28px;font-weight:800;margin:10px 0">本周艺术简报（{week_start:%m-%d} ~ {datetime.now():%m-%d}）</h1><p style="color:var(--muted)">汇总本周 {len(weekly)} 份日报。</p></div>
<ol style="line-height:2;font-size:14px">
{"\n".join(links)}
</ol><p style="margin-top:40px;font-size:12px;color:var(--muted)">WeArt Index · {week_end} 自动生成</p></body></html>"""
                with open(wk_file, "w", encoding="utf-8") as f:
                    f.write(wrep)
                print(f"周报已生成: {wk_file}（本周 {len(weekly)} 天日报）")
            else:
                print("周报已存在，跳过")

if __name__ == "__main__":
    main()
