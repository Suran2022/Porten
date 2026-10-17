/*
 * 数据层装配容器（全应用唯一装配点）。
 *
 * 由 :app 的启动任务在冷启动最早期初始化（先于任何业务读取）：
 *   - [modeProvider] 由 BuildConfig.USE_MOCK 驱动（prod 恒 Live）；
 *   - token 源读 :core:storage 的安全存储（登录态接入后由登录流程写入
 *     [TOKEN_KEY]，未登录时请求不带 Authorization，由服务端 401 决策）；
 *   - 三个 Repository 单例持有，Flutter 桥接（porten/data 通道）经此访问。
 *
 * 约束：上层（feature / 桥接）只经本容器取 Repository，禁止自行 new。
 */

package jys.porten.core.data

import jys.porten.core.network.PortenApiFactory
import jys.porten.core.network.PortenApiService
import jys.porten.core.storage.SecureStore

public object PortenDataContainer {

    /** 安全存储中的鉴权 token 键（登录流程写入，网络层读取）。 */
    public const val TOKEN_KEY: String = "auth_token"

    private val lock: Any = Any()

    private var api: PortenApiService? = null

    private var secureStoreRef: SecureStore? = null

    private var modeProvider: () -> DataSourceMode = { DataSourceMode.Mock }

    /** 认证仓储（登录 / 注册 / 验证码 / 登出；token 落盘的唯一入口）。 */
    public val authRepository: AuthRepository by lazy {
        AuthRepository(modeProvider, requireApi(), requireSecureStore())
    }

    /** 我的日程仓储（惰性创建，线程安全）。 */
    public val scheduleRepository: ScheduleRepository by lazy {
        ScheduleRepository(modeProvider, requireApi())
    }

    /** 我的旅程仓储。 */
    public val tripRepository: TripRepository by lazy {
        TripRepository(modeProvider, requireApi())
    }

    /** 记笔记仓储。 */
    public val noteRepository: NoteRepository by lazy {
        NoteRepository(modeProvider, requireApi())
    }

    /**
     * 初始化装配（幂等：重复调用以最后一次为准，便于测试与热切换）。
     *
     * @param baseUrl API 基地址（flavor 的 API_BASE_URL，如 http://10.0.2.2:8000/api/v1）。
     * @param secureStore 安全存储（token 源）。
     * @param modeProvider 数据源模式提供者（读 BuildConfig.USE_MOCK，prod 恒 Live）。
     * @param enableLogging 网络日志开关（release 恒 false）。
     */
    public fun initialize(
        baseUrl: String,
        secureStore: SecureStore,
        modeProvider: () -> DataSourceMode,
        enableLogging: Boolean = false,
    ) {
        synchronized(lock) {
            this.modeProvider = modeProvider
            this.secureStoreRef = secureStore
            this.api = PortenApiFactory.create(
                baseUrl = baseUrl,
                tokenProvider = { secureStore.getString(TOKEN_KEY) },
                enableLogging = enableLogging,
            )
        }
    }

    private fun requireApi(): PortenApiService = synchronized(lock) {
        requireNotNull(api) { "PortenDataContainer 未初始化：请在启动任务中调用 initialize()" }
    }

    private fun requireSecureStore(): SecureStore = synchronized(lock) {
        requireNotNull(secureStoreRef) { "PortenDataContainer 未初始化：请在启动任务中调用 initialize()" }
    }
}
