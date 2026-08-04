# WeArt Index CMS · 内容管理系统启动包

## 项目结构

```
cms/
├── backend/
│   ├── main.py              # FastAPI 入口
│   ├── models.py            # SQLAlchemy 数据模型
│   ├── schemas.py           # Pydantic 请求/响应验证
│   ├── core/
│   │   ├── config.py        # 环境配置
│   │   └── database.py      # 异步数据库连接
│   ├── routers/
│   │   ├── news.py          # 新闻 CRUD API
│   │   ├── reports.py       # 日报生成 API
│   │   └── scrape.py        # 爬虫触发 + 来源管理 API
│   ├── services/
│   │   ├── ai_report.py     # AI 日报生成引擎
│   │   └── scraper.py       # 定向爬虫框架
│   └── requirements.txt
├── admin/
│   ├── dashboard.html       # 管理后台首页控制台
│   ├── news-list.html       # 新闻列表管理（浏览/筛选/删改）
│   ├── news-editor.html     # 新闻编辑器（发布/编辑/分类）
│   ├── report-gen.html      # 日报生成（AI 初稿 → 人工校对 → 发布）
│   └── source-mgr.html      # 待建：来源管理
├── sql/
│   └── schema.sql           # PostgreSQL 建表脚本
├── docker-compose.yml
└── README.md
```

## 启动方式

```bash
cd cms

# 1. 启动 PostgreSQL + Elasticsearch
docker compose up -d

# 2. 创建数据库
docker compose exec postgres psql -U postgres -c "CREATE DATABASE weart"
docker compose exec postgres psql -U postgres -d weart -f /sql/schema.sql

# 3. 安装 Python 依赖
cd backend
pip install -r requirements.txt

# 4. 配置 API Key（用于 AI 日报生成）
export AI_API_KEY="sk-your-deepseek-key"

# 5. 启动 FastAPI
python -m backend.main
# → API 文档自动生成：http://localhost:8000/docs
# → 管理后台：直接用浏览器打开 admin/dashboard.html
```

## 核心 API

| 端点 | 方法 | 说明 |
| --- | --- | --- |
| `/api/news` | GET | 新闻列表（分页/筛选：赛道/地区/状态/搜索） |
| `/api/news` | POST | 创建新闻 |
| `/api/news/{id}` | PUT | 更新新闻 |
| `/api/news/{id}` | DELETE | 删除新闻 |
| `/api/reports/generate` | POST | 触发 AI 生成日报 |
| `/api/reports` | GET | 日报列表 |
| `/api/scrape/trigger` | POST | 触发全源爬虫（异步后台） |
| `/api/scrape/sources` | GET | 来源列表 |

## 日常运营流程

```
09:00  打开 dashboard.html → 「触发抓取」
       → 爬虫自动抓取 ARTnews / 雅昌 / Hypebeast → 存入数据库（status=review）

10:00  打开 news-list.html → 筛选「待审核」
       → 逐条校对：确认标题 / 分类 / 摘要 → 点击「发布」（status=published）
       → 当天累计发布 50+ 条（首页实时显示今日新闻）

16:00  打开 report-gen.html → 选择「每日日报」→ 「AI 生成初稿」
       → AI 自动聚合当天全部已发布新闻，按模板填充（速览/复盘/数据/趋势/预告）
       → 人工校对（5-10 分钟）→ 「发布」 → 当天新闻自动归档（status→archived）

23:10  日报上线 → 首页清空（只显示明天的新新闻）
       → 日报永久留存（reports 表），支持 PDF 导出
       → 订阅用户收到日报推送

次日   重复以上流程。前一天的新闻已归档到日报中，
       首页只保留当日最新的 50+ 条更新链接。
```

**关键设计**：新闻内容来自爬虫抓取（非人工撰写），当天展示在首页，结束后自动归档到日报。日报是永久档案，新闻条目每日清空替换。

## 下一步

1. 接入真实 AI API Key（DeepSeek 或 OpenAI）→ 日报生成引擎生效
2. 搭建用户系统（注册/登录/订阅/JWT）
3. admin 页面连入真实 API（当前为原型 HTML，需改为 Vue3 + Axios 调用后端）
4. 对接微信公众号/邮件推送（日报订阅推送）
5. 部署到云服务器（Nginx + Uvicorn + PostgreSQL + Docker）


