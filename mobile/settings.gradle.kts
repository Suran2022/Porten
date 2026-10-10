// ============================================================================================
// Porten 移动端 · Gradle 设置（根工程）
// --------------------------------------------------------------------------------------------
// 职责边界：本文件只做三件事
//   1. 声明构建的插件仓库与依赖仓库；
//   2. 声明所有参与构建的 Gradle 模块（app / core / feature / build-logic）；
//   3. 依据 porten.flutter.mode 选择 Flutter 集成形态（源码 Module / 产物 AAR）。
// 严禁在此处编写任何业务逻辑、任务或计算。
// ============================================================================================

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // 约定插件（build-logic）：所有模块共用一套 Android / Compose / Kotlin 标准配置
    includeBuild("build-logic")
}

dependencyResolutionManagement {
    // 依赖仓库统一在本文件声明；采用 PREFER_SETTINGS：
    // Flutter 的 flutter-gradle-plugin 会向每个子工程注入 project 级 Maven 仓库，
    // PREFER_PROJECT 模式下会让子工程丢弃本文件声明的 google()/mavenCentral()，
    // 导致 aapt2 / kotlin-stdlib 等基础依赖解析失败；PREFER_SETTINGS 反向忽略
    // 插件注入的仓库（其所需 download.flutter.io 已在本文件显式声明）。
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Flutter Engine 产物（flutter_embedding.jar / flutter.jar）官方托管仓库
        maven("https://storage.googleapis.com/download.flutter.io")
        // AAR 模式下 `flutter build aar` 产出的本地 Maven 仓库目录；
        // 目录不存在时 Gradle 仅忽略，不会报错。
        maven("${rootDir}/flutter/porten_flutter/build/host/outputs/repo")
    }
}

rootProject.name = "PortenMobile"

// ---------------------------------------------------------------------------------------------
// 原生 Android 模块
// ---------------------------------------------------------------------------------------------
include(":app")

// ---- 核心能力层（不依赖任何 feature，不依赖 UI；原生核心能力的唯一实现层）----
include(":core:model")        // 数据结构：跨层 / 跨端（桥接）使用的纯数据模型
include(":core:common")       // 基础能力：结果封装、协程调度、日志、扩展、全局异常
include(":core:design")       // 设计令牌：品牌色 / 字阶 / 间距 / 圆角（还原 Web 端）
include(":core:security")     // 安全防护：根/调试/注入检测、证书绑定、运行时完整性校验
include(":core:storage")      // 安全存储：Keystore 加密 SharedPreferences / DataStore
include(":core:network")      // 网络：HTTP 客户端、拦截器、WebSocket（长连接）抽象
include(":core:im")           // IM 核心：长连接保活、心跳、重连、消息收发管线
include(":core:push")         // 推送：厂商通道抽象与统一收件柜
include(":core:bridge")       // 桥接：原生 ↔ Flutter 双向通信（Pigeon / MethodChannel）
include(":core:webview")      // H5：WebView 容器、JSBridge、白名单与加固
include(":core:data")         // 数据仓储：Repository 实现，组合 network / storage / mock
include(":core:ui")           // 原生 UI：Compose 组件库与主题（仅原生承载页面使用）

// ---- 业务功能模块（可依赖 core:*，彼此之间不允许横向依赖）----
include(":feature:launcher")  // 启动：Splash、冷启动编排、安全自检、路由分发
include(":feature:main")      // 主容器：底部导航容器、Flutter/H5 页面装载
include(":feature:hybrid")    // 混合容器：Flutter Activity/Fragment 与 H5 Activity 的统一装载

// ---------------------------------------------------------------------------------------------
// Flutter 集成（Add-to-App）
// ---------------------------------------------------------------------------------------------
// porten.flutter.mode = module  → 源码依赖 flutter/.android/Flutter（开发期，支持源码级调试）
// porten.flutter.mode = aar     → 依赖 flutter build aar 产出的本地 Maven 产物（发布期 / CI）
// 两种模式都无需改动任何模块代码，由 listGenerated below与:app模块的依赖映射切换。
val flutterIntegrationMode: String =
    providers.gradleProperty("porten.flutter.mode").orNull ?: "module"

check(flutterIntegrationMode in arrayOf("module", "aar")) {
    "porten.flutter.mode 取值非法：$flutterIntegrationMode，仅支持 module | aar"
}

if (flutterIntegrationMode == "module") {
    val flutterModuleRoot = file("flutter/porten_flutter")
    check(flutterModuleRoot.exists()) {
        "Flutter Module 不存在：$flutterModuleRoot。请先在 flutter/ 下创建 porten_flutter 模块。"
    }
    // Flutter 官方提供的集成脚本：include :flutter 子工程、加载 Flutter 插件子工程、
    // 并把 Flutter SDK 的 gradle 构建纳入 composite build。
    apply(from = File(flutterModuleRoot, ".android/include_flutter.groovy").path)
}
