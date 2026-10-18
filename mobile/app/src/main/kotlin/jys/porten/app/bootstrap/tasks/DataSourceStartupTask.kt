/*
 * 启动任务：数据源模式注入与数据层装配。
 *
 * 执行点：日志任务之后、任何业务读取之前。
 * 职责（对应 Web 端 VITE_USE_MOCK 的「Mock / 真实 API 一键切换」）：
 *   1. 按 BuildConfig.USE_MOCK 决定 FlutterHost.dataSourceMode
 *      （prod flavor 恒 Live，演示数据不污染线上）；
 *   2. 注入 API 基地址（env 通道 apiBaseUrl 供 Flutter 调试面板展示）；
 *   3. 初始化 PortenDataContainer：API 装配 + token 源（安全存储）+ 三个 Repository。
 *
 * 失败策略：数据层装配失败不阻断启动（Flutter 侧会收到 not_initialized 错误码），
 * 但 Mock 模式开关必须成功——否则 prod 包可能停留在 Mock，属于安全事故，故为 critical。
 */

package jys.porten.app.bootstrap.tasks

import android.content.Context
import jys.porten.app.BuildConfig
import jys.porten.app.bootstrap.StartupTask
import jys.porten.core.common.log.AppLogger
import jys.porten.core.data.DataSourceMode
import jys.porten.core.data.PortenDataContainer
import jys.porten.core.storage.KeystoreSecureStore
import jys.porten.feature.hybrid.FlutterHost

public data object DataSourceStartupTask : StartupTask {

    private const val TAG: String = "DataSourceStartup"

    override val name: String get() = "DataSource"

    /** Mock 开关注入失败必须阻断启动：防止 prod 包误留 Mock 模式。 */
    override val critical: Boolean get() = true

    override fun execute(context: Context) {
        // 1. 数据源模式（prod flavor 的 USE_MOCK 恒 false，命令行覆盖也不生效）
        val mode = if (BuildConfig.USE_MOCK) DataSourceMode.Mock else DataSourceMode.Live
        FlutterHost.dataSourceMode = mode
        FlutterHost.apiBaseUrl = BuildConfig.API_BASE_URL
        AppLogger.i(TAG, "execute: 数据源模式=$mode api=${BuildConfig.API_BASE_URL}")

        // 2. 数据层装配（安全存储承载鉴权 token；日志开关随 flavor）
        val secureStore = KeystoreSecureStore.create(context.applicationContext)
        PortenDataContainer.initialize(
            baseUrl = BuildConfig.API_BASE_URL,
            secureStore = secureStore,
            modeProvider = { FlutterHost.dataSourceMode },
            enableLogging = BuildConfig.ENABLE_LOGGING,
        )
        AppLogger.i(TAG, "execute: 数据层装配完成（schedules / trips / notes）")
    }
}
