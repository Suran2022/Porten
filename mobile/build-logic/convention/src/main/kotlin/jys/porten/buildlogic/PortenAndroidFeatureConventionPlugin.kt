/*
 * 约定插件：功能模块（feature）标准配置。
 *
 * 适用：:feature:* 业务模块 —— 一个功能 = 一个模块，模块内按
 *       ui / viewmodel / model / navigation 子包拆分。
 *
 * 覆盖范围：Android Library + Compose + 生命周期 + 导航。
 * 显式不做：不允许在此引入 Application 插件，feature 永远是被组装方，而不是壳。
 */

package jys.porten.buildlogic

import org.gradle.api.Plugin
import org.gradle.api.Project

class PortenAndroidFeatureConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("porten.android.library")
            pluginManager.apply("porten.android.compose")

            dependencies.apply {
                add("implementation", libs.findLibrary("androidx-core-ktx").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-viewmodel-ktx").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-viewmodel-compose").get())
                add("implementation", libs.findLibrary("androidx-lifecycle-runtime-compose").get())
                add("implementation", libs.findLibrary("androidx-navigation-compose").get())
                add("testImplementation", libs.findLibrary("junit4").get())
            }
        }
    }
}
