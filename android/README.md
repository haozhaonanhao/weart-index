WeArt Index · Android APK 编译说明
=====================================

1. 安装 Android Studio（免费）
   https://developer.android.com/studio → 下载 → 安装 → 全部默认

2. 打开项目
   启动 Android Studio → Open → 选择 D:\艺术网站\android 文件夹

3. 修改域名
   打开 app/src/main/java/com/weart/index/MainActivity.java
   把第 10 行的 "https://你的用户名.github.io/weart-index/" 替换为你的真实 GitHub Pages 域名

4. 生成图标（可选）
   右键 res → New → Image Asset → 选择一张图片 → 自动生成各尺寸图标

5. 编译 APK
   菜单 Build → Build Bundle(s) / APK(s) → Build APK(s)
   等待 2-3 分钟 → 右下角弹出提示 → 点击 locate → 拿到 app-debug.apk

6. 传到手机
   把 APK 用微信/数据线发到手机 → 点击安装 → 完成！
