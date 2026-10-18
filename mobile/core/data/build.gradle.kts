/*
 * :core:data —— 数据仓储层。
 *
 * 提供：Repository 实现，负责组合「真实 API」与「Mock 引擎」两条数据来源，
 *       并按 BuildConfig.USE_MOCK 决定运行时走向（与 Web 端 VITE_USE_MOCK 等价）。
 * 约束：上层（feature / Flutter）只见 Repository 接口，不得感知数据来源差异。
 */

plugins {
    alias(libs.plugins.porten.android.library)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "jys.porten.core.data"
}

dependencies {
    api(project(":core:model"))
    implementation(project(":core:common"))
    implementation(project(":core:network"))
    implementation(libs.retrofit.core)
    implementation(project(":core:storage"))
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
}
