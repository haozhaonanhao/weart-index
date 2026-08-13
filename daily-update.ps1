# WeArt Index · 每日更新脚本
param([switch]$SkipScrape)
$ErrorActionPreference = 'Stop'
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36"
$today = Get-Date -Format "yyyy-MM-dd"; $todayCN = (Get-Date).ToString("yyyy年M月d日")
$archiveDir = "archive"; New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

# ==================== 1. 抓取 ====================
if (-not $SkipScrape) {
  Write-Host "=== 1/5 抓取新闻源 ===" -ForegroundColor Cyan
  $sources = @(
    @{n="ARTnews";      u="https://www.artnews.com/";              prefix="AN"}
    @{n="Artforum";     u="https://www.artforum.com/";             prefix="AF"}
    @{n="Frieze";       u="https://www.frieze.com/";               prefix="FZ"}
    @{n="Hyperallergic";u="https://hyperallergic.com/";            prefix="HA"}
    @{n="e-flux";       u="https://www.e-flux.com/";               prefix="EF"}
    @{n="Flash Art";    u="https://flash---art.com/";              prefix="FA"}
    @{n="ArtDaily";     u="https://artdaily.com/";                 prefix="AD"}
    @{n="Hypebeast";    u="https://hypebeast.cn/";                  prefix="HB"}
    @{n="HB·POPMART";  u="https://hypebeast.cn/tags/pop-mart";     prefix="PM"}
    @{n="HB·KAWS";     u="https://hypebeast.cn/tags/kaws";          prefix="KW"}
    @{n="HB·BEARBRICK";u="https://hypebeast.cn/tags/bearbrick";     prefix="BB"}
    @{n="雅昌";         u="https://news.artron.net/";              prefix="YC"}
  )
  $rawItems = @()
  foreach($src in $sources){
    Write-Host "  抓取: $($src.n)..." -NoNewline
    $htmlFile = "_raw_$($src.prefix).html"
    curl.exe -s -L -A $ua --max-time 30 -o $htmlFile $src.u 2>$null
    if((Test-Path $htmlFile) -and (Get-Item $htmlFile).Length -gt 5000){
      $c = Get-Content $htmlFile -Encoding UTF8 -Raw
      $matches = [regex]::Matches($c, '<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
      $count = 0
      foreach($m in $matches){
        $url = $m.Groups[1].Value
        $title = [regex]::Replace($m.Groups[2].Value, '<[^>]+>', ' ').Trim()
        $title = [System.Net.WebUtility]::HtmlDecode($title) -replace '\s+', ' '
        if($title.Length -ge 15 -and $url -notmatch '/(tags?|category|author|about|contact|subscribe|login|beian)/i'){
          # 雅昌混大量旧闻，只取 2025+
          if($src.n -eq '雅昌' -and $url -notmatch '/20(2[5-9]|[3-9]\d)/'){ continue }
          $rawItems += [pscustomobject]@{ Title=$title; Url=$url; Source=$src.n }
          $count++
        }
      }
      Write-Host " $count 条" -ForegroundColor Green
    } else { Write-Host " 失败" -ForegroundColor Red }
  }
  Write-Host "  原始抓取: $($rawItems.Count) 条"
  $seen = @{}
  # 加载昨天新闻链接，今天的如重复直接排除
  if(Test-Path "news.html"){
    $yesterday = Get-Content "news.html" -Encoding UTF8 -Raw
    $oldUrls = [regex]::Matches($yesterday,'<a href="(https?://[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    foreach($old in $oldUrls){ $seen[$old] = $true }
    $oldCount = $seen.Count
    if($oldCount -gt 0){ "  昨天链接已加载: $oldCount 条，今天如有重复自动排除" }
  }
  $items = @()
  foreach($it in $rawItems){
    if(-not $seen.ContainsKey($it.Url)){
      $seen[$it.Url] = $true
      if($it.Source -like 'HB·*'){ $cat = "toy" }
      else {
        $cat = "event"; $tl = $it.Title.ToLower()
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
  $items | Group-Object Source | ForEach-Object { "    $($_.Name): $($_.Count) 条" }
  # 精选 60 条
  $cats = @("exhibition","event","release","partner","trade","toy")
  $selected = @()
  foreach($cat in $cats){
    $pool = @($items | Where-Object { $_.Category -eq $cat })
    $take = [Math]::Min(7, $pool.Count)
    $selected += ($pool | Select-Object -First $take)
  }
  if($selected.Count -lt 40){
    $remaining = $items | Where-Object { $selected -notcontains $_ }
    $selected += ($remaining | Select-Object -First (40 - $selected.Count))
  }
  $items = $selected | Select-Object -First 40
  $perCat = $items | Group-Object Category | ForEach-Object { "$($_.Name):$($_.Count)" }
  Write-Host "  精选后: $($items.Count) 条 ($($perCat -join ', '))" -ForegroundColor Green
  $items | Group-Object Source | ForEach-Object { "    $($_.Name): $($_.Count) 条" }

  # 抓取文章缩略图（og:image）
  Write-Host "  抓取文章缩略图..." -NoNewline
  $thumbIdx = 0
  foreach($it in $items){
    $thumbIdx++
    $it | Add-Member -NotePropertyName Thumb -NotePropertyValue $imgs[($thumbIdx-1) % $imgs.Count] -Force
    $af = "_thumb_$thumbIdx.html"
    curl.exe -s -L -A $ua --max-time 12 -o $af $it.Url 2>$null
    if((Test-Path $af) -and (Get-Item $af).Length -gt 2000){
      $ac = Get-Content $af -Encoding UTF8 -Raw
      $og = [regex]::Match($ac, '<meta[^>]+property="og:image"[^>]+content="([^"]+)"')
      if(-not $og.Success){ $og = [regex]::Match($ac, '<meta[^>]+name="twitter:image"[^>]+content="([^"]+)"') }
      if(-not $og.Success){ $og = [regex]::Match($ac, '<img[^>]+src="(https?://[^"]+\.(?:jpe?g|png|webp))"') }
      if($og.Success){
        $imgUrl = $og.Groups[1].Value
        $ext = if($imgUrl -match '\.(jpe?g|png|webp)'){ ".$($matches[1])" } else { ".jpg" }
        $local = "thumb-{0:D3}$ext" -f $thumbIdx
        curl.exe -s -L -A $ua --max-time 10 -o "assets\images\$local" $imgUrl 2>$null
        if((Test-Path "assets\images\$local") -and (Get-Item "assets\images\$local").Length -gt 1000){
          $it.Thumb = $local
        }
      }
    }
    Remove-Item $af -ErrorAction SilentlyContinue
  }
  Write-Host " 完成" -ForegroundColor Green
} else { Write-Host "=== 1/5 跳过抓取 ===" -ForegroundColor Yellow }

# ==================== 2. 归档昨日日报 ====================
Write-Host "`n=== 2/5 生成昨日日报 ===" -ForegroundColor Cyan
$archiveFile = "$archiveDir\$today-report.html"
if(Test-Path $archiveFile){
  Write-Host "  今日已归档，跳过" -ForegroundColor DarkGray
} elseif(Test-Path "news.html"){
  $oldNews = Get-Content "news.html" -Encoding UTF8 -Raw
  $newsItems = [regex]::Matches($oldNews, '<h3><a href="(https?://[^"]+)"[^>]*>([^<]+)</a></h3>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if($newsItems.Count -gt 0){
    $reportContent = "<!DOCTYPE html><html lang=`"zh-CN`"><head><meta charset=`"UTF-8`"/><title>$todayCN 艺术日报</title><link rel=`"stylesheet`" href=`"../assets/css/style.css`"/></head><body style=`"background:var(--paper);padding:40px;max-width:900px;margin:0 auto`"><div style=`"margin-bottom:30px`"><a href=`"index.html`" style=`"font-size:14px;color:var(--ink-2)`">← 返回档案目录</a></div><div style=`"border-bottom:2px solid var(--ink);padding-bottom:20px;margin-bottom:30px`"><div style=`"font-family:monospace;font-size:12px;color:var(--muted)`">WeArt Index · 日报存档</div><h1 style=`"font-size:28px;font-weight:800;margin:10px 0`">$todayCN 艺术日报</h1><p style=`"color:var(--muted)`">当日收录 $($newsItems.Count) 条报道。</p></div><ol style=`"line-height:2;font-size:14px`">"
    foreach($ni in $newsItems){
      $reportContent += "`n  <li><a href=`"$($ni.Groups[1].Value)`" target=`"_blank`" style=`"color:var(--ink)`">$($ni.Groups[2].Value)</a></li>"
    }
    $reportContent += "`n</ol><p style=`"margin-top:40px;font-size:12px;color:var(--muted)`">WeArt Index · $today 自动归档</p></body></html>"
    Set-Content -Path $archiveFile -Value $reportContent -Encoding UTF8
    # 追加到 archive/index.html
    $entry = "            <div class=`"archive-row`"><span class=`"ar-date`">$todayCN</span><span class=`"ar-title`"><a href=`"$today-report.html`">$todayCN 艺术日报 — $($newsItems.Count) 条</a></span><span class=`"ar-kw`">WeArt Index</span><span class=`"ar-go`">→</span></div>"
    $idxContent = Get-Content "$archiveDir\index.html" -Encoding UTF8 -Raw
    $idxContent = $idxContent.Replace('<div id="archiveList">', "<div id=`"archiveList`">`n$entry")
    Set-Content -Path "$archiveDir\index.html" -Value $idxContent -Encoding UTF8
    Write-Host "  归档: $archiveFile ($($newsItems.Count) 条)" -ForegroundColor Green
  } else { Write-Host "  昨日无新闻条目" -ForegroundColor Yellow }
} else { Write-Host "  news.html 不存在" -ForegroundColor Yellow }

# ==================== 3. 生成当日 news.html ====================
if($items.Count -gt 0){
  Write-Host "`n=== 3/5 生成当日资讯页 ===" -ForegroundColor Cyan
  $catNames = @{exhibition="展览";event="事件";release="作品发布";partner="品牌合作";trade="交易";toy="艺术潮玩"}
  $catTags  = @{exhibition="tag-exhibition";event="tag-event";release="tag-release";partner="tag-partner";trade="tag-trade";toy="tag-toy"}
  $imgs = ((1..12 | ForEach-Object { "news-{0:D2}.jpg" -f $_ }) + (1..4 | ForEach-Object { "toy-$_.jpg" }))
  $lines = @(); $idx=0
  foreach($it in $items){
    $idx++; $cat=$it.Category; $src=$it.Source
    if($src -eq '雅昌'){$reg='cn'}elseif($src -eq 'Hypebeast' -or $src -like 'HB·*'){$reg='asia'}else{$reg='us-eu'}
    $img = $it.Thumb; $url=$it.Url; $title=$it.Title -replace '"','&quot;'
    $score = [Math]::Round(6.6 + (($idx * 7) % 26) / 10, 1)
    $pct = [int]($score * 10)
    $lines += '          <article class="news-card filter-target" data-cat="'+$cat+'" data-region="'+$reg+'" data-time="today">'
    $lines += '            <div class="nc-main">'
    $lines += '              <div class="nc-meta">'
    $lines += '                <span style="font-size:11.5px;color:var(--muted)">'+$src+' · 今日</span>'
    $lines += '                <span class="index-pill" style="margin-left:auto">'+$score+'<i class="bar"><i style="width:'+$pct+'%;background:var(--accent)"></i></i></span>'
    $lines += '              </div>'
    $lines += '              <h3><a href="'+$url+'" target="_blank" rel="noopener noreferrer">'+$title+'</a></h3>'
    $lines += '              <div class="nc-foot"><span>来源：'+$src+'</span></div>'
    $lines += '            </div>'
    $lines += '            <div class="nc-thumb"><img src="assets/images/'+$img+'" alt="" /></div>'
    $lines += '          </article>'
  }
  $newsHTML = $lines -join "`n"
  $template = Get-Content "news.html" -Encoding UTF8 -Raw
  # 清空 newsList 内的旧内容
  $template = $template -replace '(<div id="newsList">)[\s\S]*?(</div>\s*</div>)', '$1<!-- NEWS_ITEMS_PLACEHOLDER -->$2'
  if($template -match 'NEWS_ITEMS_PLACEHOLDER'){
    $template = $template.Replace('<!-- NEWS_ITEMS_PLACEHOLDER -->', $newsHTML)
  } else {
    $template = $template.Replace('<div id="newsList">', '<div id="newsList">'+"`n"+$newsHTML)
  }
  Set-Content -Path "news.html" -Value $template -Encoding UTF8
  # 自动补筛选属性（just in case）
  $fix = Get-Content "news.html" -Encoding UTF8 -Raw
  $fix = [regex]::Replace($fix, '(<article class="news-card filter-target")( data-cat="([^"]+)")>', { '${1}${2} data-region="us-eu" data-time="today">' })
  Set-Content -Path "news.html" -Value $fix -Encoding UTF8
  Write-Host "  news.html 已更新 ($($items.Count) 条)" -ForegroundColor Green
} else { Write-Host "`n=== 3/5 无条目 ===" -ForegroundColor Yellow }

# ==================== 4. 推送 GitHub ====================
Write-Host "`n=== 4/5 推送到 GitHub ===" -ForegroundColor Cyan
$hasGit = try { git --version 2>$null; $true } catch { $false }
if($hasGit){
  git add news.html archive/ single.html 2>$null
  git commit -m "Daily update $today — 60 条精选" 2>$null
  git push 2>$null
  if($LASTEXITCODE -eq 0){ Write-Host "  已推送 → 手机自动同步！" -ForegroundColor Green }
  else { Write-Host "  推送失败，文件已在本地更新" -ForegroundColor Yellow }
} else { Write-Host "  git 未安装，跳过推送" -ForegroundColor Yellow }

# ==================== 5. 清理 ====================
Write-Host "`n=== 5/5 清理 + 汇总 ===" -ForegroundColor Cyan
Remove-Item _raw_*.html -ErrorAction SilentlyContinue
Write-Host "  已清理临时文件"
Write-Host "  今日新闻: news.html ($($items.Count) 条)" -ForegroundColor Green
Write-Host "  日报存档: $archiveDir\$today-report.html"
Write-Host "  下次更新: 明天再运行此脚本即可"
Write-Host "  打开网站: 双击 index.html 或 single.html"
