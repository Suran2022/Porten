package jys.porten.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import jys.porten.core.ui.theme.PortenTheme
import jys.porten.feature.hybrid.FlutterContainer
import jys.porten.feature.hybrid.FlutterHost
import jys.porten.feature.launcher.PortenLauncherHost

/**
 * Porten 唯一 Activity。
 *
 * 采用单 Activity 架构：所有原生页面以 Compose 呈现，
 * Flutter 页面由 :feature:hybrid 提供的容器装载，H5 页面同理，Activity 数量保持最少。
 *
 * 职责边界：本类只做「窗口与主题」两件事，业务逻辑全部下沉到 feature 模块。
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super 之前安装：接管冷启动首帧白屏，避免出现未知时长的空白窗口
        installSplashScreen()
        super.onCreate(savedInstanceState)

        // 冷启动即预热 Flutter 引擎（幂等），开屏 3s 期间 Dart 侧并行完成
        // bootstrap → PortenApp 初始化，开屏结束直接呈现登录界面零等待。
        // 入口为 main.dart 的 main()（内部调 runPortenFlutterApp）。
        FlutterHost.warmUp(this)

        setContent {
            PortenTheme {
                PortenLauncherHost(
                    readyContent = { FlutterContainer() },
                )
            }
        }
    }
}
