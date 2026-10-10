/*
 * :core:security —— 运行期安全防护。
 *
 * 提供：运行环境体检（root / 模拟器 / 调试器 / Hook 框架）、证书绑定、包完整性校验、
 *       防截屏与隐私遮罩开关。
 * 约束：只产出「检测结果」与「策略」，不直接做 UI 弹窗，由 :feature:launcher 决定呈现方式。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.security"
}

dependencies {
    implementation(project(":core:common"))
    implementation(libs.androidx.core.ktx)
}
