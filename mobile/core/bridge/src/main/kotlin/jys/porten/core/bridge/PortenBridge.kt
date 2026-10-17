/*
 * 原生 ↔ Flutter 桥接契约（Kotlin 侧 · 依赖倒置）。
 *
 * 与 Dart 侧 lib/core/bridge/porten_channels.dart 的通道名严格一一对应，
 * 任何一侧调整必须同步，避免运行期通道失配。
 *
 * 架构约束：本模块**不依赖 Flutter SDK**——FlutterEngine 等类型只出现在
 * :feature:hybrid（唯一允许依赖 :flutter 的模块），由适配器把本模块的
 * [PortenBridgeHandler] 绑定到真实引擎上，保证核心能力层与 Flutter 解耦。
 */

package jys.porten.core.bridge

/** 通道名常量（与 Dart 侧 PortenChannels 一致）。 */
public object PortenChannels {
    public const val IM: String = "porten/im"
    public const val PUSH: String = "porten/push"
    public const val SECURE_STORE: String = "porten/secure_store"
    public const val ENV: String = "porten/env"

    /** 导航桥：Add-to-App 系统返回键转发（r20）。 */
    public const val NAVIGATION: String = "porten/navigation"

    /**
     * 业务数据桥：Flutter 经本通道读取 / 提交业务数据（日程、旅程、笔记）。
     *
     * 架构约束（混合开发核心）：Flutter 禁止直接访问网络，业务数据一律经
     * 本通道下沉到 :core:data 的 Repository（Mock / Live 双通道由原生决策），
     * 与官方 Add-to-App「核心能力在原生、表现层在 Flutter」的分工一致。
     */
    public const val DATA: String = "porten/data"
}

/**
 * 业务数据桥方法名（与 Dart 侧 PortenDataMethods 严格一致）。
 *
 * 命名规范：动词 + 领域名词（listSchedules / createSchedule / ...），
 * 请求参数与返回值均为 JSON Map，由各端 Model 的序列化约定承载。
 */
public object PortenDataMethods {
    // ---- 认证（登录 / 注册 / 验证码 / 登出）----
    public const val AUTH_SEND_CODE: String = "authSendCode"
    public const val AUTH_REGISTER: String = "authRegister"
    public const val AUTH_LOGIN_PASSWORD: String = "authLoginPassword"
    public const val AUTH_LOGIN_EMAIL_CODE: String = "authLoginEmailCode"
    public const val AUTH_LOGOUT: String = "authLogout"

    // ---- 我的日程 ----
    public const val LIST_SCHEDULES: String = "listSchedules"
    public const val CREATE_SCHEDULE: String = "createSchedule"
    public const val UPDATE_SCHEDULE: String = "updateSchedule"

    // ---- 我的旅程 ----
    public const val LIST_TRIPS: String = "listTrips"
    public const val CREATE_TRIP: String = "createTrip"

    // ---- 记笔记 ----
    public const val LIST_NOTES: String = "listNotes"
    public const val CREATE_NOTE: String = "createNote"
    public const val UPDATE_NOTE: String = "updateNote"
    public const val DELETE_NOTE: String = "deleteNote"
}

/** 业务数据桥参数键（与 Dart 侧 PortenDataArgs 严格一致）。 */
public object PortenDataArgs {
    /** 日程 / 笔记更新时的条目 id。 */
    public const val ID: String = "id"

    /** 创建 / 更新载荷（JSON Map，字段与各端 Model 一致）。 */
    public const val PAYLOAD: String = "payload"
}

/** IM 桥事件类型（与 Dart 侧 PortenImEvents 一致）。 */
public object PortenImEvents {
    public const val CONNECTION_STATE_CHANGED: String = "connectionStateChanged"
    public const val MESSAGE_RECEIVED: String = "messageReceived"
    public const val MESSAGE_SENT: String = "messageSent"
    public const val MESSAGE_READ_RECEIPT: String = "messageReadReceipt"
}

/**
 * 桥接能力提供者契约：各核心模块实现此接口，声明自己要暴露的通道。
 *
 * 防御性约定：适配层（:feature:hybrid）在绑定 MethodCallHandler 时必须自行 try/catch，
 * 原生异常只允许以 code/message 形式回传，不允许让 Flutter 侧崩溃。
 */
public fun interface PortenBridgeHandler {
    /**
     * 本域需要绑定的通道名集合。
     * 通道的 MethodCallHandler / EventChannel 由 feature:hybrid 的适配器装配。
     */
    public fun channelNames(): Set<String>
}

/** 桥接注册中心：统一装配点，禁止业务代码散落地注册通道。 */
public object PortenBridgeRegistry {

    private val handlers: MutableMap<String, PortenBridgeHandler> = linkedMapOf()

    /** 注册一个域处理器；重复注册同一 key 视为编程错误，立即抛出（防静默覆盖）。 */
    public fun register(key: String, handler: PortenBridgeHandler) {
        check(key !in handlers) { "桥接处理器重复注册：$key" }
        handlers[key] = handler
    }

    /** 按注册顺序返回全部处理器（供 feature:hybrid 遍历绑定）。 */
    public fun all(): Map<String, PortenBridgeHandler> = handlers.toMap()

    /** 清空注册表（仅测试使用）。 */
    public fun clear() = handlers.clear()
}
