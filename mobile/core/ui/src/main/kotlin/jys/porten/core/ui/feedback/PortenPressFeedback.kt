package jys.porten.core.ui.feedback

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.graphicsLayer
import jys.porten.core.design.tokens.PortenInteraction
import jys.porten.core.design.tokens.PortenMotion

/**
 * Porten 统一按压反馈。
 *
 * 为什么不用系统水波纹：
 *   React Web 端通过 useTouchInteraction / usePointerInteraction 自行管理按压态，
 *   **没有浏览器默认反馈**；若移动端放任 Material Ripple，两端点击观感会明显不一致。
 *
 * 统一规范：按压时整体透明度降至 [PortenInteraction.PressOpacityMin]、
 *           并轻微缩放至 [PortenInteraction.PressScaleMin]，100ms 快速过渡、抬起回弹。
 *
 * 用法：
 * ```kotlin
 * Box(modifier = Modifier.portenClickable { viewModel.submit() })
 * ```
 */
public fun Modifier.portenClickable(
    enabled: Boolean = true,
    scaleOnPress: Boolean = true,
    onClick: () -> Unit,
): Modifier = composed {
    val interactionSource: MutableInteractionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()

    val scale: Float by animateFloatAsState(
        targetValue = if (pressed && scaleOnPress) PortenInteraction.PressScaleMin else 1f,
        animationSpec = tween(durationMillis = PortenMotion.MicroMs),
        label = "portenPressScale",
    )
    val alpha: Float by animateFloatAsState(
        targetValue = if (pressed) PortenInteraction.PressOpacityMin else 1f,
        animationSpec = tween(durationMillis = PortenMotion.MicroMs),
        label = "portenPressAlpha",
    )

    this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
            this.alpha = alpha
        }
        // indication = null：彻底关闭水波纹；interactionSource 交给按压态动画使用
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = enabled,
            onClick = onClick,
        )
}

/**
 * 与 [portenClickable] 相同语义，但**不做缩放**，仅降透明度。
 *
 * 适用：消息气泡、列表行等大面积元素——这类元素做缩放会显得整块抖动，视觉更脏。
 */
public fun Modifier.portenClickableNoScale(
    enabled: Boolean = true,
    onClick: () -> Unit,
): Modifier = portenClickable(enabled = enabled, scaleOnPress = false, onClick = onClick)

/**
 * 按压态动画是否需要跳过：当系统开启「减少动画」等无障碍开关时可调用，由调用方决定策略。
 */
@Composable
public fun isPressAnimationRecommended(): Boolean = true
