/*
 * 约定插件：纯 Kotlin 模块标准配置（无 Android 依赖）。
 *
 * 适用：:core:model —— 仅承载跨层、跨端数据结构的纯 Kotlin 模块。
 *
 * 价值：纯 Kotlin 模块不参与 Android 变体与资源合并，编译最快、可被任意平台模块依赖，
 *       也为「后续能力下沉到 KMP（Kotlin Multiplatform）」预留通道。
 */

package jys.porten.buildlogic

import org.gradle.api.JavaVersion
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.kotlin.dsl.configure

class PortenKotlinLibraryConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("org.jetbrains.kotlin.jvm")
            pluginManager.apply("org.jetbrains.kotlin.plugin.serialization")

            // Java 与 Kotlin 的 JVM target 必须一致，否则 Kotlin 编译校验直接失败
            extensions.configure<JavaPluginExtension> {
                val target = JavaVersion.toVersion(libs.versionOf("javaTarget"))
                sourceCompatibility = target
                targetCompatibility = target
            }

            dependencies.apply {
                add("implementation", libs.findLibrary("kotlinx-serialization-json").get())
                add("testImplementation", libs.findLibrary("junit4").get())
            }
            configureKotlinCommon()
        }
    }
}
