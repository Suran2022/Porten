package jys.porten.core.design.tokens

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * Porten 渐变令牌。
 *
 * 角度语义沿用 Web 端 CSS linear-gradient：0deg = 自下而上，90deg = 自左向右，135deg = 左上到右下。
 * 每个渐变都携带 Web 端定义的流光动画时长，UI 层据此实现沿渐变方向的背景位移，还原「流动」观感。
 *
 * 使用：
 * ```kotlin
 * Box(modifier = Modifier.background(PortenGradient.BrandSurface.createBrush(widthPx, heightPx)))
 * ```
 */
public object PortenGradient {

    /** 渐变端点比例：取值均为 0~1 的容器宽高比例。 */
    private val LEFT_TO_RIGHT_END: OffsetRatio = OffsetRatio(x = 1f, y = 0f)
    private val LEFT_TOP_TO_RIGHT_BOTTOM_END: OffsetRatio = OffsetRatio(x = 1f, y = 1f)

    /**
     * 品牌文字渐变（Web 端 .porten-gradient）：
     * 蓝 → 粉 → 白 → 粉 → 蓝，50% 处为白色高光，16s 匀速流动。
     */
    public val BrandText: Spec = Spec(
        stops = listOf(
            0.0f to PortenColor.BrandBlue,
            0.3f to PortenColor.BrandPink,
            0.5f to PortenColor.BrandWhite,
            0.7f to PortenColor.BrandPink,
            1.0f to PortenColor.BrandBlue,
        ),
        start = OffsetRatio.ZERO,
        end = LEFT_TO_RIGHT_END,
        flowDurationMs = 16_000L,
    )

    /**
     * 品牌面渐变（Web 端 .porten-bg-gradient）：蓝 → 粉 → 蓝，8s 往复流动。
     */
    public val BrandSurface: Spec = Spec(
        stops = listOf(
            0.0f to PortenColor.BrandBlue,
            0.5f to PortenColor.BrandPink,
            1.0f to PortenColor.BrandBlue,
        ),
        start = OffsetRatio.ZERO,
        end = LEFT_TO_RIGHT_END,
        flowDurationMs = 8_000L,
    )

    /**
     * 约定页渐变（Web 端 .agreement-gradient）：135° 蓝 → 粉 → 蓝，3s 往复。
     */
    public val AgreementSurface: Spec = Spec(
        stops = listOf(
            0.0f to PortenColor.BrandBlue,
            0.5f to PortenColor.BrandPink,
            1.0f to PortenColor.BrandBlue,
        ),
        start = OffsetRatio.ZERO,
        end = LEFT_TOP_TO_RIGHT_BOTTOM_END,
        flowDurationMs = 3_000L,
    )

    /**
     * 渐隐分隔线（Web 端 .fade-divider）：两端透明、中间加深，用于列表分隔。
     */
    public val FadeDivider: Spec = Spec(
        stops = listOf(
            0.0f to PortenColor.Gray300.copy(alpha = PortenColor.DividerEdgeAlpha),
            0.2f to PortenColor.Gray300.copy(alpha = PortenColor.DividerEdgeAlpha),
            0.5f to PortenColor.Gray400.copy(alpha = PortenColor.DividerCoreAlpha),
            0.8f to PortenColor.Gray300.copy(alpha = PortenColor.DividerEdgeAlpha),
            1.0f to PortenColor.Gray300.copy(alpha = PortenColor.DividerEdgeAlpha),
        ),
        start = OffsetRatio.ZERO,
        end = LEFT_TO_RIGHT_END,
        flowDurationMs = null,
    )

    /** 渐变规范。 */
    public class Spec internal constructor(
        public val stops: List<Pair<Float, Color>>,
        public val start: OffsetRatio,
        public val end: OffsetRatio,
        public val flowDurationMs: Long?,
    ) {

        /**
         * 按给定像素尺寸创建 Brush。
         *
         * @param widthPx 容器宽度（像素），用于把比例端点换算为 Compose 的坐标。
         * @param heightPx 容器高度（像素）。
         */
        public fun createBrush(widthPx: Float, heightPx: Float): Brush = Brush.linearGradient(
            colorStops = stops.toTypedArray(),
            start = Offset(x = start.x * widthPx, y = start.y * heightPx),
            end = Offset(x = end.x * widthPx, y = end.y * heightPx),
        )

        /** 是否启用流光动画。 */
        public val animated: Boolean get() = flowDurationMs != null
    }

    /** 渐变端点比例值。 */
    public data class OffsetRatio(val x: Float, val y: Float) {
        public companion object {
            public val ZERO: OffsetRatio = OffsetRatio(x = 0f, y = 0f)
        }
    }
}
