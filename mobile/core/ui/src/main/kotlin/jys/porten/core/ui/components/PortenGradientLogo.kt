package jys.porten.core.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import jys.porten.core.design.tokens.PortenColor
import jys.porten.core.design.tokens.PortenTypography

/**
 * Porten 品牌渐变文字 Logo（对齐 Web 端 components/GradientLogo.tsx）。
 *
 * 设计规范：
 *   - 渐变取 Web 端 .porten-gradient：蓝 0% → 粉 30% → 白 50% → 粉 70% → 蓝 100%；
 *   - 字重恒为 Bold，默认字号 text-3xl（30sp，对应 [PortenTypography.X3L]）。
 *
 * 关于流光动画：Web 端以 `background-size: 300%` + 16s 循环位移实现「流动」感。
 * 移动端实现依赖文本宽度测量（Brush 坐标是像素而非比例），将在 Phase 2 的
 * `PortenFlowGradientText` 中通过 drawWithCache + TextLayoutResult 落地，
 * 本组件先提供静态渐变，保证视觉色序与 Web 端一致。
 */
@Composable
public fun PortenGradientLogo(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = PortenTypography.X3L,
) {
    Text(
        text = text,
        modifier = modifier,
        style = style.copy(
            brush = PortenBrandTextBrush,
            fontWeight = FontWeight.Bold,
        ),
    )
}

/** 品牌文字渐变：与 Web 端 .porten-gradient 色序完全一致。 */
private val PortenBrandTextBrush: Brush = Brush.linearGradient(
    0.0f to PortenColor.BrandBlue,
    0.3f to PortenColor.BrandPink,
    0.5f to PortenColor.BrandWhite,
    0.7f to PortenColor.BrandPink,
    1.0f to PortenColor.BrandBlue,
)
