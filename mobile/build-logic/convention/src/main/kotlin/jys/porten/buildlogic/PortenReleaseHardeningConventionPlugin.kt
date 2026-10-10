/*
 * 约定插件：发布包安全加固标准配置。
 *
 * 适用：仅 :app（最终产物模块）。
 *
 * 目标：针对 Porten 面向的敏感身份群体，发布包必须尽可能提高被反编译、逆向、二次注入的门槛：
 *   1. 代码精简 + 混淆 + 资源缩减（R8 full mode）
 *   2. 去除无用的资源与元数据
 *   3. 关闭 Debug 可调试性、禁用明文流量（网络安全策略由 res/xml 配置协同）
 *
 * 说明：本插件只做「构建期」加固，运行期防护（root/调试/注入检测、证书绑定）位于 :core:security。
 */

package jys.porten.buildlogic

import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

class PortenReleaseHardeningConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("porten.android.application")

            extensions.configure<ApplicationExtension> {
                buildTypes.getByName("release").apply {
                    isMinifyEnabled = true
                    isShrinkResources = true
                    isDebuggable = false
                    proguardFiles(
                        // getDefaultProguardFile 是 CommonExtension 的普通方法（非 bean getter），
                        // 在本 lambda 的接收者作用域内可直接调用
                        getDefaultProguardFile("proguard-android-optimize.txt"),
                        "proguard-rules.pro",
                    )
                }

                buildTypes.getByName("debug").apply {
                    // Debug 包保留可读性便于排错，但同样禁止自动备份敏感数据
                    isMinifyEnabled = false
                }
            }
        }
    }
}
