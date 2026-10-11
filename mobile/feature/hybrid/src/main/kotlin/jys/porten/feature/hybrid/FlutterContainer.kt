/*
 * Flutter 容器（:feature:hybrid 提供给宿主的唯一 Flutter 装载 Composable）。
 *
 * 职责：
 *   1. 从 FlutterEngineCache 取预热引擎（未预热则就地重试 warmUp，防御性兜底）；
 *   2. 用 Compose AndroidView 承载 FlutterView，并把缓存引擎 attach 上去
 *      （Add-to-App 官方推荐：单引擎 + 手动 attach，避免多引擎内存翻倍）。
 *
 * 引擎生命周期归 FlutterHost 管，本容器只做 attach/detach，不 destroy。
 */

package jys.porten.feature.hybrid

import android.content.Context
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import jys.porten.core.common.log.AppLogger

/** 呈现 Flutter 内容（当前为认证流程页），引擎未就绪时呈现空黑底并重试预热。 */
@Composable
public fun FlutterContainer(modifier: Modifier = Modifier) {
    val context: Context = LocalContext.current

    // remember：组合期解析引擎一次；warmUp 幂等，缓存未命中时会就地预热
    val engine: FlutterEngine? = remember {
        FlutterHost.cachedEngine() ?: FlutterHost.warmUp(context)
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
}
