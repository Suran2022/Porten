package jys.porten.app.bootstrap

import android.content.Context
import jys.porten.app.BuildConfig
import jys.porten.core.common.log.AppLogger

/**
 * 日志开关同步任务。
 *
 * 按 BuildConfig.ENABLE_LOGGING 决定端内日志是否输出；
 * 发布包即便被遗忘关闭，proguard 规则也会静态移除 Log 调用，形成双层保险。
 */
public data object LoggingStartupTask : StartupTask {

    override val name: String get() = "Logging"

    override fun execute(context: Context) {
        AppLogger.enabled = BuildConfig.ENABLE_LOGGING
        AppLogger.i(name, "execute: 日志开关=${BuildConfig.ENABLE_LOGGING}")
    }
}
