/*
 * :feature:main —— 主容器（底部导航 + 页面装载）。
 *
 * 职责：登录后的一级容器，负责 Tab 切换、页面堆叠、与各业务页面的接入装配。
 * 约束：不直接依赖 :flutter；需要 Flutter 页面时通过 :feature:hybrid 提供的路由契约进入。
 */

plugins {
    alias(libs.plugins.porten.android.feature)
}

android {
    namespace = "jys.porten.feature.main"
}

dependencies {
    implementation(project(":core:bridge"))
    implementation(project(":core:common"))
    implementation(project(":core:design"))
    implementation(project(":core:ui"))
}
