/*
 * :core:ui —— 原生侧 UI 组件库。
 *
 * 提供：Porten 主题（Material3 + 品牌色）、基础控件（按钮/输入/Toast/底部导航等）、
 *       统一的按压反馈（对齐 Web 端「无默认点击波纹」的交互规范）。
 * 约束：组件只允许读取 :core:design 的设计令牌，禁止内联颜色与尺寸。
 */

plugins {
    alias(libs.plugins.porten.android.library)
    alias(libs.plugins.porten.android.compose)
}

android {
    namespace = "jys.porten.core.ui"
}

dependencies {
    api(project(":core:design"))
    implementation(project(":core:common"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
}
