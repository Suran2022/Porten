/*
 * 数据仓储：Mock / 真实 API 一键切换（对齐 React Web 端 VITE_USE_MOCK 能力）。
 *
 * 架构约束：
 *   - Repository 是业务数据的唯一入口：上层（feature / Flutter 桥接）禁止绕过直连网络；
 *   - 数据来源由 [DataSourceMode] 决定，切换能力由两处驱动：
 *       1. 编译期：gradle flavor 的 USE_MOCK buildConfigField；
 *       2. 运行期：设置页的显式开关（仅 dev / staging 可用，prod 恒为 live）。
 *   - 敏感身份产品约束：Mock 数据必须为合成数据，禁止包含任何真实用户信息。
 */

package jys.porten.core.data

import jys.porten.core.common.log.AppLogger

/** 数据源模式。 */
public enum class DataSourceMode {
    /** 端内 Mock 引擎（演示 / 无后端联调）。 */
    Mock,

    /** 真实后端。 */
    Live,
}

/**
 * 仓储基类：统一承载 Mock / Live 双通道分发。
 *
 * 子类按业务域提供 [fetchLive] 与 [fetchMock] 两个实现，
 * 基类负责选择、防御兜底与日志。
 *
 * @param T 业务数据类型。
 */
public abstract class PortenRepository<T>(
    /** 当前生效的数据源模式（由宿主壳注入，prod 恒为 Live）。 */
    private val modeProvider: () -> DataSourceMode,
) {

    /**
     * 获取数据。
     *
     * 防御策略：
     *   - Live 通道异常时**不静默回退 Mock**（演示数据混入生产是安全事故），
     *     直接向上抛出由 UI 呈现错误态；
     *   - Mock 通道异常时抛出 [IllegalStateException]，暴露 Mock 引擎的移植遗漏。
     */
    public suspend fun fetch(): T {
        val mode = modeProvider()
        AppLogger.d(TAG, "fetch mode=$mode")
        return when (mode) {
            DataSourceMode.Live -> fetchLive()
            DataSourceMode.Mock -> fetchMock()
        }
    }

    /**
     * 写操作分发助手：与 [fetch] 相同的模式选择与防御语义，
     * 供子类的 create / update / delete 等方法复用（避免每个方法重复 when）。
     */
    protected suspend fun <R> dispatch(
        live: suspend () -> R,
        mock: suspend () -> R,
    ): R {
        val mode = modeProvider()
        AppLogger.d(TAG, "dispatch mode=$mode")
        return when (mode) {
            DataSourceMode.Live -> live()
            DataSourceMode.Mock -> mock()
        }
    }

    /** 真实后端读取（子类实现，禁止返回演示数据）。 */
    protected abstract suspend fun fetchLive(): T

    /** Mock 引擎读取（子类实现，数据必须可复现、无真实用户信息）。 */
    protected abstract suspend fun fetchMock(): T

    public companion object {
        private const val TAG: String = "Repository"
    }
}

/**
 * 仓储外的模式分发助手（供非 [PortenRepository] 语义的域使用，如认证）。
 *
 * 与 [PortenRepository.dispatch] 同一套防御语义：Live 通道异常不静默回退 Mock。
 */
internal suspend fun <R> dispatchByMode(
    mode: DataSourceMode,
    live: suspend () -> R,
    mock: suspend () -> R,
): R = when (mode) {
    DataSourceMode.Live -> live()
    DataSourceMode.Mock -> mock()
}
