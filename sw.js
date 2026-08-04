// WeArt Index · Service Worker（离线缓存 + PWA 支持）
const CACHE = "weart-v1";
const FILES = [
  "/",
  "index.html",
  "single.html",
  "news.html",
  "reports.html",
  "report.html",
  "article.html",
  "resources.html",
  "artist.html",
  "institution.html",
  "agenda.html",
  "account.html",
  "about.html",
  "manifest.json",
  "assets/css/style.css",
  "assets/js/main.js"
];

// 安装时预缓存核心文件
self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(FILES))
  );
  self.skipWaiting();
});

// 激活时清理旧缓存
self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// 请求拦截：缓存优先，网络回退
self.addEventListener("fetch", e => {
  e.respondWith(
    caches.match(e.request).then(cached =>
      cached || fetch(e.request).then(resp => {
        // 缓存成功的网络请求
        if (resp && resp.status === 200) {
          const clone = resp.clone();
          caches.open(CACHE).then(cache => cache.put(e.request, clone));
        }
        return resp;
      })
    )
  );
});
