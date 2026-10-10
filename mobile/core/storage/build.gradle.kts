/*
 * :core:storage —— 端侧安全存储。
 *
 * 提供：Keystore 加密的键值对（Token / Porten ID 等敏感信息）、DataStore 偏好项。
 * 约束：任何敏感写入必须经由本模块的加密通道，禁止直接使用 SharedPreferences 明文存储。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.storage"
}

dependencies {
    implementation(project(":core:common"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.security.crypto)
    implementation(libs.androidx.datastore.preferences)
}
