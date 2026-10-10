package jys.porten.feature.launcher

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import jys.porten.core.design.tokens.PortenColor
import jys.porten.core.design.tokens.PortenDimens
import jys.porten.core.design.tokens.PortenTypography

/**
 * 骨架占位页。
 *
 * 存在意义：让 App 在「开屏结束 → 主容器接入之前」始终有明确去处，
 * 避免过渡阶段出现白屏或空 Surface（这类空白帧在产品上会被直接判定为「卡死」）。
 * 待 :feature:main 的主容器接入后，本组件即被替换下线。
 */
@Composable
internal fun SkeletonPlaceholder(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(horizontal = PortenDimens.Space2XL),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(id = R.string.porten_launcher_skeleton_title),
            style = PortenTypography.LG,
            color = PortenColor.TextPrimary,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(PortenDimens.SpaceSM))
        Text(
            text = stringResource(id = R.string.porten_launcher_skeleton_desc),
            style = PortenTypography.SM,
            color = PortenColor.TextSecondary,
            textAlign = TextAlign.Center,
        )
    }
}
