package jys.porten.core.design.tokens

import androidx.compose.ui.graphics.Color

/**
 * Porten 颜色令牌（原生侧唯一出口）。
 *
 * 数据来源：design/tokens/porten_design_tokens_v1.json（与 Flutter 侧同名令牌一一对应）。
 * 取值来源：React Web 端 src/index.css 渐变定义 + Tailwind 默认色阶 + 组件内联色统计。
 *
 * 硬性规范：
 *   1. 业务代码禁止硬编码颜色，一律引用此处令牌；
 *   2. 新增令牌必须先在 JSON 中登记，再同步 Dart 侧，最后跑 scripts/verify_design_tokens.py 校验；
 *   3. 颜色值统一使用 ARGB packed 形式（0xFF + RGB），便于全局检索。
 */
public object PortenColor {

    // ----------------------------------------------------------------------------------
    // 品牌色：跨性别旗帜色系（Porten 的核心视觉资产，任何场合不得改写）
    // ----------------------------------------------------------------------------------
    public val BrandBlue: Color = Color(0xFF5BCEFA)
    public val BrandPink: Color = Color(0xFFF5A9B8)
    public val BrandWhite: Color = Color(0xFFFFFFFF)

    /** 品牌蓝按压态（Web 端用于按钮按下 / 激活态）。 */
    public val BrandBluePressed: Color = Color(0xFF3BB5E5)

    /** 品牌粉浅色（Web 端用于描边、弱填充）。 */
    public val BrandPinkLight: Color = Color(0xFFF7C5D0)

    // ----------------------------------------------------------------------------------
    // 中性灰阶：对齐 Tailwind gray-50 ~ gray-900
    // ----------------------------------------------------------------------------------
    public val Gray50: Color = Color(0xFFF9FAFB)
    public val Gray100: Color = Color(0xFFF3F4F6)
    public val Gray200: Color = Color(0xFFE5E7EB)
    public val Gray300: Color = Color(0xFFD1D5DB)
    public val Gray400: Color = Color(0xFF9CA3AF)
    public val Gray500: Color = Color(0xFF6B7280)
    public val Gray600: Color = Color(0xFF4B5563)
    public val Gray700: Color = Color(0xFF374151)
    public val Gray800: Color = Color(0xFF1F2937)
    public val Gray900: Color = Color(0xFF111827)
    public val Black: Color = Color(0xFF000000)
    public val White: Color = Color(0xFFFFFFFF)

    /** Web 端零散使用的浅底：#FAFAFA / #F7F7F7 / #F5F5F5，统一收敛为三档。 */
    public val Wash50: Color = Color(0xFFFAFAFA)
    public val WashLight: Color = Color(0xFFF7F7F7)
    public val WashGray: Color = Color(0xFFF5F5F5)

    // ----------------------------------------------------------------------------------
    // 行程（Trip）模块专用色：Web 端行程页的米棕色系
    // ----------------------------------------------------------------------------------
    public val TripSandLight: Color = Color(0xFFFDF3E6)
    public val TripSandBase: Color = Color(0xFFF7E9D2)
    public val TripSandDeep: Color = Color(0xFFF2DDBC)
    public val TripInkDeep: Color = Color(0xFF1C1410)
    public val TripInkSoft: Color = Color(0xFF1A1108)

    // ----------------------------------------------------------------------------------
    // 语义色
    // ----------------------------------------------------------------------------------
    public val Error: Color = Color(0xFFEF4444)
    public val ErrorSoft: Color = Color(0xFFF87171)
    public val Danger: Color = Color(0xFFE5484D)
    public val Success: Color = Color(0xFF16A34A)
    public val Info: Color = Color(0xFF3B82F6)
    public val Disabled: Color = Color(0xFFB6BDCC)

    // ----------------------------------------------------------------------------------
    // 透明度：遮罩 / 分隔线 / 拖拽指示器
    // ----------------------------------------------------------------------------------
    public const val ScrimStrongAlpha: Float = 0.6f
    public const val ScrimMediumAlpha: Float = 0.55f
    public const val ScrimSoftAlpha: Float = 0.35f
    public const val ScrimFaintAlpha: Float = 0.25f
    public const val HandleAlpha: Float = 0.5f
    public const val DividerEdgeAlpha: Float = 0.3f
    public const val DividerCoreAlpha: Float = 0.8f

    // ----------------------------------------------------------------------------------
    // 语义映射：UI 组件只引用语义名，换肤时只需改映射
    // ----------------------------------------------------------------------------------
    /** 主文本：对齐 Web 端 text-gray-900（172 次，最高频）。 */
    public val TextPrimary: Color = Gray900

    /** 次要文本 / 默认图标色：对齐 Web 端 text-gray-400（192 次）。 */
    public val TextSecondary: Color = Gray400

    /** 三级文本：对齐 text-gray-500。 */
    public val TextTertiary: Color = Gray500

    /** 品牌容器上的文本：始终为白。 */
    public val TextOnBrand: Color = White

    /** 页面底色。 */
    public val Background: Color = White

    /** 卡片/面板底色：对齐 bg-gray-100（111 次）。 */
    public val Surface: Color = Gray100

    /** 更浅的凹陷底色：对齐 bg-gray-50。 */
    public val SurfaceSunken: Color = Gray50

    /** 分隔线：对齐 border-gray-200。 */
    public val Divider: Color = Gray200

    /** 默认图标色。 */
    public val IconDefault: Color = Gray400

    /** 激活（选中）态图标与文字。 */
    public val IconActive: Color = Gray900
}
