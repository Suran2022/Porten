/*
 * :core:network —— 网络通信。
 *
 * 提供：HTTP 客户端（OkHttp + Retrofit）、序列化配置、通用拦截器、
 *       WebSocket 抽象（供 :core:im 复用，实现长连接）。
 * 约束：网络层不感知业务语义，只负责传输、错误映射与 TLS 加固（证书绑定）。
 */

plugins {
    alias(libs.plugins.porten.android.library)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "jys.porten.core.network"
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp.core)
    implementation(libs.okhttp.logging.interceptor)
    implementation(libs.retrofit.core)
    implementation(libs.retrofit.converter.kotlinx.serialization)
}
