/*
 * 推送统一收件柜。
 *
 * 架构约束（原生承载核心能力第 3 条）：
 *   - 厂商通道（FCM / 小米 / 华为等）各自注册自己的 Provider，本模块统一收口；
 *   - 推送到达后的分发顺序：本地通知展示（可选）→ 事件总线 → 经桥接转发 Flutter 渲染；
 *   - 隐私约束：推送内容不落明文日志；崩溃恢复后不重放已过期的营销类推送。
 */

package jys.porten.core.push

import jys.porten.core.common.log.AppLogger
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/** 统一推送消息模型（跨厂商归一化后的载荷）。 */
public class PushMessage(
    /** 厂商通道标识，如 fcm / xiaomi / huawei。 */
    public val channel: String,

    /** 消息类型（会话消息 / 系统公告 / 静默指令）。 */
    public val type: String,

    /** 业务 JSON 载荷。 */
    public val payloadJson: String,

    /** 到达时间戳（毫秒）。 */
    public val receivedAtMs: Long = System.currentTimeMillis(),
)

/** 推送通道提供者契约：各厂商 SDK 的接入实现。 */
public interface PushProvider {
    /** 通道名。 */
    public val channel: String

    /** 初始化 SDK（在启动编排中调用，必须幂等）。 */
    public fun initialize(context: android.content.Context)

    /** 当前设备在该通道的注册 token（未就绪返回 null）。 */
    public fun token(): String?
}

/** 推送收件柜（单例）：所有 Provider 的消息都投递到这里。 */
public object PushInbox {

    private const val TAG: String = "PushInbox"

    private val providers: MutableMap<String, PushProvider> = linkedMapOf()

    private val _messages = MutableSharedFlow<PushMessage>(extraBufferCapacity = 128)

    /** 推送消息流（桥接层订阅并转发 Flutter）。 */
    public val messages: SharedFlow<PushMessage> = _messages.asSharedFlow()

    /** 注册厂商通道；重复注册同一通道视为配置错误，立即抛出。 */
    public fun register(provider: PushProvider) {
        check(provider.channel !in providers) { "推送通道重复注册：${provider.channel}" }
        providers[provider.channel] = provider
    }

    /** 初始化全部已注册通道（防御：单个通道失败不影响其他通道）。 */
    public fun initializeAll(context: android.content.Context) {
        providers.values.forEach { provider ->
            runCatching { provider.initialize(context) }
                .onFailure { AppLogger.e(TAG, "通道 ${provider.channel} 初始化失败: ${it.message}") }
        }
    }

    /** 由各 Provider 回调：投递一条归一化消息。 */
    public fun dispatch(message: PushMessage) {
        runCatching { _messages.tryEmit(message) }
            .onFailure { AppLogger.w(TAG, "推送投递失败 type=${message.type}") }
    }
}
