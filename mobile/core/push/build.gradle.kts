/*
 * :core:push —— 推送通道抽象。
 *
 * 提供：统一收件模型与各厂商/海外通道适配接口，屏蔽渠道差异；
 *       通道选择与注册由 :app 注入具体实现，本模块只定义契约与消息归一。
 */

plugins {
    alias(libs.plugins.porten.android.library)
}

android {
    namespace = "jys.porten.core.push"
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:model"))
    implementation(libs.androidx.core.ktx)
}
