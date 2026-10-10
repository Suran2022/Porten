/*
 * 约定插件模块的标准构建脚本。
 *
 * 说明：
 *   - 使用 `kotlin-dsl` 预编译脚本插件能力，所有约定插件以 Kotlin 类实现；
 *   - AGP / KGP 以 compileOnly 引入，运行时由主工程提供，避免版本二次绑定；
 *   - gradlePlugin {} 中声明的每个插件 id 都必须有对应实现类，编译期即校验。
 */

plugins {
    `kotlin-dsl`
}

dependencies {
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.kotlin.gradlePlugin)
}

gradlePlugin {
    plugins {
        register("androidApplication") {
            id = "porten.android.application"
            implementationClass = "jys.porten.buildlogic.PortenAndroidApplicationConventionPlugin"
        }
        register("androidLibrary") {
            id = "porten.android.library"
            implementationClass = "jys.porten.buildlogic.PortenAndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = "porten.android.compose"
            implementationClass = "jys.porten.buildlogic.PortenAndroidComposeConventionPlugin"
        }
        register("androidFeature") {
            id = "porten.android.feature"
            implementationClass = "jys.porten.buildlogic.PortenAndroidFeatureConventionPlugin"
        }
        register("kotlinLibrary") {
            id = "porten.kotlin.library"
            implementationClass = "jys.porten.buildlogic.PortenKotlinLibraryConventionPlugin"
        }
        register("releaseHardening") {
            id = "porten.release.hardening"
            implementationClass = "jys.porten.buildlogic.PortenReleaseHardeningConventionPlugin"
        }
    }
}
