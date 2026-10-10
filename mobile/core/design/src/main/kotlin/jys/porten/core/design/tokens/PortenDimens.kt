package jys.porten.core.design.tokens

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Porten 尺寸令牌：间距 / 圆角 / 触摸目标 / 屏幕适配基准。
 *
 * 全部取值来自 design/tokens/porten_design_tokens_v1.json，与 Flutter 侧同名令牌严格一致。
 */
public object PortenDimens {

    // ----------------------------------------------------------------------------------
    // 间距：以 4dp 栅格为主，补齐 Web 端实际用到的 2/6/12/20
    // ----------------------------------------------------------------------------------
    public val SpaceXXXS: Dp = 2.dp
    public val SpaceXXS: Dp = 4.dp
    public val SpaceXS: Dp = 6.dp
    public val SpaceSM: Dp = 8.dp
    public val SpaceMD: Dp = 12.dp
    public val SpaceLG: Dp = 16.dp
    public val SpaceXL: Dp = 20.dp
    public val Space2XL: Dp = 24.dp
    public val Space3XL: Dp = 32.dp
    public val Space4XL: Dp = 48.dp

    // ----------------------------------------------------------------------------------
    // 圆角：rounded=4 / md=6 / lg=8 / xl=12 / 2xl=16 / full=胶囊
    // ----------------------------------------------------------------------------------
    public val RadiusBase: Dp = 4.dp
    public val RadiusSM: Dp = 6.dp
    public val RadiusMD: Dp = 8.dp
    public val RadiusLG: Dp = 12.dp
    public val RadiusXL: Dp = 16.dp
    /** 胶囊形（Web 端 rounded-full 使用频率最高，共 170 次）。 */
    public val RadiusPill: Dp = 9999.dp

    // ----------------------------------------------------------------------------------
    // 触摸目标：遵循 Material 3 无障碍规范
    // ----------------------------------------------------------------------------------
    public val TouchTargetMin: Dp = 48.dp
    public val TouchTargetRecommended: Dp = 56.dp

    // ----------------------------------------------------------------------------------
    // 控件尺寸
    // ----------------------------------------------------------------------------------
    /** 底部导航高度：对齐 Web 端 64px 视觉，移动端取 Material 推荐值。 */
    public val BottomNavHeight: Dp = 56.dp

    /** 顶部应用栏高度。 */
    public val TopBarHeight: Dp = 56.dp

    /** 下拉刷新指示球（Web 端 .ptr-loader 为 20px，与 text-sm 行框等高）。 */
    public val PullToRefreshIndicatorSize: Dp = 20.dp

    /** 抽屉/面板拖拽指示器：Web 端 36x4，圆角 2。 */
    public val SheetHandleWidth: Dp = 36.dp
    public val SheetHandleHeight: Dp = 4.dp
    public val SheetHandleRadius: Dp = 2.dp

    /** 分隔线厚度：Web 端 .fade-divider 为 1px。 */
    public val DividerThickness: Dp = 1.dp

    /** 认证页顶部分割进度条厚度（Web 端 .auth-progress 为 1.5px）。 */
    public val AuthProgressThickness: Dp = 1.5.dp
}

/**
 * 屏幕适配基准：等比缩放常量。
 *
 * 背景：React Web 端是**流式响应式布局**，不存在「设计稿宽度」；
 * 而 App 窗口尺寸随设备千差万别，要实现「布局不变、整体等比缩放」，必须人为固定一个基准。
 *
 * 策略（width-first）：以 [DesignWidthDp] 为基准，按屏幕宽度计算缩放系数，
 * 并对超大屏/超小屏做上下限约束，避免平板被拉爆、小屏被压垮。
 */
@Immutable
public object PortenScaling {

    /** 设计基准宽度（dp）。取值需与 Flutter 侧保持一致。 */
    public const val DesignWidthDp: Float = 375f

    /** 设计基准高度（dp），仅用于推算宽高比，不参与缩放系数计算。 */
    public const val DesignHeightDp: Float = 812f

    /** 缩放系数上下限：防止极端屏幕出现畸形布局。 */
    public const val MinScale: Float = 0.8f
    public const val MaxScale: Float = 1.35f

    /**
     * 文本是否跟随宽度等比缩放。
     *
     * 默认 false：文字保持 sp 语义（跟随用户系统字体设置），只有间距/控件尺寸做等比缩放。
     * 这是 IM 类产品的通行做法——字号随屏缩放容易导致长文本换行崩坏、且违背无障碍诉求。
     */
    public const val ScaleText: Boolean = false

    /** 允许用户系统字体缩放影响的最大倍数（超出则截断，避免布局溢出）。 */
    public const val FontScaleMax: Float = 1.3f

    /**
     * 依据屏幕宽度计算缩放系数。
     *
     * @param screenWidthDp 当前配置下的屏幕宽度（dp）。
     * @return 落在 [MinScale] ~ [MaxScale] 区间内的有效缩放系数。
     */
    public fun scaleFor(screenWidthDp: Float): Float {
        if (screenWidthDp <= 0f) return 1f
        val raw = screenWidthDp / DesignWidthDp
        return raw.coerceIn(MinScale, MaxScale)
    }
}
