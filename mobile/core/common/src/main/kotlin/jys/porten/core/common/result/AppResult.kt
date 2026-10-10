package jys.porten.core.common.result

/**
 * 统一结果封装。
 *
 * 与后端 `ResponseModel { code, message, data }` 结构对齐，
 * 规定所有跨层调用（Repository / DataSource / 桥接层）统一返回本类型，禁止裸抛异常跨层传播。
 *
 * 用法约定：
 * ```kotlin
 * override suspend fun fetch(): AppResult<Profile> = runCatchingAsResult {
 *     api.getProfile()
 * }
 * ```
 */
public sealed interface AppResult<out T> {

    /** 成功：携带业务数据。 */
    public data class Success<out T>(val data: T) : AppResult<T>

    /**
     * 失败：携带错误码、用户可见文案与可选的根因。
     *
     * @property code 业务/协议错误码，与后端保持一致；非 HTTP 场景使用 [FailureCodes] 中的本地取值。
     * @property message 面向用户的可读文案，UI 层可直接展示。
     * @property cause 内部根因，仅用于日志与崩溃上报，**不可**直接展示给用户。
     */
    public data class Failure(
        val code: Int,
        val message: String,
        val cause: Throwable? = null,
    ) : AppResult<Nothing>
}

/**
 * 本地错误码：用于「未触达服务端」或「端自身异常」的场景，避免与后端码段冲突。
 * 约定：本地码使用负数区间，后端码 >= 0。
 */
public object FailureCodes {

    /** 网络不可达或连接被中断。 */
    public const val NETWORK_UNREACHABLE: Int = -100

    /** 请求超时。 */
    public const val TIMEOUT: Int = -101

    /** 服务端返回的数据结构不符合预期（字段缺失或类型不匹配）。 */
    public const val PARSE_ERROR: Int = -102

    /** 未登录或登录态已失效。 */
    public const val UNAUTHORIZED: Int = -103

    /** 端侧安全校验未通过（运行环境风险、证书校验失败等）。 */
    public const val SECURITY_BLOCKED: Int = -104

    /** 未知异常兜底。 */
    public const val UNKNOWN: Int = -999
}

/** 是否成功，便于 UI 层做分支。 */
public fun <T> AppResult<T>.isSuccess(): Boolean = this is AppResult.Success

/** 取值，失败时返回 [fallback]，用于「可有可无」的数据。 */
public fun <T> AppResult<T>.getOrNullSafe(fallback: T): T =
    (this as? AppResult.Success)?.data ?: fallback

/** 把普通异常安全转换为 [AppResult.Failure]，杜绝异常跨层逃逸。 */
public inline fun <T> runCatchingAsResult(
    unknownMessage: String = "请求失败，请稍后重试",
    block: () -> T,
): AppResult<T> = try {
    AppResult.Success(block())
} catch (t: Throwable) {
    AppResult.Failure(code = FailureCodes.UNKNOWN, message = unknownMessage, cause = t)
}

/** 结果变换：成功时映射数据，失败原样透出。 */
public inline fun <T, R> AppResult<T>.mapResult(transform: (T) -> R): AppResult<R> = when (this) {
    is AppResult.Success -> AppResult.Success(transform(data))
    is AppResult.Failure -> this
}
