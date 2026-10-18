/*
 * Retrofit 装配工厂（全应用唯一出口，对齐 PortenHttpClientFactory 的单例约束）。
 *
 * 职责：
 *   1. 以注入的 baseUrl + OkHttpClient 构建 [PortenApiService]；
 *   2. 通过 [AuthInterceptor] 附加 Bearer token（token 源由 :core:data 注入，
 *      本模块不依赖 :core:storage，保持网络层无存储语义）；
 *   3. kotlinx.serialization 配置与 Web 端对齐：忽略未知键（后端加字段不崩）、
 *      显式默认值、不允许 null 字面量外的隐式转换。
 */

package jys.porten.core.network

import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import okhttp3.MediaType.Companion.toMediaType

/** 鉴权拦截器：从注入的 token 源读取 Bearer 令牌（无 token 时不附加头，由服务端 401 决策）。 */
public class AuthInterceptor(
    private val tokenProvider: () -> String?,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val token = runCatching { tokenProvider() }.getOrNull()
        val enriched = if (!token.isNullOrBlank()) {
            request.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        } else {
            request
        }
        return chain.proceed(enriched)
    }
}

/** API 装配工厂。 */
public object PortenApiFactory {

    /** 与 Web 端 fetch 包装一致的 JSON 策略：容忍后端新增字段，严格缺失必填字段。 */
    public val json: Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    /**
     * 构建 API 服务。
     *
     * @param baseUrl 形如 `http://10.0.2.2:8000/api/v1`（末次斜杠由本方法补齐）。
     * @param tokenProvider 鉴权 token 源（读安全存储，禁止缓存到内存字段）。
     * @param enableLogging 是否输出网络日志（release 恒 false）。
     */
    public fun create(
        baseUrl: String,
        tokenProvider: () -> String?,
        enableLogging: Boolean = false,
        connectTimeoutSeconds: Long = 15,
        readTimeoutSeconds: Long = 20,
    ): PortenApiService {
        val normalizedBaseUrl = if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
        val client = OkHttpClient.Builder()
            .connectTimeout(connectTimeoutSeconds, TimeUnit.SECONDS)
            .readTimeout(readTimeoutSeconds, TimeUnit.SECONDS)
            .addInterceptor(AuthInterceptor(tokenProvider))
            .apply {
                if (enableLogging) {
                    addInterceptor(
                        okhttp3.logging.HttpLoggingInterceptor().apply {
                            // 只记录请求行，禁止记录 BODY（可能含 token 与用户内容）
                            level = okhttp3.logging.HttpLoggingInterceptor.Level.BASIC
                        },
                    )
                }
            }
            .build()

        val converter = json.asConverterFactory("application/json".toMediaType())
        return Retrofit.Builder()
            .baseUrl(normalizedBaseUrl)
            .client(client)
            .addConverterFactory(converter)
            .build()
            .create(PortenApiService::class.java)
    }
}
