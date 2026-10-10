/*
 * 跨层 / 跨端数据模型（纯 Kotlin，可被序列化后经桥接传输）。
 *
 * 规范约束：
 *   1. 本模块禁止依赖任何 Android / UI 类型 —— 保证 KMP 可迁移性与编译速度；
 *   2. 所有模型使用 kotlinx.serialization，字段名与 Web 端 API JSON 严格一致
 *      （snake_case 由 @SerialName 显式标注，禁止运行时猜测）；
 *   3. 面向敏感身份用户：模型只承载业务必需字段，禁止塞入可长期识别个体的冗余数据。
 */

package jys.porten.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 用户会话模型（对应 Web 端 Session）。 */
@Serializable
public data class Session(
    public val id: String,
    @SerialName("user_id") public val userId: String,
    /** 会话类型：私聊 / 群聊，具体枚举随业务域扩展。 */
    @SerialName("session_type") public val sessionType: String,
    @SerialName("updated_at") public val updatedAt: String,
    /** 可选冗余字段统一用 nullable，禁止默认空串伪造数据。 */
    @SerialName("last_message_preview") public val lastMessagePreview: String? = null,
)

/** IM 消息模型（对应 Web 端 Message，经桥接 JSON 往返于原生与 Flutter）。 */
@Serializable
public data class Message(
    public val id: String,
    @SerialName("session_id") public val sessionId: String,
    @SerialName("sender_id") public val senderId: String,
    /** 消息体类型：text / image / system 等。 */
    @SerialName("body_type") public val bodyType: String,
    /** 消息体内容（text 为文本，image 为资源 URI，由 bodyType 语义决定）。 */
    public val body: String,
    @SerialName("sent_at") public val sentAt: String,
    /** 客户端本地状态：sending / sent / failed，用于消息气泡的发送态渲染。 */
    @SerialName("local_status") public val localStatus: String = "sent",
)

/** 用户资料卡（对齐 Web 端最小化原则，仅展示字段）。 */
@Serializable
public data class UserProfile(
    public val id: String,
    public val nickname: String,
    public val avatar: String? = null,
    /** 个性化签名（Web 端个人页字段）。 */
    public val bio: String? = null,
)
