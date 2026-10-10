package jys.porten.core.common.crash

import jys.porten.core.common.log.AppLogger

/**
 * 全局崩溃兜底：Porten 的最低运行底线是「宁可降级，不可闪退到桌面」。
 *
 * 职责：
 *   1. 接管未被业务捕获的异常（含协程外、Binder 线程、厂商 ROM 的系统回调抛错）；
 *   2. 记录结构化日志供问题定位（不写用户内容，避免隐私泄露）；
 *   3. 在可控的场景下阻止默认崩溃流程，交由宿主决定降级行为。
 *
 * 注意：本类不负责「上报」，上报通道由宿主注入 [CrashGuardListener]，
 *       保持 :core:common 对第三方 SDK 零依赖。
 */
public object CrashGuard {

    private const val TAG: String = "CrashGuard"

    private var isInstalled: Boolean = false
    private var previousHandler: Thread.UncaughtExceptionHandler? = null
    private val listeners: MutableList<CrashGuardListener> = mutableListOf()

    /**
     * 安装全局兜底。
     *
     * 重复调用是安全的：幂等，避免多进程或多次初始化导致 handler 链式嵌套。
     */
    @Synchronized
    public fun install() {
        if (isInstalled) return
        previousHandler = Thread.currentThread().uncaughtExceptionHandler
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            handleUncaught(thread, throwable)
        }
        isInstalled = true
        AppLogger.i(TAG, "install: 全局崩溃兜底已安装")
    }

    /** 注册崩溃监听（多进程环境下仅主进程注册一次即可）。 */
    @Synchronized
    public fun addListener(listener: CrashGuardListener) {
        listeners.add(listener)
    }

    @Synchronized
    public fun removeListener(listener: CrashGuardListener) {
        listeners.remove(listener)
    }

    /**
     * 兜底处理入口。
     *
     * 默认策略：记录日志 → 通知监听者 → 交还原 handler。
     * 之所以保留原 handler 链：ROM 厂商与第三方 SDK 可能有自己的兜底，直接吞掉会掩盖现场。
     */
    private fun handleUncaught(thread: Thread, throwable: Throwable) {
        AppLogger.e(TAG, "uncaught: thread=${thread.name} error=${throwable.message}", throwable)
        runCatching {
            listeners.forEach { it.onUncaughtException(thread, throwable) }
        }.onFailure { AppLogger.e(TAG, "uncaught: 监听器自身异常已被忽略", it) }
        previousHandler?.uncaughtException(thread, throwable)
    }
}

/** 崩溃监听：供宿主做上报、清理、降级提示。 */
public fun interface CrashGuardListener {

    /** 发生未捕获异常时回调；该回调内的异常同样会被兜底吞掉，避免二次崩溃。 */
    public fun onUncaughtException(thread: Thread, throwable: Throwable)
}
