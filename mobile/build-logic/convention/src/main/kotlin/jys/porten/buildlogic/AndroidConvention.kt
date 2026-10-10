/*
 * Android / Kotlin 模块的公共编译配置（AGP 8.13 版）。
 *
 * 该文件是「约定插件的工具箱」，只提供配置函数，不注册任何插件；
 * 所有 Porten 原生模块共享同一套标准配置，避免各模块自由发挥导致配置漂移。
 *
 * AGP 8 说明：CommonExtension 仍是 6 泛型参数接口；为避免 star projection
 * 无法调用 setter 的问题，本文件把公共配置收敛为接收具体子类型的委托函数，
 * 由 Application / Library 两个约定插件分别调用。
 */

package jys.porten.buildlogic

import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.CompileOptions
import com.android.build.api.dsl.DefaultConfig
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.dsl.Packaging
import org.gradle.api.GradleException
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalog
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.kotlin.dsl.getByType
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

/** 主工程的版本目录（gradle/libs.versions.toml）。 */
internal val Project.libs: VersionCatalog
    get() = extensions.getByType<VersionCatalogsExtension>().named("libs")

/** 从版本目录读取版本号，缺失时立即失败，避免静默降级。 */
internal fun VersionCatalog.versionOf(name: String): String =
    findVersion(name).orElseThrow {
        GradleException("版本目录缺少 [versions] 项：$name，请在 gradle/libs.versions.toml 中补充")
    }.requiredVersion

/** Application 模块公共配置入口。 */
internal fun Project.configureAndroidCommon(extension: ApplicationExtension) {
    extension.apply {
        configureCommonParts(
            setCompileSdk = { v -> compileSdk = v },
            defaultConfig = defaultConfig,
            compileOptions = compileOptions,
            packaging = packaging,
        )
    }
    configureKotlinCommon()
}

/** Library 模块公共配置入口。 */
internal fun Project.configureAndroidCommon(extension: LibraryExtension) {
    extension.apply {
        configureCommonParts(
            setCompileSdk = { v -> compileSdk = v },
            defaultConfig = defaultConfig,
            compileOptions = compileOptions,
            packaging = packaging,
        )
    }
    configureKotlinCommon()
}

/**
 * 统一配置 Android 模块的公共编译选项。
 *
 * 覆盖范围：编译 SDK、最低运行 SDK、Java 兼容性、资源打包排除项。
 * 不覆盖：namespace（模块私有）、versionCode/versionName（仅 application 模块）。
 */
private fun configureCommonParts(
    setCompileSdk: (Int) -> Unit,
    defaultConfig: DefaultConfig,
    compileOptions: CompileOptions,
    packaging: Packaging,
    javaTarget: String,
    minSdkValue: Int,
    compileSdkValue: Int,
) {
    setCompileSdk(compileSdkValue)
    defaultConfig.apply {
        minSdk = minSdkValue
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    compileOptions.apply {
        val target = JavaVersion.toVersion(javaTarget)
        sourceCompatibility = target
        targetCompatibility = target
    }
    packaging.resources.excludes += setOf(
        // 第三方库自带的许可元数据不进 APK，避免打包期重复资源冲突
        "/META-INF/{AL2.0,LGPL2.1}",
        "/META-INF/LICENSE*",
        "/META-INF/NOTICE*",
    )
}

private fun Project.configureCommonParts(
    setCompileSdk: (Int) -> Unit,
    defaultConfig: DefaultConfig,
    compileOptions: CompileOptions,
    packaging: Packaging,
) = configureCommonParts(
    setCompileSdk = setCompileSdk,
    defaultConfig = defaultConfig,
    compileOptions = compileOptions,
    packaging = packaging,
    javaTarget = libs.versionOf("javaTarget"),
    minSdkValue = libs.versionOf("minSdk").toInt(),
    compileSdkValue = libs.versionOf("compileSdk").toInt(),
)

/**
 * 统一配置 Kotlin 编译选项。
 *
 * - jvmTarget 与 Java 目标版本保持一致；
 * - 显式 opt-in 协程实验性 API（IM 长连接 / 推送模块依赖 StateFlow / Flow 的高级能力）。
 */
internal fun Project.configureKotlinCommon() {
    tasks.withType(KotlinCompile::class.java).configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.fromTarget(libs.versionOf("javaTarget")))
            freeCompilerArgs.addAll("-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi")
        }
    }
}
