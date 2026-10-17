/*
 * 业务数据桥适配器：把 porten/data 通道的 MethodCall 分发到 :core:data 的 Repository。
 *
 * 职责边界：
 *   - 本类是 core:bridge 契约到真实仓储的绑定点（依赖倒置的落地）；
 *   - Flutter 禁止直连网络：业务数据只经本适配器下沉到 Repository
 *     （Mock / Live 由原生 DataSourceMode 决策，Flutter 无感知）；
 *   - 防御性约定：所有异常以 code/message 回传，绝不让 Flutter 侧崩溃。
 *
 * 传输约定：MethodCall.arguments 为 Dart 侧 JSON Map（已由 Dart 转为基础类型），
 * 本类递归转为 kotlinx JsonElement 后解码为各端 Model；返回值编码为
 * JsonElement 再转为基础类型树回传（MethodChannel 只承载基础类型）。
 */

package jys.porten.feature.hybrid

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import jys.porten.core.bridge.PortenChannels
import jys.porten.core.bridge.PortenDataArgs
import jys.porten.core.bridge.PortenDataMethods
import jys.porten.core.common.log.AppLogger
import jys.porten.core.data.PortenDataContainer
import jys.porten.core.model.AuthLoginCodePayload
import jys.porten.core.model.AuthLoginPasswordPayload
import jys.porten.core.model.AuthLogoutPayload
import jys.porten.core.model.AuthRegisterPayload
import jys.porten.core.model.AuthSendCodePayload
import jys.porten.core.model.NoteUpsertPayload
import jys.porten.core.model.ScheduleCreatePayload
import jys.porten.core.model.ScheduleUpdatePayload
import jys.porten.core.model.TripCreatePayload
import jys.porten.core.network.PortenApiException

/**
 * 数据桥适配器（由 FlutterHost 在引擎装配期创建并绑定）。
 *
 * @param scope 协程作用域（Repository 为挂起函数；建议 Application 级，禁止随页面销毁）。
 */
internal class DataBridgeAdapter(
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) {

    private val json: Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    /** 通道名（装配用）。 */
    public val channelName: String get() = PortenChannels.DATA

    /**
     * 处理一次 MethodCall，结果经 [reply] 异步回传。
     *
     * 防御：仓储未初始化 / 业务异常 / 未知方法均以错误码回传，不抛到桥对面。
     */
    public fun handle(
        method: String,
        arguments: Map<String, Any?>?,
        reply: (Result<Any?>) -> Unit,
    ) {
        AppLogger.d(TAG, "handle method=$method")
        scope.launch {
            reply(runCatching { dispatch(method, arguments) })
        }
    }

    private suspend fun dispatch(method: String, arguments: Map<String, Any?>?): Any? {
        val schedules = PortenDataContainer.scheduleRepository
        val trips = PortenDataContainer.tripRepository
        val notes = PortenDataContainer.noteRepository
        val auth = PortenDataContainer.authRepository
        return when (method) {
            // ---- 认证 ----
            PortenDataMethods.AUTH_SEND_CODE -> {
                auth.sendCode(
                    email = arguments.requireString("email"),
                    purpose = arguments.requireString("purpose"),
                )
                mapOf("sent" to true)
            }

            PortenDataMethods.AUTH_REGISTER -> {
                encode(
                    auth.register(
                        AuthRegisterPayload(
                            email = arguments.requireString("email"),
                            password = arguments.requireString("password"),
                            confirmPassword = arguments.requireString("confirmPassword"),
                            verificationCode = arguments.requireString("verificationCode"),
                        ),
                    ),
                )
            }

            PortenDataMethods.AUTH_LOGIN_PASSWORD -> {
                encode(
                    auth.loginPassword(
                        AuthLoginPasswordPayload(
                            email = arguments.requireString("email"),
                            password = arguments.requireString("password"),
                        ),
                    ),
                )
            }

            PortenDataMethods.AUTH_LOGIN_EMAIL_CODE -> {
                encode(
                    auth.loginEmailCode(
                        AuthLoginCodePayload(
                            email = arguments.requireString("email"),
                            verificationCode = arguments.requireString("verificationCode"),
                        ),
                    ),
                )
            }

            PortenDataMethods.AUTH_LOGOUT -> {
                auth.logout()
                mapOf("loggedOut" to true)
            }

            // ---- 我的日程 ----
            PortenDataMethods.LIST_SCHEDULES ->
                encode(schedules.fetch())

            PortenDataMethods.CREATE_SCHEDULE ->
                encode(schedules.create(arguments.requirePayload()))

            PortenDataMethods.UPDATE_SCHEDULE ->
                encode(schedules.update(arguments.requireId(), arguments.requirePayload()))

            // ---- 我的旅程 ----
            PortenDataMethods.LIST_TRIPS ->
                encode(trips.fetch())

            PortenDataMethods.CREATE_TRIP ->
                encode(trips.create(arguments.requirePayload()))

            // ---- 记笔记 ----
            PortenDataMethods.LIST_NOTES ->
                encode(notes.fetch())

            PortenDataMethods.CREATE_NOTE ->
                encode(notes.create(arguments.requirePayload()))

            PortenDataMethods.UPDATE_NOTE ->
                encode(notes.update(arguments.requireId(), arguments.requirePayload()))

            PortenDataMethods.DELETE_NOTE -> {
                notes.delete(arguments.requireId())
                mapOf("deleted" to true)
            }

            else -> throw PortenApiException(-1, "未知数据桥方法：$method")
        }
    }

    // ---------------------------------------------------------- 参数解析

    private inline fun <reified T : Any> Map<String, Any?>?.requirePayload(): T {
        val payload = this?.get(PortenDataArgs.PAYLOAD)
            ?: throw PortenApiException(-1, "缺少 ${PortenDataArgs.PAYLOAD} 参数")
        return json.decodeFromJsonElement(payload.toJsonElement())
    }

    private fun Map<String, Any?>?.requireId(): Long {
        val raw = this?.get(PortenDataArgs.ID)
            ?: throw PortenApiException(-1, "缺少 ${PortenDataArgs.ID} 参数")
        return when (raw) {
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull()
                ?: throw PortenApiException(-1, "${PortenDataArgs.ID} 非法：$raw")
            else -> throw PortenApiException(-1, "${PortenDataArgs.ID} 非法：$raw")
        }
    }

    /** 读取扁平字符串参数（认证桥使用；缺失即抛，不猜默认值）。 */
    private fun Map<String, Any?>?.requireString(key: String): String {
        val raw = this?.get(key)
            ?: throw PortenApiException(-1, "缺少 $key 参数")
        return raw as? String
            ?: throw PortenApiException(-1, "$key 参数类型非法（期望字符串）")
    }

    // ---------------------------------------------------------- 结果编码

    /** 可序列化对象 → MethodChannel 可承载的基础类型树。 */
    private inline fun <reified T : Any> encode(value: T): Any? =
        json.encodeToJsonElement(value).toPlain()

    private fun JsonElement.toPlain(): Any? = when (this) {
        is JsonObject -> mapValues { (_, value) -> value.toPlain() }
        is JsonArray -> map { it.toPlain() }
        is JsonPrimitive -> when {
            this is JsonNull -> null
            content == "true" -> true
            content == "false" -> false
            content.toLongOrNull() != null -> content.toLong()
            content.toDoubleOrNull() != null -> content.toDouble()
            else -> content
        }
    }

    /** MethodChannel 参数（Dart Map）→ kotlinx JsonElement。 */
    private fun Any?.toJsonElement(): JsonElement = when (this) {
        null -> JsonNull
        is Map<*, *> -> JsonObject(
            entries.associate { (key, value) -> key.toString() to value.toJsonElement() },
        )
        is List<*> -> JsonArray(map { it.toJsonElement() })
        is Boolean -> JsonPrimitive(this)
        is Int -> JsonPrimitive(this)
        is Long -> JsonPrimitive(this)
        is Double -> JsonPrimitive(this)
        is Float -> JsonPrimitive(this)
        is String -> JsonPrimitive(this)
        else -> JsonPrimitive(toString())
    }

    /** 仓储异常 → 桥接错误码（Flutter 侧 PortenBridgeException 承载）。 */
    public fun mapError(throwable: Throwable): Pair<String, String> = when (throwable) {
        is PortenApiException -> "api_${throwable.code}" to throwable.message
        is IllegalStateException -> "not_initialized" to (throwable.message ?: "数据层未初始化")
        else -> "native_error" to (throwable.message ?: "unknown")
    }

    private companion object {
        private const val TAG: String = "DataBridge"
    }
}
