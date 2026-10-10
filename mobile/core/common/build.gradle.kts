/*
 * :core:common —— 全局基础能力。
 *
 * 提供：统一结果封装、协程调度器注入、日志门面、通用扩展、全局异常契约。
 * 约束：不依赖任何业务概念，可被任意模块依赖（单向朝下层）。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.common"
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.core.ktx)
}
