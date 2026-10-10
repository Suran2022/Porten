package jys.porten.core.design.tokens

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Porten 字阶令牌。
 *
 * 取值来源：Web 端 Tailwind 字号（xs=12, sm=14, base=16, lg=18, xl=20, 2xl=24, 3xl=30），
 * 另补齐 Web 端内联使用过的 10 / 11 / 13 / 15 / 17 / 22 / 28。
 * 行高一律为字号的 1.5 倍（与 Web 端 `:root { line-height: 1.5 }` 一致）。
 *
 * 字体族：Web 端使用系统字体栈，移动端同样沿用系统默认，避免引入第三方字体的体积与合规成本。
 */
public object PortenTypography {

    /** 与 Web 端一致的基准行高倍数。 */
    private const val LINE_HEIGHT_RATIO: Float = 1.5f

    private val SystemFamily: FontFamily = FontFamily.Default

    public val Mini: TextStyle = style(size = 10, weight = FontWeight.Normal)
    public val Micro: TextStyle = style(size = 11, weight = FontWeight.Normal)
    public val XS: TextStyle = style(size = 12, weight = FontWeight.Normal)
    public val Body13: TextStyle = style(size = 13, weight = FontWeight.Normal)
    public val SM: TextStyle = style(size = 14, weight = FontWeight.Normal)
    public val Body15: TextStyle = style(size = 15, weight = FontWeight.Normal)
    public val Base: TextStyle = style(size = 16, weight = FontWeight.Normal)
    public val Title17: TextStyle = style(size = 17, weight = FontWeight.Medium)
    public val LG: TextStyle = style(size = 18, weight = FontWeight.Medium)
    public val XL: TextStyle = style(size = 20, weight = FontWeight.Medium)
    public val Hero22: TextStyle = style(size = 22, weight = FontWeight.SemiBold)
    public val X2L: TextStyle = style(size = 24, weight = FontWeight.SemiBold)
    public val Big28: TextStyle = style(size = 28, weight = FontWeight.SemiBold)
    public val X3L: TextStyle = style(size = 30, weight = FontWeight.SemiBold)

    private fun style(size: Int, weight: FontWeight): TextStyle = TextStyle(
        fontFamily = SystemFamily,
        fontWeight = weight,
        fontSize = size.sp,
        lineHeight = (size * LINE_HEIGHT_RATIO).sp,
    )
}
