package jys.porten.app

import android.app.Application
import jys.porten.app.bootstrap.AppBootstrap

/**
 * Porten 应用入口。
 *
 * 设计约束：**入口只负责启动，不承担任何具体任务**。
 * 所有初始化任务以「启动任务」为单位拆到 bootstrap 包下的独立类中，由 [AppBootstrap] 统一编排，
 * 新增 / 下线一个初始化动作只需在 AppBootstrap 的任务列表里增删一行，不在本类堆积逻辑。
 */
class PortenApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        AppBootstrap.run(this)
    }
}
