/*
 * API 统一响应包（与后端 ResponseModel[T] 严格对齐）。
 *
 * 设计约束：
 *   1. code == 0 表示成功（后端全局异常处理器对业务异常同样以 200 + 非零 code 回传，
 *      网络层必须解包后判定，禁止只看 HTTP 状态码）；
 *   2. code != 0 时 [unwrap] 抛 [PortenApiException]，message 原样上抛供 UI 呈现
 *      （不吞错、不静默回退 Mock——演示数据混入生产是安全事故）。
 */

package jys.porten.core.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

/** 业务 API 异常（解包后的非零 code 或传输失败）。 */
public class PortenApiException(
    public val code: Int,
    override val message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

/** 统一响应包。 */
@Serializable
public data class ApiResponse<T>(
    val code: Int = 0,
    val message: String = "success",
    val data: T? = null,
) {
    /** 解包：成功返回 data，失败抛 [PortenApiException]。 */
    public fun unwrap(): T {
        if (code != 0) throw PortenApiException(code, message)
        return data ?: throw PortenApiException(code, "响应数据为空")
    }

    public companion object {
        private val errorJson: Json = Json { ignoreUnknownKeys = true }

        /**
         * HTTP 4xx/5xx → 业务异常：后端对业务错误返回非 2xx + ResponseModel
         * （实测 register 400 即 `{"code":400,"message":"..."}`），
         * Retrofit 此时抛 HttpException 而不会走到 [unwrap]，
         * 必须从 errorBody 解析出真实 message 透传，否则用户只能看到
         * "HTTP 400 Bad Request" 这类无意义文案。
         */
        public fun fromHttpException(e: retrofit2.HttpException): PortenApiException =
            PortenApiException(
                code = e.code(),
                message = runCatching {
                    (errorJson.parseToJsonElement(
                        e.response()?.errorBody()?.string().orEmpty(),
                    ) as? JsonObject)?.get("message")?.jsonPrimitive?.content
                }.getOrNull() ?: (e.message() ?: "网络请求失败"),
            )
    }
}
