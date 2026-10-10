/*
 * HTTP 客户端统一封装。
 *
 * 设计约束：
 *   1. 全应用唯一的 OkHttpClient 出口（连接池/线程池复用，禁止各模块 new）；
 *   2. 拦截器链有序：日志（可关）→ 安全头 → 业务头；
 *   3. release 包禁用明文 HTTP（networkSecurityConfig 兜底），此处再防御一层；
 *   4. 敏感身份产品：User-Agent 不携带可识别个体的指纹串。
 */

package jys.porten.core.network

import jys.porten.core.common.log.AppLogger
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import java.util.concurrent.TimeUnit

/** 业务公共请求头拦截器。 */
public class PortenHeaderInterceptor(
    /** 是否允许明文 HTTP（仅 dev flavor 允许，用于本机联调）。 */
    private val allowCleartext: Boolean,
) : Interceptor {

    public companion object {
        private const val TAG: String = "NetworkHeader"
    }

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        // 防御：非 dev 环境直接拒绝明文请求，避免 token 走裸 HTTP
        if (!allowCleartext && request.url.isHttps.not()) {
            AppLogger.w(TAG, "拦截明文 HTTP 请求（生产环境禁止）：${request.url.host}")
            throw SecurityException("明文 HTTP 请求被 Porten 网络层拒绝")
        }

        val enriched = request.newBuilder()
            .header("X-Porten-Client", "android")
            .build()
        return chain.proceed(enriched)
    }
}

/** OkHttp 客户端工厂（全应用单例出口）。 */
public object PortenHttpClientFactory {

    /**
     * 构建标准客户端。
     *
     * @param allowCleartext 仅 dev flavor 传 true。
     * @param enableLogging 是否输出网络日志（release 恒 false，避免敏感信息落 logcat）。
     */
    public fun create(
        allowCleartext: Boolean,
        enableLogging: Boolean,
        connectTimeoutSeconds: Long = 15,
        readTimeoutSeconds: Long = 20,
    ): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(connectTimeoutSeconds, TimeUnit.SECONDS)
        .readTimeout(readTimeoutSeconds, TimeUnit.SECONDS)
        .addInterceptor(PortenHeaderInterceptor(allowCleartext))
        .apply {
            // 日志拦截器由调用方按 flavor 注入；此处保留扩展点，release 恒不输出
            if (enableLogging) {
                eventListenerFactory { call ->
                    PortenNetworkEventListener(call.request().url.host, enableLogging)
                }
            }
        }
        .build()
}

/** 精简网络事件监听：只记录主机与耗时，禁止记录 URL 全量与请求体（含敏感内容）。 */
public class PortenNetworkEventListener(
    private val host: String,
    private val enabled: Boolean,
) : okhttp3.EventListener() {

    override fun callEnd(call: okhttp3.Call) {
        if (enabled) {
            AppLogger.d("Network", "callEnd host=$host")
        }
    }

    override fun callFailed(call: okhttp3.Call, e: java.io.IOException) {
        // 失败日志只含主机与异常类型，不含路径/参数
        if (enabled) {
            AppLogger.w("Network", "callFailed host=$host type=${e.javaClass.simpleName}")
        }
    }
}
