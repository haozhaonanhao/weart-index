/* ==========================================================================
   WeWeArt Index — 原型共享脚本
   负责：全站导航/页脚注入、当前页高亮、动态日期与期号、
        Hero 轮播、数字滚动、筛选交互、订阅弹窗、移动端菜单
   ========================================================================== */

(function () {
  "use strict";

  /* ---------- 全站导航与页脚 ---------- */
  var PAGES = {
    index: "index.html",
    news: "news.html",
    article: "article.html",
    reports: "reports.html",
    report: "report.html",
    resources: "resources.html",
    artist: "artist.html",
    institution: "institution.html",
    agenda: "agenda.html",
    account: "account.html",
    about: "about.html"
  };

  var NAV = [
    { label: "全球资讯", href: PAGES.news, page: "news" },
    { label: "行业日报", href: PAGES.reports, page: "reports" },
    { label: "资源库", href: PAGES.resources, page: "resources" },
    { label: "活动预告", href: PAGES.agenda, page: "agenda" },
    { label: "关于我们", href: PAGES.about, page: "about" }
  ];

  function renderHeader() {
    var host = document.getElementById("site-header");
    if (!host) return;
    var raw = document.body.getAttribute("data-page") || "index";
    var current = { article: "news", report: "reports" }[raw] || raw;

    var links = NAV.map(function (n) {
      var cls = current === n.page ? ' class="active"' : "";
      return '<a href="' + n.href + '"' + cls + ">" + n.label + "</a>";
    }).join("");

    host.outerHTML =
      '<header class="site-header">' +
      '<div class="container nav">' +
      '<a class="brand" href="index.html">WeArt<span class="dot">·</span>Index<small>Art Intelligence</small></a>' +
      '<button class="burger" id="burger" aria-label="菜单"><span></span><span></span><span></span></button>' +
      '<nav class="nav-links" id="navLinks">' + links + "</nav>" +
      '<div class="nav-cta">' +
      '<a class="btn btn-accent btn-sm" href="archive/index.html" target="_blank" style="font-weight:700">📋 今日简报</a>' +
      '<button class="btn btn-primary btn-sm btn-sub" data-modal-open>订阅日报</button>' +
      '<a class="nav-avatar" href="account.html" title="用户中心">藏</a>' +
      "</div>" +
      "</div>" +
      "</header>";
  }

  function renderFooter() {
    var host = document.getElementById("site-footer");
    if (!host) return;
    host.outerHTML =
      '<footer class="site-footer">' +
      '<div class="container footer-top">' +
      '<div>' +
      '<a class="brand" href="index.html">WeArt<span class="dot">·</span>Index</a>' +
      '<p class="f-about">当代艺术世界的价值定义者与议程设置者。以结构化数据 + AI 解读 + 行业专家洞察，提供可认知、可量化、可预判的艺术决策支持。</p>' +
      "</div>" +
      '<div class="f-col"><h5>内容</h5><a href="news.html">全球资讯</a><a href="reports.html">行业日报</a><a href="report.html">今日日报</a><a href="agenda.html">活动预告</a></div>' +
      '<div class="f-col"><h5>资源库</h5><a href="resources.html">资源库入口</a><a href="artist.html">艺术家档案</a><a href="institution.html">机构档案</a><a href="account.html">用户中心</a></div>' +
      '<div class="f-col"><h5>关于</h5><a href="about.html">平台定位</a><a href="about.html#copyright">图片版权声明</a><a href="about.html#privacy">隐私政策</a><a href="about.html#contact">商务合作</a><a href="about.html#contact">媒体联系</a></div>' +
      "</div>" +
      '<div class="container footer-bottom">' +
      "<span>© 2026 WeArt Index · 每日 16:00（北京时间）更新日报</span>" +
      '<span><a href="about.html#copyright" style="border-bottom:1px solid rgba(255,255,255,0.35)">图片版权声明</a> · <span class="demo-note">原型演示 · 页面数据为示例占位</span></span>' +
      "</div>" +
      "</footer>";
  }

  function renderModal() {
    if (document.getElementById("subscribeModal")) return;
    var div = document.createElement("div");
    div.id = "subscribeModal";
    div.className = "modal-mask";
    div.innerHTML =
      '<div class="modal">' +
      '<button class="m-close" aria-label="关闭">✕</button>' +
      "<h3>订阅艺术日报</h3>" +
      "<p>每日 16:00（北京时间）将《当代艺术日报》发送至你的邮箱。原型演示阶段，仅验证交互。</p>" +
      '<form><input type="email" placeholder="输入邮箱地址" required /><button class="btn btn-accent" type="submit">订阅</button></form>' +
      "</div>";
    document.body.appendChild(div);
  }

  /* ---------- 动态日期与期号 ---------- */
  function renderDate() {
    var el = document.getElementById("today");
    if (!el) return;
    var WEEK = ["日", "一", "二", "三", "四", "五", "六"];
    var d = new Date();
    var label =
      d.getFullYear() + "年" + (d.getMonth() + 1) + "月" + d.getDate() + "日 星期" + WEEK[d.getDay()];
    el.textContent = label;
    // 期号：以 2026-01-01 为第 1 期
    var start = new Date(2026, 0, 1);
    var vol = Math.floor((d - start) / 86400000) + 1;
    var volEls = document.querySelectorAll(".js-vol");
    for (var i = 0; i < volEls.length; i++) {
      volEls[i].textContent = String(vol).padStart(3, "0");
    }
  }

  /* ---------- Hero 轮播 ---------- */
  function initCarousel() {
    var carousels = document.querySelectorAll(".carousel");
    carousels.forEach(function (car) {
      var slides = car.querySelectorAll(".carousel-slide");
      var dotsWrap = car.querySelector(".carousel-dots");
      if (slides.length < 2) return;

      slides.forEach(function (_, i) {
        var b = document.createElement("button");
        b.setAttribute("aria-label", "第 " + (i + 1) + " 条");
        if (i === 0) b.className = "on";
        b.addEventListener("click", function () { go(i); });
        dotsWrap.appendChild(b);
      });
      var dots = dotsWrap.querySelectorAll("button");

      var idx = 0, timer = null;
      function go(n) {
        idx = (n + slides.length) % slides.length;
        slides.forEach(function (s, i) { s.classList.toggle("active", i === idx); });
        dots.forEach(function (d, i) { d.classList.toggle("on", i === idx); });
      }
      function next() { go(idx + 1); }

      var nextBtn = car.querySelector(".carousel-next");
      var prevBtn = car.querySelector(".carousel-prev");
      if (nextBtn) nextBtn.addEventListener("click", function () { next(); reset(); });
      if (prevBtn) prevBtn.addEventListener("click", function () { go(idx - 1); reset(); });

      function reset() {
        clearInterval(timer);
        timer = setInterval(next, 5500);
      }
      reset();
    });
  }

  /* ---------- 数字滚动 ---------- */
  function initCounters() {
    var els = document.querySelectorAll("[data-count]");
    els.forEach(function (el) {
      var target = parseFloat(el.getAttribute("data-count"));
      var suffix = el.getAttribute("data-suffix") || "";
      var duration = 1100, start = null;

      function tick(ts) {
        if (!start) start = ts;
        var p = Math.min((ts - start) / duration, 1);
        var eased = 1 - Math.pow(1 - p, 3);
        var val = Math.round(target * eased);
        el.textContent = val.toLocaleString("en-US") + suffix;
        if (p < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
    });
  }

  /* ---------- 筛选交互 ---------- */
  function initFilters() {
    var bars = document.querySelectorAll(".filter-bar");
    bars.forEach(function (bar) {
      var chips = bar.querySelectorAll(".chip");
      var targets = document.querySelectorAll(".filter-target");
      chips.forEach(function (chip) {
        chip.addEventListener("click", function () {
          var group = chip.getAttribute("data-group");
          var value = chip.getAttribute("data-value");
          // 同组互斥
          bar.querySelectorAll('.chip[data-group="' + group + '"]').forEach(function (c) {
            c.classList.remove("on");
          });
          chip.classList.add("on");

          if (!targets.length) return;
          targets.forEach(function (t) {
            var g = t.getAttribute("data-" + group) || "";
            var match = value === "all" || g === value;
            t.style.display = match ? "" : "none";
          });
        });
      });
    });
  }

  /* ---------- 订阅弹窗 ---------- */
  function initModal() {
    var mask = document.getElementById("subscribeModal");
    if (!mask) return;
    var openers = document.querySelectorAll("[data-modal-open]");
    var closeBtn = mask.querySelector(".m-close");
    var form = mask.querySelector("form");

    function open() { mask.classList.add("show"); }
    function close() { mask.classList.remove("show"); }

    openers.forEach(function (b) { b.addEventListener("click", open); });
    closeBtn.addEventListener("click", close);
    mask.addEventListener("click", function (e) { if (e.target === mask) close(); });
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var email = form.querySelector("input").value.trim();
      if (!email) return;
      form.innerHTML =
        '<div style="padding:10px 0;font-size:14px;color:var(--accent-deep);font-weight:600">' +
        "✓ 订阅成功（原型演示）。每日 16:00 日报将发送至 " + email + "</div>";
    });
  }

  /* ---------- 移动端菜单 ---------- */
  function initBurger() {
    var burger = document.getElementById("burger");
    var links = document.getElementById("navLinks");
    if (!burger || !links) return;
    burger.addEventListener("click", function () {
      burger.classList.toggle("open");
      links.classList.toggle("open");
    });
  }

  /* ---------- 启动 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    renderHeader();
    renderFooter();
    renderModal();
    renderDate();
    initCarousel();
    initCounters();
    initFilters();
    initModal();
    initBurger();
  });
})();



