/*
 * 约定插件：Jetpack Compose（Material 3）标准配置。
 *
 * 适用：任何承载原生 UI 的模块（:core:ui、:feature:*）。
 * 覆盖：
 *   - KGP Compose 编译器插件（AGP 9 起 Compose 编译器由 Kotlin 插件提供，不再需要 composeOptions）
 *   - Compose BOM + 基础依赖（ui / graphics / foundation / material3 / runtime）
 *   - Debug 包的 UI 预览工具、Release 包自动剔除
 *
 * 注意：tooling-preview 用于 @Preview 注解，不能进 release 包，故用 debugImplementation。
 */

package jys.porten.buildlogic

import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

class PortenAndroidComposeConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            // AGP 8：Compose 编译器由 KGP 的 compose 插件提供（org.jetbrains.kotlin.plugin.compose）
            pluginManager.apply("org.jetbrains.kotlin.plugin.compose")

            // AGP 8 注册的是 legacy extension（BaseAppModuleExtension / LibraryExtension），
            // 二者均实现 DSL 的 ApplicationExtension / LibraryExtension；按模块类型择一配置
            runCatching {
                extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
                    buildFeatures { compose = true }
                }
            }
            runCatching {
                extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                    buildFeatures { compose = true }
                }
            }

            dependencies {
                add("implementation", platform(libs.findLibrary("androidx-compose-bom").get()))
                add("implementation", libs.findLibrary("androidx-compose-foundation").get())
                add("implementation", libs.findLibrary("androidx-compose-material3").get())
                add("implementation", libs.findLibrary("androidx-compose-runtime").get())
                add("implementation", libs.findLibrary("androidx-compose-ui").get())
                add("implementation", libs.findLibrary("androidx-compose-ui-graphics").get())
                add("implementation", libs.findLibrary("androidx-compose-ui-tooling-preview").get())
                add("implementation", libs.findLibrary("androidx-activity-compose").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-runtime-ktx").get())
                add("debugImplementation", libs.findLibrary("androidx-compose-ui-tooling").get())
            }
        }
    }
}
