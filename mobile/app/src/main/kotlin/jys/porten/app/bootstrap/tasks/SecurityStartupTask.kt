/*
 * 启动任务：运行时安全自检。
 *
 * 执行点：冷启动最早期（CrashGuard 之后），在加载任何业务数据前完成。
 * 策略：只采集并缓存风险信号，不阻断启动——处置决策由 LauncherViewModel
 *       在 Splash 阶段根据 [SecurityStartupTask.lastReport] 做差异化呈现
 *       （例如 release 包检测到调试器时降级为只读浏览模式）。
 * dev flavor（ENABLE_SECURITY=false）整体跳过。
 */

package jys.porten.app.bootstrap.tasks

import android.content.Context
import jys.porten.app.BuildConfig
import jys.porten.app.bootstrap.StartupTask
import jys.porten.core.common.log.AppLogger
import jys.porten.core.security.RuntimeRiskReport
import jys.porten.core.security.SecurityGuard

public object SecurityStartupTask : StartupTask {

    private const val TAG: String = "SecurityStartup"

    /** 最近一次风险报告（volatile：启动线程写、UI 线程读）。 */
    @Volatile
    public var lastReport: RuntimeRiskReport? = null
        private set

    override val name: String = "SecurityStartup"

    override fun execute(context: Context) {
        // dev 包关闭安全自检：保证日常开发不受模拟器/root 检测干扰
        if (!BuildConfig.ENABLE_SECURITY) {
            AppLogger.d(TAG, "ENABLE_SECURITY=false，跳过安全自检")
            return
        }
        val report = SecurityGuard.inspect(context)
        lastReport = report
        if (report.hasRisk) {
            // 只记录风险类别，不记录设备指纹（敏感身份产品最小化日志原则）
            AppLogger.w(TAG, "检测到运行时风险: $report")
        }
    }
}
