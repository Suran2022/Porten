/*
 * :core:bridge —— 原生 ↔ Flutter 桥接契约（依赖倒置）。
 *
 * 提供：跨端消息的数据模型、序列化约定、通道名常量、回调接口定义。
 *
 * 关键约束：本模块**不得**依赖 Flutter SDK —— 具体实现放在 :feature:hybrid（依赖 :flutter）。
 *           这样「能力层」保持纯净，也为后续替换为其他跨端容器留出通道。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.bridge"
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    implementation(libs.kotlinx.serialization.json)
}
