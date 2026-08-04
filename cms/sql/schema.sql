-- ==========================================================================
-- WeArt Index CMS · 数据库设计（PostgreSQL）
-- ==========================================================================

-- 报道来源表
CREATE TABLE sources (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100)  NOT NULL,           -- 来源名称（ARTnews / 雅昌 / Hypebeast）
    url         VARCHAR(300)  NOT NULL,           -- 首页 URL
    language    VARCHAR(10)   DEFAULT 'zh',       -- zh / en
    type        VARCHAR(30)   DEFAULT 'media',    -- media / gallery / auction / brand
    is_active   BOOLEAN       DEFAULT TRUE,
    last_crawled_at TIMESTAMP,
    created_at  TIMESTAMP     DEFAULT NOW()
);

-- 新闻/资讯表
CREATE TABLE news (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(500)  NOT NULL,           -- 中文化标题
    summary     TEXT,                              -- 摘要
    category    VARCHAR(20)   NOT NULL,           -- exhibition / event / release / partner / trade / toy
    region      VARCHAR(30)   DEFAULT '',         -- cn / us-eu / asia / me
    city        VARCHAR(60)   DEFAULT '',
    source_id   INT           REFERENCES sources(id) ON DELETE SET NULL,
    source_url  VARCHAR(800)  NOT NULL UNIQUE,    -- 原文链接（唯一索引防重复）
    source_name VARCHAR(100),                     -- 来源显示名
    impact      DECIMAL(3,1)  DEFAULT 7.0,       -- 影响指数（演示/算法）
    thumb_img   VARCHAR(300),                     -- 缩略图路径
    status      VARCHAR(20)   DEFAULT 'review',  -- draft / review / published / archived
    published_at TIMESTAMP,
    reviewer_id INT           REFERENCES users(id),
    tags        JSONB         DEFAULT '[]',       -- ["KAWS","拍卖","纽约"]
    created_at  TIMESTAMP     DEFAULT NOW(),
    updated_at  TIMESTAMP     DEFAULT NOW()
);
CREATE INDEX idx_news_category ON news(category);
CREATE INDEX idx_news_status   ON news(status);
CREATE INDEX idx_news_created  ON news(created_at DESC);

-- 日报/报告表
CREATE TABLE reports (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(300)  NOT NULL,
    type        VARCHAR(20)   DEFAULT 'daily',   -- daily / weekly / monthly / quarterly
    content     JSONB         NOT NULL DEFAULT '{}', -- 结构化日报内容
    news_ids    INT[]         DEFAULT '{}',       -- 本期收录的 news id 列表
    status      VARCHAR(20)   DEFAULT 'draft',    -- draft / published
    published_at TIMESTAMP,
    pdf_url     VARCHAR(300),
    created_at  TIMESTAMP     DEFAULT NOW()
);
CREATE INDEX idx_reports_type ON reports(type);
CREATE INDEX idx_reports_pub  ON reports(published_at DESC);

-- 用户表
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(60)   NOT NULL UNIQUE,
    email       VARCHAR(120)  UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role        VARCHAR(20)   DEFAULT 'editor',   -- admin / editor / reviewer
    tier        VARCHAR(20)   DEFAULT 'free',     -- free / pro / enterprise
    avatar_url  VARCHAR(300),
    is_active   BOOLEAN       DEFAULT TRUE,
    created_at  TIMESTAMP     DEFAULT NOW()
);

-- 收藏表
CREATE TABLE collections (
    id          SERIAL PRIMARY KEY,
    user_id     INT           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    news_id     INT           NOT NULL REFERENCES news(id) ON DELETE CASCADE,
    created_at  TIMESTAMP     DEFAULT NOW(),
    UNIQUE(user_id, news_id)
);

-- 订阅关键词表
CREATE TABLE subscriptions (
    id          SERIAL PRIMARY KEY,
    user_id     INT           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    keyword     VARCHAR(120)  NOT NULL,           -- 关键词 / 艺术家名 / 地区
    type        VARCHAR(20)   DEFAULT 'keyword',  -- keyword / artist / region
    created_at  TIMESTAMP     DEFAULT NOW()
);

-- 活动/日程表
CREATE TABLE events (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(300)  NOT NULL,
    event_type  VARCHAR(30)   DEFAULT 'exhibition', -- exhibition / auction / forum / fair / opening
    location    VARCHAR(150),
    event_date  DATE,
    source_url  VARCHAR(500),
    news_id     INT           REFERENCES news(id),
    created_at  TIMESTAMP     DEFAULT NOW()
);

-- 初始化默认管理员
INSERT INTO users (username, email, password_hash, role, tier)
VALUES ('admin', 'admin@weart-index.com', '$2b$12$placeholder', 'admin', 'pro');

-- 初始化来源（9 个已验证可抓取源）
INSERT INTO sources (name, url, language, type) VALUES
  ('ARTnews',      'https://www.artnews.com/',       'en', 'media'),
  ('雅昌艺术网',   'https://news.artron.net/',       'zh', 'media'),
  ('Hypebeast',    'https://hypebeast.cn/',           'zh', 'media'),
  ('Artforum',     'https://www.artforum.com/',       'en', 'media'),
  ('Frieze',       'https://www.frieze.com/',         'en', 'media'),
  ('Hyperallergic','https://hyperallergic.com/',      'en', 'media'),
  ('e-flux',       'https://www.e-flux.com/',         'en', 'media'),
  ('Flash Art',    'https://flash---art.com/',        'en', 'media'),
  ('ArtDaily',     'https://artdaily.com/',           'en', 'media');
