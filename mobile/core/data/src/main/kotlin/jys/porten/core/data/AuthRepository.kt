/*
 * 认证仓储：Mock / 真实 API 双通道（对齐 Web 端 authStore 的登录/注册能力）。
 *
 * 职责边界：
 *   - 登录 / 注册 / 验证码 / 登出的唯一业务入口，上层（Flutter 桥接）禁止直连网络；
 *   - Live 通道成功后立即把 access_token 写入安全存储（网络层
 *     [jys.porten.core.network.AuthInterceptor] 从同一存储读取 Bearer 头）；
 *   - Mock 通道保留端内假会话（任意合法凭证放行），仅 dev / staging 演示使用；
 *   - Live 通道异常不静默回退 Mock（假会话混入生产是安全事故），原样上抛。
 */

package jys.porten.core.data

import jys.porten.core.common.log.AppLogger
import jys.porten.core.model.AuthLoginCodePayload
import jys.porten.core.model.AuthLoginPasswordPayload
import jys.porten.core.model.AuthLoginResult
import jys.porten.core.model.AuthLogoutPayload
import jys.porten.core.model.AuthRegisterPayload
import jys.porten.core.model.AuthSendCodePayload
import jys.porten.core.model.AuthTokenInfo
import jys.porten.core.model.AuthUserBrief
import jys.porten.core.network.PortenApiService
import jys.porten.core.storage.SecureStore
import kotlinx.coroutines.delay

/**
 * 认证仓储。
 *
 * @param modeProvider 数据源模式提供者（prod 恒 Live）。
 * @param api 业务 API 服务。
 * @param secureStore 安全存储（token 的落盘载体，禁止明文缓存到内存字段）。
 */
public class AuthRepository(
    private val modeProvider: () -> DataSourceMode,
    private val api: PortenApiService,
    private val secureStore: SecureStore,
) {

    /** 发送验证码（Live 走后端邮件通道；Mock 仅模拟耗时）。 */
    public suspend fun sendCode(email: String, purpose: String) {
        dispatchByMode(
            mode = modeProvider(),
            live = { api.sendVerificationCode(AuthSendCodePayload(email, purpose)).unwrap() },
            mock = {
                // 对齐 Web 端 sendCode 的 mock setTimeout(800ms)
                delay(MOCK_SEND_CODE_DELAY_MS)
                mapOf("sent" to true)
            },
        )
    }

    /** 邮箱注册（成功后写 token）。 */
    public suspend fun register(payload: AuthRegisterPayload): AuthLoginResult =
        dispatchByMode(
            mode = modeProvider(),
            live = { api.register(payload).unwrap().also(::persistToken) },
            mock = { mockSession(email = payload.email, nickname = "Porten 新成员") },
        )

    /** 邮箱 + 密码登录（成功后写 token）。 */
    public suspend fun loginPassword(payload: AuthLoginPasswordPayload): AuthLoginResult =
        dispatchByMode(
            mode = modeProvider(),
            live = { api.loginPassword(payload).unwrap().also(::persistToken) },
            mock = { mockSession(email = payload.email, nickname = "Porten 用户") },
        )

    /** 邮箱 + 验证码登录（成功后写 token）。 */
    public suspend fun loginEmailCode(payload: AuthLoginCodePayload): AuthLoginResult =
        dispatchByMode(
            mode = modeProvider(),
            live = { api.loginEmailCode(payload).unwrap().also(::persistToken) },
            mock = { mockSession(email = payload.email, nickname = "Porten 用户") },
        )

    /**
     * 登出：先以当前 token 通知服务端解绑，再清本地 token。
     *
     * 防御：服务端失败（如 token 已过期）不清空本地会话的语义不成立——
     * 登出是用户显式意图，本地 token 必须清除，服务端错误只记录不阻断。
     */
    public suspend fun logout(deviceId: String? = null) {
        val mode = modeProvider()
        if (mode == DataSourceMode.Live) {
            runCatching { api.logout(AuthLogoutPayload(deviceId)).unwrap() }
                .onFailure { AppLogger.w(TAG, "logout: 服务端登出失败（仍清除本地 token）: ${it.message}") }
        }
        secureStore.remove(PortenDataContainer.TOKEN_KEY)
        AppLogger.i(TAG, "logout: 本地 token 已清除 mode=$mode")
    }

    /** 当前 token（启动时恢复登录态用；无token返回 null）。 */
    public fun currentToken(): String? = secureStore.getString(PortenDataContainer.TOKEN_KEY)

    /** 登录成功落盘 token（唯一写入方）。 */
    private fun persistToken(result: AuthLoginResult) {
        secureStore.putString(PortenDataContainer.TOKEN_KEY, result.token.accessToken)
        AppLogger.i(TAG, "登录成功，token 已写入安全存储 userId=${result.user.id}")
    }

    /** Mock 假会话（与 Flutter 侧 loginMock 语义对齐：任意合法凭证放行）。 */
    private fun mockSession(email: String, nickname: String): AuthLoginResult = AuthLoginResult(
        token = AuthTokenInfo(
            accessToken = "mock-token-${email.hashCode().toUInt()}",
            tokenType = "bearer",
            expiresIn = MOCK_TOKEN_EXPIRES_SECONDS,
        ),
        user = AuthUserBrief(
            id = email.hashCode().let { if (it == Int.MIN_VALUE) 0 else it },
            email = email,
            portenId = "MOCK${email.hashCode().toUInt()}",
            nickname = nickname,
        ),
    )

    private companion object {
        private const val TAG: String = "AuthRepository"
        private const val MOCK_SEND_CODE_DELAY_MS: Long = 800L
        private const val MOCK_TOKEN_EXPIRES_SECONDS: Int = 7 * 24 * 3600
    }
}
