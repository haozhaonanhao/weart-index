# ==========================================================================
# WeArt Index · GitHub Pages 一键初始化
# 前提：已安装 git，已在 GitHub 创建空仓库
# 用法：把下面 YOUR_USERNAME 和 YOUR_REPO 替换后运行
# ==========================================================================
param(
  [string]$Username = "YOUR_GITHUB_USERNAME",
  [string]$Repo     = "weart-index"
)

Write-Host "=== WeArt Index · GitHub Pages 初始化 ===" -ForegroundColor Cyan

# 初始化 git 仓库
git init
git checkout -b main 2>$null

# 添加文件（.gitignore 已排除临时文件）
git add .
git commit -m "WeArt Index 初始部署"

# 关联远程仓库
$remote = "https://github.com/$Username/$Repo.git"
git remote add origin $remote 2>$null
git branch -M main

Write-Host "`n推送中..." -ForegroundColor Yellow
git push -u origin main

Write-Host "`n=== 完成 ===" -ForegroundColor Green
Write-Host "1. 打开 https://github.com/$Username/$Repo/settings/pages"
Write-Host "2. Source 选 'Deploy from a branch' → Branch 选 'main' → Save"
Write-Host "3. 等待 1 分钟 → 拿到域名 https://$Username.github.io/$Repo"
Write-Host "4. 手机浏览器打开这个域名 → 添加到主屏幕"
Write-Host ""
Write-Host "之后每天运行 daily-update.ps1 → 自动推送到 GitHub → 手机自动同步！"
