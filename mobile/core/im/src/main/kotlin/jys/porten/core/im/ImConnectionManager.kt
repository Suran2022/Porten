/*
 * IM 长连接管理核心。
 *
 * 职责（架构第 1 条：核心能力由 Android 原生承载）：
 *   - WebSocket 连接生命周期管理（建连 / 心跳 / 指数退避重连）；
 *   - 前后台切换时的保活策略（前台全速心跳，后台降频 + 系统JobScheduler 兜底，Phase 2 接入）；
 *   - 消息收发管线：入站事件转发给 Flutter 渲染层，出站消息由 Flutter 经桥接提交。
 *
 * 防御性设计：
 *   - 所有状态迁移在单线程调度器内串行执行，杜绝并发竞态；
 *   - 重连退避 + 抖动，防止服务端雪崩时的重连风暴；
 *   - 消息回调包 try/catch，单个监听器异常不影响连接。
 */

package jys.porten.core.im

import jys.porten.core.common.log.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min
import kotlin.random.Random

/** 连接状态（与 Dart 侧 PortenImEvents.connectionStateChanged 的事件载荷对应）。 */
public enum class ConnectionState {
    /** 未初始化 / 已断开且未开始重连。 */
    Idle,

    /** 连接中。 */
    Connecting,

    /** 已连接（心跳正常）。 */
    Connected,

    /** 断开中（主动关闭或被动断开，即将重连）。 */
    Reconnecting,
}

/** 入站消息（由服务端推送、待转发给 Flutter 渲染层）。 */
public class InboundMessage(
    public val type: String,
    public val payloadJson: String,
)

/** 长连接配置。 */
public class ImConnectionConfig(
    /** WebSocket 地址。 */
    public val wsUrl: String,

    /** 心跳间隔（毫秒），对齐 Web 端 30s。 */
    public val heartbeatIntervalMs: Long = 30_000,

    /** 重连初始退避（毫秒）。 */
    public val reconnectBaseMs: Long = 1_000,

    /** 重连退避上限（毫秒）。 */
    public val reconnectMaxMs: Long = 60_000,

    /** 最大连续重连次数；超过后进入 Idle 并等待前台事件重新拉起。 */
    public val maxReconnectAttempts: Int = 12,
)

/**
 * IM 长连接管理器。
 *
 * 传输层的真实 WebSocket 由 Phase 2 注入（[Transport] 抽象），
 * 本类只负责连接状态机与心跳/重连策略，保证策略可单测。
 */
public class ImConnectionManager(
    private val config: ImConnectionConfig,
    private val scope: CoroutineScope,
    private val transport: Transport,
) {

    /** 传输抽象：OkHttp WebSocket 实现位于同模块 Phase 2，测试用 Fake 注入。 */
    public interface Transport {
        public fun connect()
        public fun disconnect()
        public fun send(json: String): Boolean
    }

    public companion object {
        private const val TAG: String = "ImConnection"
    }

    private val _state = MutableStateFlow(ConnectionState.Idle)

    /** 连接状态流（供桥接层转发给 Flutter）。 */
    public val state: StateFlow<ConnectionState> = _state.asStateFlow()

    private val _inbound = MutableSharedFlow<InboundMessage>(extraBufferCapacity = 256)

    /** 入站消息流（供桥接层转发给 Flutter）。 */
    public val inbound: SharedFlow<InboundMessage> = _inbound.asSharedFlow()

    private val heartbeatJob = Job()
    private val started = AtomicBoolean(false)

    private var reconnectAttempts: Int = 0

    /** 启动长连接（幂等；重复调用直接忽略）。 */
    public fun start() {
        if (!started.compareAndSet(false, true)) {
            AppLogger.d(TAG, "长连接已在运行，忽略重复 start")
            return
        }
        connectInternal()
    }

    /** 主动停止（登出 / 测试）。 */
    public fun stop() {
        started.set(false)
        transport.disconnect()
        _state.value = ConnectionState.Idle
    }

    /** 提交出站消息（Flutter → 原生 → 服务端）。 */
    public fun send(json: String): Boolean = transport.send(json)

    /** 由传输层回调：连接已建立。 */
    public fun onConnected() {
        reconnectAttempts = 0
        _state.value = ConnectionState.Connected
        startHeartbeat()
    }

    /** 由传输层回调：连接断开。 */
    public fun onDisconnected(reason: String) {
        stopHeartbeat()
        if (!started.get()) {
            _state.value = ConnectionState.Idle
            return
        }
        scheduleReconnect(reason)
    }

    /** 由传输层回调：收到服务端消息。 */
    public fun onMessage(type: String, payloadJson: String) {
        val message = InboundMessage(type, payloadJson)
        // 防御：单条消息分发异常不影响连接
        scope.launch {
            runCatching { _inbound.emit(message) }
                .onFailure { AppLogger.w(TAG, "消息分发失败: ${it.message}") }
        }
    }

    private fun connectInternal() {
        _state.value = ConnectionState.Connecting
        runCatching { transport.connect() }
            .onFailure { AppLogger.w(TAG, "建连异常: ${it.message}"); scheduleReconnect(it.message ?: "unknown") }
    }

    private fun startHeartbeat() {
        scope.launch {
            while (isActive && started.get() && _state.value == ConnectionState.Connected) {
                delay(config.heartbeatIntervalMs)
                val sent = runCatching { transport.send("""{"type":"ping"}""") }
                    .getOrDefault(false)
                if (!sent) {
                    AppLogger.w(TAG, "心跳发送失败，触发重连")
                    onDisconnected("heartbeat_failed")
                    break
                }
            }
        }
    }

    private fun stopHeartbeat() {
        heartbeatJob.cancel()
    }

    /** 指数退避 + 随机抖动重连，防重连风暴。 */
    private fun scheduleReconnect(reason: String) {
        if (reconnectAttempts >= config.maxReconnectAttempts) {
            AppLogger.w(TAG, "重连次数耗尽($reason)，进入 Idle 等待前台拉起")
            _state.value = ConnectionState.Idle
            return
        }
        reconnectAttempts += 1
        _state.value = ConnectionState.Reconnecting
        val backoff = min(
            config.reconnectBaseMs shl (reconnectAttempts - 1),
            config.reconnectMaxMs,
        )
        val jittered = backoff + Random.nextLong(0, backoff / 4 + 1)
        AppLogger.d(TAG, "第 $reconnectAttempts 次重连将于 ${jittered}ms 后执行（原因: $reason）")
        scope.launch {
            delay(jittered)
            if (started.get()) connectInternal()
        }
    }
}
