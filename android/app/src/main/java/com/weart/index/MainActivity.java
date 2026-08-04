package com.weart.index;

import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {

    // ==============================================
    // ★ 替换为你的 GitHub Pages 域名
    // 部署完成后在 https://github.com/你的用户名/weart-index/settings/pages 查看
    // ==============================================
    private static final String SITE_URL = "https://你的用户名.github.io/weart-index/";

    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        setContentView(webView);

        // WebView 配置
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        settings.setSupportZoom(true);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);

        // 在 App 内打开链接（不跳系统浏览器）
        webView.setWebViewClient(new WebViewClient());

        // 加载网站
        webView.loadUrl(SITE_URL);
    }

    // 返回键：优先返回上一页，无法返回时退出
    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
