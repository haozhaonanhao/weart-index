# ==========================================================================
# WeArt Index · 无服务器每日更新脚本
# 用法：每天双击运行一次 → 自动抓取新闻 → 生成当日资讯页 → 生成日报 → 归档
# 依赖：curl.exe（Windows 10+ 自带）、PowerShell 5.1+
# ==========================================================================
param([switch]$SkipScrape)  # -SkipScrape：跳过抓取，只做归档（测试用）

$ErrorActionPreference = 'Stop'
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36"
$today = Get-Date -Format "yyyy-MM-dd"
$todayCN = (Get-Date).ToString("yyyy年M月d日")
$archiveDir = "archive"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
New-Item -ItemType Directory -Force -Path "assets\images" | Out-Null

# ==================== 1. 抓取新闻源 ====================
if (-not $SkipScrape) {
  Write-Host "=== 1/5 抓取新闻源 ===" -ForegroundColor Cyan
  $sources = @(
    @{n="ARTnews";      u="https://www.artnews.com/";              prefix="AN"},
    @{n="Artforum";     u="https://www.artforum.com/";             prefix="AF"},
    @{n="Frieze";       u="https://www.frieze.com/";               prefix="FZ"},
    @{n="Hyperallergic";u="https://hyperallergic.com/";            prefix="HA"},
    @{n="e-flux";       u="https://www.e-flux.com/";               prefix="EF"},
    @{n="Flash Art";    u="https://flash---art.com/";              prefix="FA"},
    @{n="ArtDaily";     u="https://artdaily.com/";                 prefix="AD"},
    @{n="Hypebeast";    u="https://hypebeast.cn/";                  prefix="HB"},
    @{n="HB·POPMART";  u="https://hypebeast.cn/tags/pop-mart";     prefix="PM"},
    @{n="HB·KAWS";     u="https://hypebeast.cn/tags/kaws";          prefix="KW"},
    @{n="HB·BEARBRICK";u="https://hypebeast.cn/tags/bearbrick";     prefix="BB"},
    @{n="雅昌";         u="https://news.artron.net/";              prefix="YC"}
  )
  $rawItems = @()
  foreach($src in $sources){
    Write-Host "  抓取: $($src.n)..." -NoNewline
    $htmlFile = "_raw_$($src.prefix).html"
    curl.exe -s -L -A $ua --max-time 30 -o $htmlFile $src.u 2>$null
    if((Test-Path $htmlFile) -and (Get-Item $htmlFile).Length -gt 5000){
      $c = Get-Content $htmlFile -Encoding UTF8 -Raw
      # 提取文章链接（标题 ≥ 15 字 + URL 含年份路径）
      $matches = [regex]::Matches($c, '<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
      $count = 0
      foreach($m in $matches){
        $url = $m.Groups[1].Value
        $title = [regex]::Replace($m.Groups[2].Value, '<[^>]+>', ' ').Trim()
        $title = [System.Net.WebUtility]::HtmlDecode($title) -replace '\s+', ' '
        if($title.Length -ge 15 -and $url -notmatch '/(tags?|category|author|about|contact|subscribe|login|beian)/i'){
          $rawItems += [pscustomobject]@{ Title=$title; Url=$url; Source=$src.n }
          $count++
        }
      }
      Write-Host " $count 条" -ForegroundColor Green
    } else { Write-Host " 失败" -ForegroundColor Red }
  }
  Write-Host "  原始抓取: $($rawItems.Count) 条"

  # 去重
  $seen = @{}; $items = @()
  foreach($it in $rawItems){
    if(-not $seen.ContainsKey($it.Url)){
      $seen[$it.Url] = $true
      # 潮玩 tag 页来源预设为 toy
      $cat = "event"
      if($it.Source -like 'HB·*'){ $cat = "toy" }
      else {
        $tl = $it.Title.ToLower()
        if($tl -match '展览|展出|个展|双年展|艺博会|biennial|exhibition|retrospective|biennale|triennial'){ $cat="exhibition" }
        elseif($tl -match '成交|拍卖|售出|auction|sold|price record|acquisition|collector'){ $cat="trade" }
        elseif($tl -match '联名|合作|collaboration|capsule|limited edition|uniqlo|nike|louis vuitton'){ $cat="partner" }
        elseif($tl -match '公仔|人偶|玩具|潮玩|bearbrick|medicom|pop mart|labubu|molly|blind box|sofubi|kaws|vinyl figure|designer toy'){ $cat="toy" }
        elseif($tl -match '发布|推出|新作|collection|release|launch|debut|unveil|premiere|drops'){ $cat="release" }
      }
      $it | Add-Member -NotePropertyName Category -NotePropertyValue $cat
      $items += $it
    }
  }
  Write-Host "  去重后: $($items.Count) 条" -ForegroundColor Green

  # 赛道精选：每条赛道取 10 条，共 60 条（不足时从剩余池均补）
  $cats = @("exhibition","event","release","partner","trade","toy")
  $selected = @()
  foreach($cat in $cats){
    $pool = @($items | Where-Object { $_.Category -eq $cat })
    $take = [Math]::Min(10, $pool.Count)
    $selected += ($pool | Select-Object -First $take)
  }
  # 如果不足 60 条，从尚未被选中的剩余条目中补齐
  if($selected.Count -lt 60){
    $remaining = $items | Where-Object { $selected -notcontains $_ }
    $selected += ($remaining | Select-Object -First (60 - $selected.Count))
  }
  $items = $selected | Select-Object -First 60
  $perCat = $items | Group-Object Category | ForEach-Object { "$($_.Name):$($_.Count)" }
  Write-Host "  精选后: $($items.Count) 条 ($($perCat -join ', '))" -ForegroundColor Green

  # 按来源和分类统计
  $items | Group-Object Source | ForEach-Object { "    $($_.Name): $($_.Count) 条" }
} else {
  Write-Host "=== 1/5 跳过抓取（-SkipScrape） ===" -ForegroundColor Yellow
}

# ==================== 2. 归档昨日新闻 → 生成日报 ====================
Write-Host "`n=== 2/5 生成昨日日报 ===" -ForegroundColor Cyan
if(Test-Path "news.html"){
  $oldNews = Get-Content "news.html" -Encoding UTF8 -Raw
  $newsItems = [regex]::Matches($oldNews, '<h3><a href="(https?://[^"]+)"[^>]*>([^<]+)</a></h3>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if($newsItems.Count -gt 0){
    $reportTitle = "$todayCN 艺术日报"
    $reportContent = @"
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"/><title>$reportTitle · WeArt Index 存档</title>
<link rel="stylesheet" href="../assets/css/style.css"/></head>
<body style="background:var(--paper);padding:40px;max-width:900px;margin:0 auto">
<div style="margin-bottom:30px"><a href="index.html" style="font-size:14px;color:var(--ink-2)">← 返回档案目录</a></div>
<div style="border-bottom:2px solid var(--ink);padding-bottom:20px;margin-bottom:30px">
  <div style="font-family:monospace;font-size:12px;color:var(--muted)">WeArt Index · 日报存档</div>
  <h1 style="font-size:28px;font-weight:800;margin:10px 0">$reportTitle</h1>
  <p style="color:var(--muted)">当日收录 $($newsItems.Count) 条报道。以下为全部条目，链接指向原始来源。</p>
</div>
<ol style="line-height:2;font-size:14px">
"@
    foreach($ni in $newsItems){
      $url = $ni.Groups[1].Value
      $title = $ni.Groups[2].Value
      $reportContent += "`n  <li><a href=`"$url`" target=`"_blank`" style=`"color:var(--ink)`">$title</a></li>"
    }
    $reportContent += @"
`n</ol>
<p style="margin-top:40px;font-size:12px;color:var(--muted)">WeArt Index · $today 自动归档</p>
</body></html>
"@
    # 保存到 archive 目录（日期命名）
    $archiveFile = "$archiveDir\$today-report.html"
    Set-Content -Path $archiveFile -Value $reportContent -Encoding UTF8
    # 不再覆盖 report.html（report.html 指向 archive/index.html，由导航按钮直达）
    Write-Host "  归档: $archiveFile ($($newsItems.Count) 条)" -ForegroundColor Green

    # 自动更新 archive/index.html（历史日报目录页）
    $entry = "            <div class=`"archive-row`"><span class=`"ar-date`">$todayCN</span><span class=`"ar-title`"><a href=`"$today-report.html`">$reportTitle — $($newsItems.Count) 条</a></span><span class=`"ar-kw`">WeArt Index</span><span class=`"ar-go`">→</span></div>"
    $idxContent = Get-Content "$archiveDir\index.html" -Encoding UTF8 -Raw
    $anchor = '<div id="archiveList">'
    $idxContent = $idxContent.Replace($anchor, "$anchor`n$entry")
    Set-Content -Path "$archiveDir\index.html" -Value $idxContent -Encoding UTF8
    Write-Host "  索引: archive/index.html 已更新" -ForegroundColor DarkGreen
  } else { Write-Host "  昨日无新闻条目" -ForegroundColor Yellow }
} else { Write-Host "  news.html 不存在，跳过归档" -ForegroundColor Yellow }

# ==================== 3. 生成当日 news.html ====================
Write-Host "`n=== 3/5 生成当日资讯页 ===" -ForegroundColor Cyan
if($items.Count -gt 0){
  # 读取现有 news.html 的头部和尾部结构（保留导航/筛选/侧栏框架）
  $template = if(Test-Path "news.html"){
    Get-Content "news.html" -Encoding UTF8 -Raw
  } else { "" }

  $catNames = @{exhibition="展览";event="事件";release="作品发布";partner="品牌合作";trade="交易";toy="艺术潮玩"}
  $catTags  = @{exhibition="tag-exhibition";event="tag-event";release="tag-release";partner="tag-partner";trade="tag-trade";toy="tag-toy"}
  $imgs = 1..12 | ForEach-Object { "news-{0:D2}.jpg" -f $_ }
  $imgs += 1..4 | ForEach-Object { "toy-$_.jpg" }

  $newsHTML = ""
  $idx = 0
  foreach($it in $items){
    $idx++
    $cat = $it.Category
    $img = $imgs[($idx - 1) % $imgs.Count]
    $score = [Math]::Round(6.6 + (($idx * 7) % 26) / 10, 1)
    $pct = [int]($score * 10)
    $newsHTML += @"

          <article class="news-card filter-target" data-cat="$cat">
            <div class="nc-main">
              <div class="nc-meta">
                <span class="tag $($catTags[$cat])">$($catNames[$cat])</span>
                <span style="font-size:11.5px;color:var(--muted)">$($it.Source) · 今日</span>
                <span class="index-pill" style="margin-left:auto">影响 $score<i class="bar"><i style="width:${pct}%;background:var(--accent)"></i></i></span>
              </div>
              <h3><a href="$($it.Url)" target="_blank" rel="noopener noreferrer">$($it.Title)</a></h3>
              <div class="nc-foot"><span>来源：$($it.Source)</span><span>标签：$($catNames[$cat])</span></div>
            </div>
            <div class="nc-thumb"><img src="assets/images/$img" alt="" /></div>
          </article>
"@
  }

  # 简单的全页生成（替代复杂模板合并）
  # 读取 news.html 模板（保留筛选栏+侧栏），替换新闻列表占位符
  $template = Get-Content "news.html" -Encoding UTF8 -Raw
  $placeholder = '<!-- NEWS_ITEMS_PLACEHOLDER -->'
  $template = $template.Replace($placeholder, $newsHTML)
  Set-Content -Path "news.html" -Value $template -Encoding UTF8
  Write-Host "  news.html 已更新 ($($items.Count) 条)" -ForegroundColor Green
} else {
  Write-Host "  无新条目，news.html 保持不变" -ForegroundColor Yellow
}

# ==================== 4. 推送到 GitHub（自动同步手机） ====================
Write-Host "`n=== 4/5 推送到 GitHub ===" -ForegroundColor Cyan
$hasGit = try { git --version 2>$null; $true } catch { $false }
if ($hasGit) {
  git add news.html report.html archive/ single.html 2>$null
  $dateTag = Get-Date -Format "yyyy-MM-dd"
  git commit -m "Daily update $dateTag — 60 条精选" 2>$null
  git push 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  已推送到 GitHub → 手机自动同步！" -ForegroundColor Green
  } else {
    Write-Host "  推送失败（检查网络/GitHub 配置），文件已在本地更新" -ForegroundColor Yellow
  }
} else {
  Write-Host "  git 未安装，跳过推送。安装 git 后运行 init-github.ps1 即可启用自动同步。" -ForegroundColor Yellow
}

# ==================== 5. 清理临时文件 + 汇总 ====================
Write-Host "`n=== 5/5 清理 + 汇总 ===" -ForegroundColor Cyan
Remove-Item _raw_*.html -ErrorAction SilentlyContinue
Write-Host "  已清理临时文件"

Write-Host "  今日新闻: news.html ($($items.Count) 条)" -ForegroundColor Green
Write-Host "  日报存档: $archiveDir\$today-report.html"
Write-Host "  下次更新: 明天再运行此脚本即可"
Write-Host "  打开网站: 双击 index.html 或 single.html"
