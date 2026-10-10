/*
 * :feature:hybrid —— 混合容器（Flutter / H5 的唯一装载点）。
 *
 * 职责：
 *   - Flutter：FlutterActivity / FlutterFragment 的统一封装（引擎预热、路由参数、生命周期）；
 *   - H5：基于 :core:webview 的 WebActivity / WebFragment 封装；
 *   - 桥接：把 :core:bridge 定义的契约绑定到具体实现（MethodChannel / Pigeon / JSBridge）。
 *
 * 为什么只有这里能依赖 Flutter：
 *   保持 :core:* 与 :feature:main 对跨端容器零感知，后续替换为其他容器或移除 Flutter
 *   只需改动本模块，符合大厂企业级混合架构的「单点隔离」原则。
 *
 * 两种 Flutter 集成形态由 porten.flutter.mode 决定，本文件已自动适配，业务代码无需分支。
 */

plugins {
    alias(libs.plugins.porten.android.library)
    alias(libs.plugins.porten.android.compose)
}

android {
    namespace = "jys.porten.feature.hybrid"
}

val flutterIntegrationMode: String = providers.gradleProperty("porten.flutter.mode").orNull ?: "module"

dependencies {
    api(project(":core:bridge"))
    implementation(project(":core:common"))
    implementation(project(":core:data"))
    implementation(project(":core:webview"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.fragment)

    // Flutter：源码依赖（开发期）或 AAR 产物依赖（发布期 / CI）
    if (flutterIntegrationMode == "module") {
        implementation(project(":flutter"))
    } else {
        implementation("jys.porten.porten_flutter:flutter_release:1.0")
    }
}
