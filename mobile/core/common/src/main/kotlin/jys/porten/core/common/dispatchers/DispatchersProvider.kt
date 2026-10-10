package jys.porten.core.common.dispatchers

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers

/**
 * 协程调度器抽象。
 *
 * 之所以不直接使用 [Dispatchers]：单测需要用测试调度器替换真实线程池，
 * 通过构造注入的方式才能让 ViewModel / Repository 的测试确定性地跑完。
 *
 * 线程规程（此处集中约定，全项目遵守）：
 *   - UI 更新           → [DispatchersProvider.main]
 *   - 网络 / 文件 IO    → [DispatchersProvider.io]
 *   - 加解密 / 排序 / JSON 解析等 CPU 密集 → [DispatchersProvider.default]
 */
public interface DispatchersProvider {

    public val io: CoroutineDispatcher
    public val main: CoroutineDispatcher
    public val default: CoroutineDispatcher
}

/** 生产实现：直接使用 Kotlin 标准调度器。 */
public data object DefaultDispatchersProvider : DispatchersProvider {
    override val io: CoroutineDispatcher get() = Dispatchers.IO
    override val main: CoroutineDispatcher get() = Dispatchers.Main
    override val default: CoroutineDispatcher get() = Dispatchers.Default
}
