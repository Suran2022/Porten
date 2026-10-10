/*
 * :core:webview —— H5 容器能力。
 *
 * 提供：安全加固的 WebView 容器、原生与 JS 的双向桥（JSBridge）、域名白名单、Cookie/UA 策略。
 * 约束：所有跳转前必须经域名白名单校验，禁止 file:// / javascript: 等危险协议。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.webview"
}

dependencies {
    implementation(project(":core:common"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.webkit)
}
