package jys.porten.core.common.log

import android.util.Log

/**
 * 统一日志门面。
 *
 * 设计要求（针对本项目的高隐私属性）：
 *   - 禁止打印任何用户身份信息、聊天内容、Token、邮箱、Porten ID；
 *   - 生产包通过 [enabled] 关闭输出；发布混淆规则会进一步移除日志调用，双重保险；
 *   - 统一 Tag 前缀 `Porten/`，便于过滤与排错。
 *
 * 严禁在业务代码中直接使用 android.util.Log，一律走本类，方便统一脱敏与关闭策略。
 */
public object AppLogger {

    private const val TAG_PREFIX: String = "Porten/"

    /**
     * 日志总开关，由宿主在启动时依据 BuildConfig.ENABLE_LOGGING 设置。
     * 即便被忘记关闭，release 混淆规则（assumenosideeffects）也会在生产包中移除调用。
     */
    @JvmStatic
    @Volatile
    public var enabled: Boolean = true

    /** 常规流程关键点：方法入口、关键参数（不含敏感值）。 */
    @JvmStatic
    public fun i(tag: String, message: String) {
        if (enabled) Log.i(TAG_PREFIX + tag, message)
    }

    /** 调试信息：仅调查问题时使用。 */
    @JvmStatic
    public fun d(tag: String, message: String) {
        if (enabled) Log.d(TAG_PREFIX + tag, message)
    }

    /** 可恢复的异常、降级处理、命中兜底分支。 */
    @JvmStatic
    public fun w(tag: String, message: String, throwable: Throwable? = null) {
        if (!enabled) return
        if (throwable == null) Log.w(TAG_PREFIX + tag, message) else Log.w(TAG_PREFIX + tag, message, throwable)
    }

    /** 失败与错误：请求失败、被捕获的异常、不可恢复流程。 */
    @JvmStatic
    public fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (!enabled) return
        if (throwable == null) Log.e(TAG_PREFIX + tag, message) else Log.e(TAG_PREFIX + tag, message, throwable)
    }
}
