package jys.porten.app.bootstrap

import android.content.Context
import jys.porten.core.common.crash.CrashGuard
import jys.porten.core.common.log.AppLogger

/**
 * 崩溃兜底安装任务。
 *
 * 之所以放在最前：后续所有任务都依赖「异常不会逃出」这一底线，
 * 越早接管兜底，越能覆盖到其余初始化过程中发生的意外。
 */
public data object CrashGuardStartupTask : StartupTask {

    override val name: String get() = "CrashGuard"

    /** 兜底失败不应阻断启动，但属于高优先级信息，保留 critical=false 由 CrashGuard 自身幂等保证。 */
    override fun execute(context: Context) {
        CrashGuard.install()
        AppLogger.i(name, "execute: 崩溃兜底已就绪")
    }
}
