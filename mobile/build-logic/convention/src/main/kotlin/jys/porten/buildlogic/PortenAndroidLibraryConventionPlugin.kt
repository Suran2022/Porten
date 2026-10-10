/*
 * 约定插件：Android Library 模块标准配置。
 *
 * 适用：所有 core:* 与 feature:* 中的 Android 库模块。
 * 覆盖：AGP library 插件 + Kotlin Android 插件 + 公共编译选项。
 *
 * 约束：不开启任何 UI 能力的依赖（Compose 由 porten.android.compose 单独提供），
 *       保证「能力层」与「表现层」的依赖边界清晰可见。
 */

package jys.porten.buildlogic

import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

class PortenAndroidLibraryConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("com.android.library")
            pluginManager.apply("org.jetbrains.kotlin.android")

            extensions.configure<LibraryExtension> {
                configureAndroidCommon(this)
            }
        }
    }
}
