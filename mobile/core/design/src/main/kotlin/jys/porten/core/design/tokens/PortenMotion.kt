package jys.porten.core.design.tokens

/**
 * Porten 交互与动效令牌。
 *
 * 动效时长与 Web 端关键帧一一对应：
 *   .spinner              → 800ms 匀速旋转
 *   Splash 图标出现        → 700ms
 *   Splash Logo 上移       → 600ms（延迟 150ms）
 *   Splash 整体淡出        → 400ms
 *   Sheet 步骤切换         → 250ms
 *   搜索内容切换淡入       → 260ms
 *   展开/收起              → 300ms
 */
public object PortenMotion {

    /** 微交互（按压反馈、状态切换）：100ms。 */
    public const val MicroMs: Int = 100

    /** 短动画（简单显隐）：200ms。 */
    public const val ShortMs: Int = 200

    /** 中等动画（展开/折叠）：300ms。 */
    public const val MediumMs: Int = 300

    /** 长动画（复杂转场）：500ms。 */
    public const val LongMs: Int = 500

    /** 面板展开/收起：300ms。 */
    public const val ExpandMs: Int = 300

    /** 开屏：图标渐现放大 700ms。 */
    public const val SplashIconMs: Int = 700

    /** 开屏：Logo 上移渐现 600ms（延迟 150ms）。 */
    public const val SplashFadeUpMs: Int = 600

    /** 开屏：整体淡出 400ms。 */
    public const val SplashExitMs: Int = 400

    /** 列表/搜索切换内容淡入：260ms。 */
    public const val ContentInMs: Int = 260

    /** 弹出面板内步骤切换：250ms。 */
    public const val SheetStepMs: Int = 250

    /** Loading 旋转一周：800ms。 */
    public const val SpinnerMs: Int = 800
}

/**
 * Porten 按压反馈令牌。
 *
 * 关键约束：Web 端通过 useTouchInteraction / usePointerInteraction 自行实现按压反馈，
 * **不使用浏览器默认行为**；移动端同样严禁使用系统水波纹（Material Ripple），
 * 必须由统一的 `PortenPressFeedback` 提供「透明度变化 + 轻微缩放」的反馈，确保两端观感一致。
 */
public object PortenInteraction {

    /** 是否启用系统水波纹：恒为 false，禁止打开。 */
    public const val RippleEnabled: Boolean = false

    /** 按压态最低透明度。 */
    public const val PressOpacityMin: Float = 0.6f

    /** 按压态最小缩放比。 */
    public const val PressScaleMin: Float = 0.96f
}
