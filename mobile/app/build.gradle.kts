import java.util.Properties

/*
 * Porten 宿主壳模块（:app）
 *
 * 职责边界：
 *   - 作为唯一的 Android Application 产物模块，负责组装所有 feature / core 模块；
 *   - 承载 Application 入口、Activity 壳、签名与发布加固配置；
 *   - **不允许**编写任何业务页面逻辑，业务一律落在 :feature:* 模块。
 *
 * 环境与 Mock 切换：
 *   产品风味 environment = dev | staging | prod，并由 gradle 属性一起决定几个核心开关，
 *   实现与 Web 端 `VITE_USE_MOCK` 等价的「Mock / 真实 API 一键切换」能力：
 *     gradle.properties  →  porten.mock.enabled=true
 *     命令行覆盖        →  -Pporten.mock.enabled=false
 *   取值优先级：命令行 -P > gradle.properties > flavor 默认值。
 */

plugins {
    // 内部已包含：com.android.application + 发布加固（混淆/资源缩减）+ Compose（内置 Kotlin）
    alias(libs.plugins.porten.release.hardening)
    alias(libs.plugins.porten.android.compose)
}

val useMockEngine: Boolean = (providers.gradleProperty("porten.mock.enabled").orNull ?: "true").toBoolean()
val securityEnabled: Boolean = (providers.gradleProperty("porten.security.enabled").orNull ?: "true").toBoolean()
val loggingEnabled: Boolean = (providers.gradleProperty("porten.logging.enabled").orNull ?: "true").toBoolean()

// API 基地址（dev/staging 可用 -Pporten.api.base.url / -Pporten.api.ws.url 覆盖，
// 联调部署环境（如 Zeabur 预发域名）时无需改代码；prod 恒为正式域名，不走属性覆盖）。
val apiBaseUrl: String? = providers.gradleProperty("porten.api.base.url").orNull
val apiWsUrl: String? = providers.gradleProperty("porten.api.ws.url").orNull

android {
    namespace = "jys.porten.app"

    // ---------------------------------------------------------------------------------------
    // 签名配置：从 local.properties 读取（凭据仅存本地，不入库）。
    // staging release 为「测试正式包」：正式签名 + 可直接安装；
    // prod release 若无签名配置则回退 staging 密钥，避免产出无法安装的 unsigned 包。
    // ---------------------------------------------------------------------------------------
    val localProps = Properties().apply {
        val f = rootProject.file("local.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    val storeFile = localProps.getProperty("PORTEN_STORE_FILE")?.let { file(it) }
    signingConfigs {
        if (storeFile != null && storeFile.exists()) {
            create("porten") {
                this.storeFile = storeFile
                storePassword = localProps.getProperty("PORTEN_STORE_PASSWORD")
                keyAlias = localProps.getProperty("PORTEN_KEY_ALIAS")
                keyPassword = localProps.getProperty("PORTEN_KEY_PASSWORD")
            }
        }
    }

    defaultConfig {
        applicationId = "jys.porten.app"
        versionCode = 26 // 每次分发递增：防止同号覆盖安装被安装器拒绝/静默失败
        versionName = "1.0.0"
        // 资源语言白名单：Porten 现阶段仅投放简体中文，剔除第三方库带来的多语言资源
        resourceConfigurations += setOf("zh")
    }

    buildFeatures {
        // flavor 使用 resValue 注入各环境应用名，AGP 9 默认关闭该特性，需显式开启
        resValues = true
    }

    // ---------------------------------------------------------------------------------------
    // 环境风味：dev（日常开发）/ staging（预发联调）/ prod（对外发布）
    // ---------------------------------------------------------------------------------------
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Porten Dev")
            buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl ?: "http://10.0.2.2:8000/api/v1"}\"")
            buildConfigField("String", "API_WS_URL", "\"${apiWsUrl ?: "ws://10.0.2.2:8000/ws"}\"")
            buildConfigField("boolean", "USE_MOCK", useMockEngine.toString())
            buildConfigField("boolean", "ENABLE_SECURITY", "false")
            buildConfigField("boolean", "ENABLE_LOGGING", loggingEnabled.toString())
        }

        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Porten 预发")
            buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl ?: "https://staging.example.com/api/v1"}\"")
            buildConfigField("String", "API_WS_URL", "\"${apiWsUrl ?: "wss://staging.example.com/ws"}\"")
            buildConfigField("boolean", "USE_MOCK", useMockEngine.toString())
            buildConfigField("boolean", "ENABLE_SECURITY", securityEnabled.toString())
            buildConfigField("boolean", "ENABLE_LOGGING", loggingEnabled.toString())
        }

        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Porten")
            buildConfigField("String", "API_BASE_URL", "\"https://example.com/api/v1\"")
            buildConfigField("String", "API_WS_URL", "\"wss://example.com/ws\"")
            // 生产包强制关闭 Mock：即使命令行传入 true 也不生效，避免演示数据污染线上
            buildConfigField("boolean", "USE_MOCK", "false")
            buildConfigField("boolean", "ENABLE_SECURITY", securityEnabled.toString())
            buildConfigField("boolean", "ENABLE_LOGGING", "false")
        }
    }

    buildTypes {
        release {
            // 有签名配置则正式签名（staging/prod 可安装），无则显式报错而非产出 unsigned 包
            signingConfig = if (signingConfigs.any { it.name == "porten" }) {
                signingConfigs.getByName("porten")
            } else {
                signingConfigs.getByName("debug") // 本地兜底，保证包始终可安装
            }
            // 仅出 arm64-v8a：真机全量覆盖，体积减半，显著降低手机浏览器下载截断概率
            ndk { abiFilters += "arm64-v8a" }
        }
    }

    dependenciesInfo {
        // 对外发布的 APK 不写入依赖清单元数据，减少可被反编译的情报输出
        includeInApk = false
        includeInBundle = false
    }
}

/*
 * Flutter 集成（Add-to-App）
 *
 * 两种形态由 gradle.properties 的 porten.flutter.mode 决定，业务代码零改动：
 *   module → 源码依赖 flutter/.android/Flutter（开发期，可源码级断点调试 Flutter）
 *   aar    → 依赖 `flutter build aar` 产出的本地 Maven 产物（发布期 / CI，原生同学免装 Flutter）
 */
val flutterIntegrationMode: String = providers.gradleProperty("porten.flutter.mode").orNull ?: "module"

/*
 * 瓶颈 11 修复：AGP 的 strip 任务对 Flutter 官方预编译 AAR 的 libflutter.so
 * 不生效（release 引擎带完整 DWARF 约 165MB/ABI），打包体积虚增 450MB。
 * 此处在 strip 任务输出后追加执行 NDK llvm-strip（仅处理 >32MB 的大 so），
 * strip 后 libflutter.so 约 12MB/ABI。详见瓶颈方案文档。
 */
val llvmStrip = "/opt/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"

tasks.matching { it.name.startsWith("strip") && it.name.endsWith("DebugSymbols") }.configureEach {
    outputs.upToDateWhen { false }
    doLast {
        val outDir = outputs.files.firstOrNull { it.isDirectory } ?: return@doLast
        outDir.walkTopDown()
            .filter { it.isFile && it.extension == "so" && it.length() > 32L * 1024 * 1024 }
            .forEach { so ->
                exec { commandLine(llvmStrip, so.absolutePath) }
                logger.lifecycle("PortenStrip: stripped ${so.name} -> ${so.length() / 1024 / 1024}MB")
            }
    }
}

dependencies {
    // ---- 功能模块 ----
    implementation(project(":feature:launcher"))
    implementation(project(":feature:main"))
    implementation(project(":feature:hybrid"))

    // ---- 核心能力层 ----
    implementation(project(":core:model"))
    implementation(project(":core:common"))
    implementation(project(":core:design"))
    implementation(project(":core:security"))
    implementation(project(":core:storage"))
    implementation(project(":core:network"))
    implementation(project(":core:im"))
    implementation(project(":core:push"))
    implementation(project(":core:bridge"))
    implementation(project(":core:webview"))
    implementation(project(":core:data"))
    implementation(project(":core:ui"))

    // ---- Flutter 引擎（随 porten.flutter.mode 自动选择源码依赖或 AAR 产物依赖）----
    if (flutterIntegrationMode == "module") {
        implementation(project(":flutter"))
    } else {
        implementation("jys.porten.porten_flutter:flutter_release:1.0")
    }

    // ---- 基础 ----
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.androidx.startup.runtime)
    implementation(libs.kotlinx.coroutines.android)
}
