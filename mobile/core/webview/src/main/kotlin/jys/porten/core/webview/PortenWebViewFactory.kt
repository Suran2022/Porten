/*
 * H5 混合容器：WebView 统一壳（需求第 7 条：预留 H5 混合开发能力）。
 *
 * 安全约束（敏感身份产品的 WebView 红线）：
 *   1. 仅加载白名单域名的页面（URL 校验在 shouldOverrideUrlLoading 中强制）；
 *   2. JS 桥仅暴露白名单方法，且只在受信页面注入；
 *   3. 禁用文件访问（file:// 域封闭），禁用地理定位等敏感权限的自动授予；
 *   4. Cookies 采用独立持久化，登出时整体清理，杜绝会话残留。
 */

package jys.porten.core.webview

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import jys.porten.core.common.log.AppLogger

/** H5 白名单域（后续按后端下发的域名列表扩展）。 */
public object PortenWebWhitelist {
    /** 允许 WebView 加载的域（后缀匹配）。 */
    public val allowedHostSuffixes: Set<String> = setOf(
        // TODO: 等待真实域名确定后替换占位，当前仅允许本地调试
        "localhost", "127.0.0.1", "10.0.2.2",
    )

    /** 判断 URL 是否在白名单内。 */
    public fun contains(url: String): Boolean = runCatching {
        val host = android.net.Uri.parse(url).host?.lowercase() ?: return false
        allowedHostSuffixes.any { host == it || host.endsWith(".$it") }
    }.getOrDefault(false)
}

/** 统一 WebView 工厂：所有 H5 页面必须经由此处创建，禁止业务模块私自 new WebView。 */
public object PortenWebViewFactory {

    private const val TAG: String = "WebView"

    /** 创建安全加固的 WebView。 */
    @SuppressLint("SetJavaScriptEnabled")
    public fun create(context: Context): WebView {
        val webView = WebView(context)
        webView.settings.apply {
            javaScriptEnabled = true
            // ---- 安全线（全部显式关闭） ----
            allowFileAccess = false
            allowContentAccess = false
            allowFileAccessFromFileURLs = false
            allowUniversalAccessFromFileURLs = false
            mediaPlaybackRequiresUserGesture = true
            setGeolocationEnabled(false)
            cacheMode = WebSettings.LOAD_DEFAULT
            // UA 不追加可识别个体指纹
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean {
                val url = request.url.toString()
                val allowed = PortenWebWhitelist.contains(url)
                if (!allowed) {
                    AppLogger.w(TAG, "拦截非白名单跳转 host=${request.url.host}")
                    return true // 拒绝加载
                }
                return false
            }
        }
        return webView
    }
}
