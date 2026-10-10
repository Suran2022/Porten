/*
 * 约定插件：Android Application 模块标准配置。
 *
 * 适用：仅 :app（宿主壳）使用。
 * 覆盖：AGP application 插件 + Kotlin Android 插件 + 公共编译选项。
 *
 * 说明：namespace / versionCode / versionName / signingConfig 属于「模块个性信息」，
 *       必须由模块自身的 build.gradle.kts 显式声明，约定插件不代劳，避免隐式约定。
 */

package jys.porten.buildlogic

import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

class PortenAndroidApplicationConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("com.android.application")
            pluginManager.apply("org.jetbrains.kotlin.android")

            extensions.configure<ApplicationExtension> {
                configureAndroidCommon(this)
                // app 模块承载 flavor 级 buildConfigField（API 地址 / Mock / 安全开关），
                // AGP 9 默认关闭 BuildConfig，此处对宿主壳显式开启
                buildFeatures { buildConfig = true }
            }
        }
    }
}
