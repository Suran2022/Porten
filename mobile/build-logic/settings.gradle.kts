// ============================================================================================
// build-logic · 合成构建（Included Build）设置
// --------------------------------------------------------------------------------------------
// 约定插件在独立合成构建中编译，与主工程共用仓库与版本目录，互不污染。
// --------------------------------------------------------------------------------------------

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // 与主工程共用同一份版本目录，避免版本双写
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "build-logic"

include(":convention")
