/*
 * Flutter 引擎适配层：把 core:bridge 的通道契约绑定到真实 FlutterEngine。
 *
 * 本模块是全工程唯一允许依赖 Flutter SDK 的原生模块（依赖倒置的落地边界）。
 * 职责：
 *   1. 缓存引擎预热（Add-to-App 最佳实践：冷启动时预创建引擎，进入 Flutter 页面零等待）；
 *   2. 把 env / secure_store 等通道的 MethodCallHandler 装配到引擎上；
 *   3. 防御性约定：所有 MethodCallHandler 必须 try/catch，原生异常只以 code/message 回传。
 */

package jys.porten.feature.hybrid

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import jys.porten.core.bridge.PortenBridgeRegistry
import jys.porten.core.bridge.PortenChannels
import jys.porten.core.common.log.AppLogger
import jys.porten.core.data.DataSourceMode

/** Flutter 引擎容器与通道适配器。 */
public object FlutterHost {

    private const val TAG: String = "FlutterHost"

    /** 缓存引擎的固定 ID（Add-to-App 官方推荐模式）。 */
    private const val ENGINE_ID: String = "porten_engine"

    /** 当前 Mock 模式（由 app 层注入，桥接 env 通道读取）。 */
    @Volatile
    public var dataSourceMode: DataSourceMode = DataSourceMode.Mock

    /**
     * 预热引擎并注册通道（幂等）。
     *
     * @param dartEntrypoint Flutter 入口函数名（默认 main；混合场景用 bootstrap）。
     */
    public fun warmUp(
        context: Context,
        dartEntrypoint: String = "bootstrap",
    ): FlutterEngine? = runCatching {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }

        val engine = FlutterEngine(context.applicationContext)
        // createDefault 使用默认 main 入口；自定义入口（如 bootstrap）需在
        // AndroidManifest 的 io.flutter.Entrypoint 元数据中声明后再切换
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        registerChannels(engine)
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        AppLogger.i(TAG, "Flutter 引擎预热完成 entrypoint=$dartEntrypoint")
        engine
    }.getOrElse { error ->
        // 防御：引擎预热失败不崩溃，Flutter 页面进入时再重试
        AppLogger.e(TAG, "Flutter 引擎预热失败: ${error.message}")
        null
    }

    /** 取缓存引擎（未预热返回 null）。 */
    public fun cachedEngine(): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ENGINE_ID)

    /** 释放引擎（仅登出/测试场景）。 */
    public fun destroy() {
        cachedEngine()?.destroy()
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }

    /** 把原生能力按通道装配到引擎。 */
    private fun registerChannels(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger

        // ---- env 通道：环境与配置注入 ----
        io.flutter.plugin.common.MethodChannel(messenger, PortenChannels.ENV)
            .setMethodCallHandler { call, result ->
                runCatching {
                    when (call.method) {
                        "mockMode" -> result.success(
                            if (dataSourceMode == DataSourceMode.Live) "live" else "mock",
                        )
                        else -> result.notImplemented()
                    }
                }.onFailure { result.error("native_error", it.message, null) }
            }

        // 其余域（im / push / secure_store）的处理器由各自 core 模块提供，
        // Phase 2 在此逐域接入 PortenBridgeRegistry.all() 的注册清单。
        AppLogger.d(TAG, "已注册通道：env；待接入：${PortenBridgeRegistry.all().keys}")
    }
}
