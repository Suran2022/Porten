package jys.porten.app.bootstrap

import android.content.Context
import jys.porten.app.bootstrap.tasks.SecurityStartupTask
import jys.porten.core.common.log.AppLogger

/**
 * 应用启动编排器。
 *
 * 唯一职责：按序执行启动任务，并保证「任一任务失败都不导致 App 崩溃」。
 * 这里不写任何具体初始化逻辑，具体逻辑都在 bootstrap/tasks 下的独立任务类中。
 */
public object AppBootstrap {

    private const val TAG: String = "Bootstrap"

    /** 启动任务清单：顺序即执行顺序，新增任务在此登记。 */
    private val tasks: List<StartupTask> = listOf(
        CrashGuardStartupTask,
        LoggingStartupTask,
        SecurityStartupTask,
    )

    /**
     * 执行全部启动任务。
     *
     * 防御策略（防止启动崩溃）：
     *   1. 每个任务独立 try/catch，单个任务失败不影响后续任务；
     *   2. [StartupTask.critical] 为 false 的任务失败只记录日志；
     *   3. 记录每个任务耗时，便于定位冷启动变慢的元凶。
     */
    public fun run(context: Context) {
        AppLogger.i(TAG, "run: 开始执行 ${tasks.size} 项启动任务")
        tasks.forEach { task ->
            val startAt = System.currentTimeMillis()
            runCatching {
                task.execute(context)
            }.onFailure { throwable ->
                AppLogger.e(TAG, "run: 任务 ${task.name} 执行失败，已跳过", throwable)
            }
            AppLogger.i(TAG, "run: 任务 ${task.name} 耗时 ${System.currentTimeMillis() - startAt}ms")
        }
        AppLogger.i(TAG, "run: 启动编排完成")
    }
}
