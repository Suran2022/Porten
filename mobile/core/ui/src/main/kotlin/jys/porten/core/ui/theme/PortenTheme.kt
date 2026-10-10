package jys.porten.core.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.NonRestartableComposable
import androidx.compose.ui.platform.LocalDensity
import jys.porten.core.design.tokens.PortenColor
import jys.porten.core.design.tokens.PortenInteraction
import jys.porten.core.design.tokens.PortenTypography
import jys.porten.core.ui.adaptive.PortenAdaptiveStrategy
import jys.porten.core.ui.adaptive.rememberPortenAdaptiveStrategy
import jys.porten.core.ui.adaptive.scaledDensity

/**
 * Porten 主题入口。
 *
 * 职责：
 *   1. 把设计令牌映射为 Material3 主题对象；
 *   2. 注入等比缩放后的 Density（实现「版式不变、整体适配」）；
 *   3. **全局关闭水波纹**——Web 端采用自定义按压态而非浏览器默认反馈，
 *      移动端必须保持完全一致，任何系统水波纹都属于视觉还原事故。
 *
 * 用法：
 * ```kotlin
 * PortenTheme {
 *     PortenNavHost()
 * }
 * ```
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
public fun PortenTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    adaptiveEnabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val strategy: PortenAdaptiveStrategy = rememberPortenAdaptiveStrategy()
    val baseDensity = LocalDensity.current
    val density = if (adaptiveEnabled) scaledDensity(baseDensity, strategy) else baseDensity

    CompositionLocalProvider(
        LocalDensity provides density,
        // null = 彻底禁用 Material 水波纹，与 Web 端「无默认点击反馈」保持一致
        LocalRippleConfiguration provides null,
    ) {
        MaterialTheme(
            colorScheme = if (darkTheme) PortenDarkColorScheme else PortenLightColorScheme,
            typography = PortenAppTypography,
            content = content,
        )
    }
}

/** 浅色主题配色（Porten 现阶段主投放形态）。 */
private val PortenLightColorScheme = lightColorScheme(
    primary = PortenColor.BrandBlue,
    onPrimary = PortenColor.White,
    secondary = PortenColor.BrandPink,
    onSecondary = PortenColor.White,
    background = PortenColor.Background,
    onBackground = PortenColor.TextPrimary,
    surface = PortenColor.Background,
    onSurface = PortenColor.TextPrimary,
    surfaceVariant = PortenColor.Surface,
    onSurfaceVariant = PortenColor.TextSecondary,
    surfaceContainerLowest = PortenColor.Wash50,
    outline = PortenColor.Divider,
    outlineVariant = PortenColor.Gray200,
    error = PortenColor.Error,
    onError = PortenColor.White,
    scrim = PortenColor.Black,
)

/** 深色主题配色：保持品牌色不动，中性面按 Material3 深色规范处理。 */
private val PortenDarkColorScheme = darkColorScheme(
    primary = PortenColor.BrandBlue,
    onPrimary = PortenColor.TextPrimary,
    secondary = PortenColor.BrandPink,
    onSecondary = PortenColor.TextPrimary,
    background = PortenColor.Gray900,
    onBackground = PortenColor.Gray100,
    surface = PortenColor.Gray800,
    onSurface = PortenColor.Gray100,
    surfaceVariant = PortenColor.Gray700,
    onSurfaceVariant = PortenColor.Gray300,
    surfaceContainerLowest = PortenColor.Gray800,
    outline = PortenColor.Gray600,
    outlineVariant = PortenColor.Gray700,
    error = PortenColor.ErrorSoft,
    onError = PortenColor.Gray900,
    scrim = PortenColor.Black,
)

/** Material3 排版规范：全部字段使用统一字阶，避免不同组件字体风格漂移。 */
private val PortenAppTypography = Typography(
    displayLarge = PortenTypography.X3L,
    displayMedium = PortenTypography.Big28,
    displaySmall = PortenTypography.X2L,
    headlineLarge = PortenTypography.Hero22,
    headlineMedium = PortenTypography.XL,
    headlineSmall = PortenTypography.LG,
    titleLarge = PortenTypography.Title17,
    titleMedium = PortenTypography.Base,
    titleSmall = PortenTypography.Body15,
    bodyLarge = PortenTypography.Base,
    bodyMedium = PortenTypography.SM,
    bodySmall = PortenTypography.XS,
    labelLarge = PortenTypography.SM,
    labelMedium = PortenTypography.XS,
    labelSmall = PortenTypography.Micro,
)

/** 按压反馈是否使用透明度而非缩放（部分场景如列表项只降透明度更自然）。 */
public val IsPortenPressReduced: Boolean
    @Composable @NonRestartableComposable
    get() = PortenInteraction.RippleEnabled.not()
