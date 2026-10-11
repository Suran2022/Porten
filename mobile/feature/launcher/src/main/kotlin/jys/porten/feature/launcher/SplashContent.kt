package jys.porten.feature.launcher

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import jys.porten.core.design.tokens.PortenColor

/**
 * 原生过渡页 —— 纯白底，无任何内容。
 *
 * 双开屏治理：完整开屏（图标 + 流光 Logo + 服务声明，3s）由 Flutter 侧
 * SplashScreen 承担，原生只做「系统启动画面 → Flutter 首帧」的白底缓冲，
 * 不再重复渲染开屏内容（否则用户会看到两次开屏）。
 */
@Composable
internal fun SplashContent(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(PortenColor.Background),
    )
}
