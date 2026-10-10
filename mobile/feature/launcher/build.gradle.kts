/*
 * :feature:launcher —— 冷启动编排。
 *
 * 职责：闪屏页、环境安全自检、必要依赖初始化、进入主容器或引导页的路由分发。
 * 约束：这里只做「编排」，不实现具体能力；所有能力调用都下沉到 :core:*。
 */

plugins {
    alias(libs.plugins.porten.android.feature)
}

android {
    namespace = "jys.porten.feature.launcher"
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:design"))
    implementation(project(":core:security"))
    implementation(project(":core:ui"))
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.lifecycle.runtime.ktx)
}
