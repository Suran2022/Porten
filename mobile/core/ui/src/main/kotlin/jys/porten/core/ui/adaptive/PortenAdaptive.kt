package jys.porten.core.ui.adaptive

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import jys.porten.core.design.tokens.PortenScaling

/**
 * 屏幕适配策略。
 *
 * 策略：**以屏幕宽度为主导的等比缩放**（width-first）。
 * React Web 端是流式布局，本不存在「设计稿」概念；而 App 窗口宽度随设备差异巨大，
 * 要达成「视觉版式不变、整体等比适配」的目标，必须固定一个基准宽度做换算。
 *
 * 实现方式是通过替换 [LocalDensity]，让全树的 dp / sp 自动按比例换算，
 * 业务代码照常写设计稿数值即可，**不感知缩放的存在**。
 */
@Immutable
public data class PortenAdaptiveStrategy(
    /** 最终生效的缩放系数（已做上下限约束）。 */
    val scaleFactor: Float,
    /** 文本缩放系数：默认恒为 1，文字保持 sp 语义，避免长文本换行崩坏。 */
    val fontScaleFactor: Float,
    /** 当前屏幕宽度（dp）。 */
    val screenWidthDp: Int,
    /** 当前屏幕最小边长（dp），用于判断平板/折叠屏等大屏形态。 */
    val smallestWidthDp: Int,
) {

    /** 是否为大屏形态（平板 / 展开态折叠屏），用于切换分栏布局。 */
    public val isExpandedWindow: Boolean get() = smallestWidthDp >= SMALL_SCREEN_WIDTH_THRESHOLD

    public companion object {
        /** 大屏判定阈值（dp）：600dp 是业界通用断点。 */
        public const val SMALL_SCREEN_WIDTH_THRESHOLD: Int = 600
    }
}

/**
 * 依据当前配置计算适配策略。
 */
@Composable
public fun rememberPortenAdaptiveStrategy(): PortenAdaptiveStrategy {
    val configuration: Configuration = LocalConfiguration.current
    val scale = PortenScaling.scaleFor(configuration.screenWidthDp.toFloat())
    val fontScale = if (PortenScaling.ScaleText) scale else 1f
    return PortenAdaptiveStrategy(
        scaleFactor = scale,
        fontScaleFactor = fontScale,
        screenWidthDp = configuration.screenWidthDp,
        smallestWidthDp = configuration.smallestScreenWidthDp,
    )
}

/**
 * 生成应用了缩放后的 Density。
 *
 * @param base 系统原始 Density（携带用户设置的系统字体缩放）。
 * @param strategy 适配策略。
 */
public fun scaledDensity(base: Density, strategy: PortenAdaptiveStrategy): Density = Density(
    density = base.density * strategy.scaleFactor,
    fontScale = (base.fontScale * strategy.fontScaleFactor).coerceAtMost(PortenScaling.FontScaleMax),
)
