package jys.porten.app.bootstrap

import android.content.Context

/**
 * 启动任务抽象。
 *
 * 每个 [execute] 只负责一件初始化事项，对应到类名即可读懂：
 * 新增 / 下线一项启动动作 = 在 AppBootstrap 的任务列表中增删一项，不在 Application 里堆砌代码。
 *
 * 契约：
 *   - [execute] 必须自身保证不抛出未捕获异常（外部仍会兜底，但不该依赖兜底）；
 *   - 主线程耗时敏感任务需自行切线程，AppBootstrap 不代做调度决策。
 */
public interface StartupTask {

    /** 任务名，用于日志与启动耗时埋点。 */
    public val name: String

    /** 是否允许在失败时继续启动（true = 失败仅记录，不影响 App 可用）。 */
    public val critical: Boolean get() = false

    /** 执行初始化。 */
    public fun execute(context: Context)
}
