/*
 * :core:im —— IM 核心（原生负责的关键能力）。
 *
 * 提供：长连接生命周期管理、心跳保活、指数退避重连、网络状态监听、
 *       消息上行/下行管线、离线消息补偿。
 *
 * 选型理由：保活、后台存活、网络切换恢复、系统级约束都依赖平台能力，
 *           原生实现比 Flutter 更可控，因此该能力由原生承载并向 Flutter 侧透出状态与数据。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.im"
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    implementation(project(":core:network"))
    implementation(project(":core:storage"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.process)
}
