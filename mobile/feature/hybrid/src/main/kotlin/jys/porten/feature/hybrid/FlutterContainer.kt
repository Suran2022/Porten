/*
 * Flutter 容器（:feature:hybrid 提供给宿主的唯一 Flutter 装载 Composable）。
 *
 * 职责：
 *   1. 从 FlutterEngineCache 取预热引擎（未预热则就地重试 warmUp，防御性兜底）；
 *   2. 用 Compose AndroidView 承载 FlutterView，并把缓存引擎 attach 上去
 *      （Add-to-App 官方推荐：单引擎 + 手动 attach，避免多引擎内存翻倍）；
 *   3. 【关键】手动转发 Activity 生命周期到引擎——缓存引擎模式不会自动
 *      绑定生命周期，缺失会导致引擎停在 detached 状态：动画帧不调度、
 *      交互异常（官方文档明确要求 self-forward lifecycle events）。
 *
 * 引擎生命周期归 FlutterHost 管，本容器只做 attach/detach，不 destroy。
 */

package jys.porten.feature.hybrid

import android.content.Context
import androidx.activity.OnBackPressedCallback
import androidx.activity.OnBackPressedDispatcherOwner
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import jys.porten.core.bridge.PortenChannels
import jys.porten.core.common.log.AppLogger

/** 呈现 Flutter 内容（当前为认证流程页），引擎未就绪时呈现空白并重试预热。 */
@Composable
public fun FlutterContainer(modifier: Modifier = Modifier) {
    val context: Context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // remember：组合期解析引擎一次；warmUp 幂等，缓存未命中时会就地预热
    val engine: FlutterEngine? = remember {
        FlutterHost.cachedEngine() ?: FlutterHost.warmUp(context)
    }

    // 生命周期转发：缓存引擎必须显式接收 resume/pause/stop 事件，
    // 否则 Flutter 侧 WidgetsBinding 一直认为应用在后台（帧调度停摆）。
    DisposableEffect(engine) {
        if (engine == null) {
            AppLogger.e("FlutterContainer", "引擎未就绪，Flutter 内容将呈现空白")
            return@DisposableEffect onDispose { }
        }

        val observer = LifecycleEventObserver { _, event ->
            runCatching {
                when (event) {
                    Lifecycle.Event.ON_RESUME -> engine.lifecycleChannel.appIsResumed()
                    Lifecycle.Event.ON_PAUSE -> engine.lifecycleChannel.appIsInactive()
                    Lifecycle.Event.ON_STOP -> engine.lifecycleChannel.appIsPaused()
                    Lifecycle.Event.ON_DESTROY -> engine.lifecycleChannel.appIsDetached()
                    else -> Unit
                }
            }.onFailure {
                AppLogger.e("FlutterContainer", "生命周期转发失败: ${it.message}")
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        // attach 即视为前台（组合发生时 Activity 必然处于 resumed 前后）
        runCatching { engine.lifecycleChannel.appIsResumed() }
        AppLogger.i("FlutterContainer", "Flutter 引擎生命周期通道已接通")

        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { viewContext ->
            FlutterView(viewContext).apply {
                engine?.let {
                    attachToFlutterEngine(it)
                    AppLogger.i("FlutterContainer", "FlutterView 已挂载缓存引擎")
                } ?: AppLogger.e(
                    "FlutterContainer",
                    "引擎未就绪，FlutterView 挂载失败（将呈现空白）",
                )
            }
        },
    )

    // 系统返回键转发（r20）：缓存引擎 + 手动 attach 的 FlutterView 没有
    // FlutterActivity/FlutterFragment 的背书，系统返回默认走 Activity.finish()
    // 直接退出应用。此处注册 OnBackPressedCallback：先经导航桥询问 Dart 侧
    // canPop——可弹则向引擎发 popRoute（Flutter 内 pop 一级），不可弹（已在根）
    // 才 finish() 退出，与官方 FlutterActivity 行为语义一致。
    val backDispatcherOwner = LocalOnBackPressedDispatcherOwner.current
    DisposableEffect(engine, backDispatcherOwner) {
        if (engine == null || backDispatcherOwner == null) {
            return@DisposableEffect onDispose { }
        }
        val dispatcher = backDispatcherOwner.onBackPressedDispatcher
        val callback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                runCatching {
                    MethodChannel(
                        engine.dartExecutor.binaryMessenger,
                        PortenChannels.NAVIGATION,
                    ).invokeMethod(
                        "canPop",
                        null,
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                if (result == true) {
                                    engine.navigationChannel.popRoute()
                                } else {
                                    backDispatcherOwner.finishActivitySafely()
                                }
                            }

                            override fun error(
                                errorCode: String,
                                errorMessage: String?,
                                errorDetails: Any?,
                            ) {
                                AppLogger.e(
                                    "FlutterContainer",
                                    "canPop 通道错误: $errorCode $errorMessage",
                                )
                                backDispatcherOwner.finishActivitySafely()
                            }

                            override fun notImplemented() {
                                backDispatcherOwner.finishActivitySafely()
                            }
                        },
                    )
                }.onFailure {
                    AppLogger.e("FlutterContainer", "返回键转发失败: ${it.message}")
                    // 通道异常兜底：维持可退出，不困死用户
                    backDispatcherOwner.finishActivitySafely()
                }
            }
        }
        dispatcher.addCallback(backDispatcherOwner, callback)
        onDispose { callback.remove() }
    }
}

/** Activity 安全收尾（测试/非 Activity 宿主防御）。 */
private fun OnBackPressedDispatcherOwner.finishActivitySafely() {
    (this as? android.app.Activity)?.finish()
}
