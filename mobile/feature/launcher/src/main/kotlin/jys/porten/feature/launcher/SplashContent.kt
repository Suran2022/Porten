package jys.porten.feature.launcher

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import jys.porten.core.design.tokens.PortenColor
import jys.porten.core.design.tokens.PortenDimens
import jys.porten.core.design.tokens.PortenTypography
import jys.porten.core.ui.components.PortenGradientLogo

/**
 * 开屏页 —— 与 React Web 端 components/SplashScreen.tsx 逐项对齐。
 *
 * 还原要点：
 *   - 白底铺满，全屏不响应点击、不允许跳过；
 *   - 中央航班图标 96dp（Web 端 w-24），整体上移 40dp（Web 端 -translate-y-10）以保持视觉重心；
 *   - 底部：品牌渐变 Logo + 「静夜思云提供计算服务」，距底 28dp（Web 端 bottom-7）。
 */
@Composable
internal fun SplashContent(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(bottom = PortenDimens.Space2XL),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(id = jys.porten.core.ui.R.drawable.ic_splash_logo),
            contentDescription = null,
            modifier = Modifier
                .size(SPLASH_ICON_SIZE)
                // 对齐 Web 端 -translate-y-10（40px）
                .offset(y = -SPLASH_ICON_OFFSET_Y),
        )

        Column(
            modifier = Modifier.align(Alignment.BottomCenter),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(PortenDimens.SpaceSM),
        ) {
            PortenGradientLogo(text = "Porten")
            Spacer(modifier = Modifier.height(PortenDimens.SpaceXXS))
            Text(
                text = stringResource(id = R.string.porten_common_splash_caption),
                style = PortenTypography.XS,
                color = PortenColor.TextSecondary,
            )
        }
    }
}

/** Web 端内的 w-24 = 96px。 */
private val SPLASH_ICON_SIZE = 96.dp

/** Web 端内的 -translate-y-10 = -40px。 */
private val SPLASH_ICON_OFFSET_Y = 40.dp

/** 占位用前景色常量（骨架阶段 UI 尚未铺开，避免魔法数字散落）。 */
internal val SkeletonForeground: Color = PortenColor.TextPrimary
