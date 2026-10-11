package jys.porten.feature.launcher

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import jys.porten.core.design.tokens.PortenColor

/**
 * 启动编排总入口（由 :app 的 MainActivity 装载）。
 *
 * 只做一件事：根据 [LauncherState] 决定当前呈现哪一层。
 * 每一层的具体实现拆分到独立文件（如 SplashContent.kt），避免单点膨胀。
 */
@Composable
public fun PortenLauncherHost(
    modifier: Modifier = Modifier,
    viewModel: LauncherViewModel = viewModel(),
    // 就绪后的承载内容：默认保留骨架占位（独立调试用），
    // 由 :app 注入 Flutter 容器，实现「开屏 → 登录界面」的交接。
    readyContent: @Composable () -> Unit = {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            SkeletonPlaceholder()
        }
    },
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(
        modifier = modifier.fillMaxSize(),
        color = PortenColor.Background,
    ) {
        when (state) {
            LauncherState.Splash -> SplashContent()
            LauncherState.Ready -> readyContent()
        }
    }
}
