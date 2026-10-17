/*
 * 认证业务模型（与后端 /api/v1/auth 系列接口 JSON 严格一致）。
 *
 * 规范约束（同 PortenModels.kt）：
 *   1. 纯 Kotlin，禁止依赖 Android / UI 类型；
 *   2. kotlinx.serialization + @SerialName 显式标注 snake_case，禁止运行时猜测；
 *   3. 字段与后端 app/schemas/auth.py 一个不多一个不少。
 */

package jys.porten.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 发送验证码载荷（对齐 SendVerificationCodeRequest）。 */
@Serializable
public data class AuthSendCodePayload(
    val email: String,
    /** 用途：register / login / reset_password */
    val purpose: String,
)

/** 注册载荷（对齐 RegisterRequest）。 */
@Serializable
public data class AuthRegisterPayload(
    val email: String,
    val password: String,
    @SerialName("confirm_password") public val confirmPassword: String,
    @SerialName("verification_code") public val verificationCode: String,
    @SerialName("device_id") public val deviceId: String? = null,
    @SerialName("device_name") public val deviceName: String? = null,
    /** 平台标识：ios / android / web / desktop */
    val platform: String? = null,
)

/** 邮箱 + 密码登录载荷（对齐 EmailPasswordLoginRequest）。 */
@Serializable
public data class AuthLoginPasswordPayload(
    val email: String,
    val password: String,
    @SerialName("device_id") public val deviceId: String? = null,
    @SerialName("device_name") public val deviceName: String? = null,
    val platform: String? = null,
)

/** 邮箱 + 验证码登录载荷（对齐 EmailCodeLoginRequest）。 */
@Serializable
public data class AuthLoginCodePayload(
    val email: String,
    @SerialName("verification_code") public val verificationCode: String,
    @SerialName("device_id") public val deviceId: String? = null,
    @SerialName("device_name") public val deviceName: String? = null,
    val platform: String? = null,
)

/** 登出载荷（对齐 LogoutRequest；token 经 Authorization 头承载，本载荷仅解绑设备）。 */
@Serializable
public data class AuthLogoutPayload(
    @SerialName("device_id") public val deviceId: String? = null,
)

/** 登录令牌（对齐 TokenResponse）。 */
@Serializable
public data class AuthTokenInfo(
    @SerialName("access_token") public val accessToken: String,
    @SerialName("token_type") public val tokenType: String = "bearer",
    @SerialName("expires_in") public val expiresIn: Int = 0,
)

/** 登录用户简报（对齐 UserBriefResponse）。 */
@Serializable
public data class AuthUserBrief(
    val id: Int,
    val email: String,
    @SerialName("porten_id") public val portenId: String,
    val nickname: String,
    @SerialName("avatar_url") public val avatarUrl: String? = null,
    @SerialName("background_url") public val backgroundUrl: String? = null,
    val role: String = "user",
)

/** 登录结果（对齐 LoginResponse：令牌 + 用户简报）。 */
@Serializable
public data class AuthLoginResult(
    val token: AuthTokenInfo,
    val user: AuthUserBrief,
)
