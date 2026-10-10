/*
 * 运行时安全防护。
 *
 * 背景：Porten 面向跨性别人群，用户身份高度敏感。除构建期加固（R8 full mode /
 * ProGuard / 证书绑定，见 app/proguard-rules.pro 与 network_security_config.xml）外，
 * 运行期还需主动检测高危环境，在受控场景下降低信息暴露与动态注入风险。
 *
 * 设计原则（防御性编程）：
 *   1. 检测结果只上报「风险信号」，由宿主壳决定策略（降级/弹窗/静默），检测层不做处置，
 *      避免「误杀」导致正常用户无法使用；
 *   2. 全部检测必须幂等、无副作用、不抛异常（检测代码自身崩溃 = 攻击面）；
 *   3. dev flavor 可整体关闭（ENABLE_SECURITY=false），staging/prod 默认开启。
 */

package jys.porten.core.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build

/** 运行时风险信号集合。 */
public class RuntimeRiskReport(
    /** 设备已 root / 检测到 su 可执行文件。 */
    public val rooted: Boolean,
    /** 应用处于可调试模式（android:debuggable 或 ptrace 附加可能）。 */
    public val debuggable: Boolean,
    /** 检测到运行于模拟器。 */
    public val emulator: Boolean,
) {
    /** 是否存在任意风险信号。 */
    public val hasRisk: Boolean
        get() = rooted || debuggable || emulator

    public override fun toString(): String =
        "RuntimeRiskReport(rooted=$rooted, debuggable=$debuggable, emulator=$emulator)"
}

/** 运行时安全检测器（纯静态工具，无状态）。 */
public object SecurityGuard {

    // ------------------------------ root 检测 ------------------------------

    /** 常见 su / 特权二进制路径（社区通用清单）。 */
    private val SU_PATHS: List<String> = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/sd/xbin/su",
        "/system/bin/failsafe/su", "/data/local/xbin/su", "/data/local/bin/su",
        "/data/local/su", "/su/bin/su",
    )

    /** 常见 root 管理类 App 包名。 */
    private val ROOT_PACKAGES: List<String> = listOf(
        "com.topjohnwu.magisk", "eu.chainfire.supersu", "com.noshufou.android.su",
        "com.koushikdutta.superuser", "com.thirdparty.superuser",
    )

    public fun isRooted(context: Context): Boolean {
        val pm = context.applicationContext.packageManager
        val hasSuBinary = SU_PATHS.any { path ->
            runCatching { java.io.File(path).exists() }.getOrDefault(false)
        }
        val hasRootApp = runCatching {
            ROOT_PACKAGES.any { pkg ->
                runCatching { pm.getPackageInfo(pkg, 0) }.isSuccess
            }
        }.getOrDefault(false)
        return hasSuBinary || hasRootApp
    }

    // ------------------------------ 调试检测 ------------------------------

    public fun isDebuggable(context: Context): Boolean =
        runCatching {
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        }.getOrDefault(false)

    /** Debug 包永远可调试，此检测只对 release 包有意义。 */
    public fun isDebuggerAttached(): Boolean =
        runCatching { android.os.Debug.isDebuggerConnected() }
            .getOrDefault(false)

    // ------------------------------ 模拟器检测 ------------------------------

    private val EMULATOR_FINGERPRINT_KEYS: List<String> = listOf(
        "generic", "sdk_gphone", "emulator", "google_sdk",
    )

    public fun isEmulator(): Boolean = runCatching {
        val fp = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        (EMULATOR_FINGERPRINT_KEYS.any { fp.contains(it) || model.contains(it) }) ||
            Build.HARDWARE.contains("goldfish") ||
            Build.PRODUCT.contains("vbox")
    }.getOrDefault(false)

    // ------------------------------ 汇总 ------------------------------

    /** 执行全套检测，生成风险报告。永不抛异常。 */
    public fun inspect(context: Context): RuntimeRiskReport = RuntimeRiskReport(
        rooted = isRooted(context),
        debuggable = isDebuggable(context),
        emulator = isEmulator(),
    )
}
