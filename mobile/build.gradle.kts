/*
 * Porten 移动端 · 根构建脚本。
 *
 * 规范分工：
 *   - 这里**只**做两件事：提供 Android / Kotlin 插件的统一 classpath（apply false），
 *     以及极少量跨模块任务；
 *   - 所有模块的标准配置一律由 build-logic 的约定插件提供，避免每个 build.gradle.kts 重复声明。
 *
 * 为什么必须在根脚本声明 apply false：
 *   约定插件是独立编译的 synthetic 组件，运行时所需的 AGP / KGP 由主工程 classpath 注入。
 *   若此处不声明，约定插件执行 pluginManager.apply("com.android.library") 时会报
 *   “plugin dependency must include a version number”。
 */

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false

    // Flutter Gradle 插件（apply false 仅注入 classpath，不在根工程应用）。
    // 必须声明：pub 插件子工程（如 shared_preferences_android）的 build.gradle.kts
    // 通过 `flutter.compileSdkVersion` 访问 FlutterExtension，
    // 该类型的 accessor 依赖根 classpath 中存在 Flutter 插件，缺失会导致
    // 插件子工程脚本报 Unresolved reference 'compileSdkVersion'。
    id("dev.flutter.flutter-gradle-plugin") apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
