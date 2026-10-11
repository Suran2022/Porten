package jys.porten.feature.launcher

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import jys.porten.core.design.tokens.PortenMotion

/**
 * 启动阶段状态机。
 *
 * 状态：
 *   - [LauncherState.Splash]：开屏，停留 3 秒且不允许跳过（与 Web 端 SplashScreen 行为一致）；
 *   - [LauncherState.Ready]：开屏结束，交接到下一层（主容器 / 登录引导）。
 *
 * 说明：当前骨架阶段完成到 Ready 为止；后续接入登录态判定后，
 *       只需在此处增加分支，不在 UI 层写任何业务判断。
 */
public sealed interface LauncherState {

    /** 开屏中。 */
    public data object Splash : LauncherState

    /** 开屏结束，可以进入业务 UI。 */
    public data object Ready : LauncherState
}

public class LauncherViewModel : ViewModel() {

    private val _state: MutableStateFlow<LauncherState> = MutableStateFlow(LauncherState.Splash)
    val state: StateFlow<LauncherState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            delay(SPLASH_DURATION_MS)
            _state.value = LauncherState.Ready
        }
    }

    private companion object {
        /**
         * 原生侧仅承担「系统启动画面 → Flutter 首帧」的过渡缓冲（400ms）。
         * 完整的 3s 开屏（图标 + 流光 Logo + 服务声明）由 Flutter 侧统一承担，
         * 原生再停留 3s 会造成双重开屏。
         */
        const val SPLASH_DURATION_MS: Long = 400L
        /** 预留：与 Web 端一致的淡出时长，供后续转场动画使用。 */
        const val FADE_DURATION_MS: Int = PortenMotion.SplashExitMs
    }
}
