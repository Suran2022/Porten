# =============================================================================================
# Porten 发布包混淆规则
# =============================================================================================
# 目标：在「保证功能可用」的前提下，尽最大可能提高反编译后的阅读成本与二次注入成本。
# 分层思路：通用规则 → 框架/三方库维稳规则 → Porten 自身防护规则。
# =============================================================================================

# ---------------------------------------------------------------------------------------------
# 1. 通用
# ---------------------------------------------------------------------------------------------
# 保持行号信息用于还原崩溃堆栈（不保留源码文件名，泄露信息少、够用于排错）
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes InnerClasses,Signature,EnclosingMethod
-renamesourcefileattribute PortenSource

# 日志：发布包静态移除所有 android.util.Log 调用与 Porten 日志门面，双保险防止敏感信息外泄
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
-assumenosideeffects class jys.porten.core.common.log.AppLogger {
    public static void d(java.lang.String, java.lang.String);
    public static void i(java.lang.String, java.lang.String);
    public static void w(java.lang.String, java.lang.String, java.lang.Throwable);
    public static void e(java.lang.String, java.lang.String, java.lang.Throwable);
}

# 移除调试/校验性代码
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static void checkExpressionValueIsNotNull(...);
    public static void checkNotNullExpressionValue(java.lang.Object, java.lang.String);
}

# ---------------------------------------------------------------------------------------------
# 2. 模型与序列化（必须保留，否则运行时解析失败）
# ---------------------------------------------------------------------------------------------
-keepclassmembers class jys.porten.core.model.** { <fields>; }
-keepclassmembers class jys.porten.core.bridge.** { <fields>; }
# Kotlin 序列化编译器元数据
-keepattributes kotlinx.serialization.*
-keepclassmembers @kotlinx.serialization.Serializable class ** { *** Companion; }
-keepclasseswithmembers class ** { kotlinx.serialization.KSerializer serializer(...); }

# Kotlin 反射契约：data class 的 componentN 在未使用时会被移除，统一保留以稳定序列化和桥接
-keepclassmembers class jys.porten.core.model.** {
    public <init>(...);
    public java.lang.Object component*();
}

# ---------------------------------------------------------------------------------------------
# 3. Android 组件
# ---------------------------------------------------------------------------------------------
# Application / Activity 由系统反射创建，必须保留
-keep public class jys.porten.app.** extends android.app.Application
-keep public class jys.porten.app.** extends android.app.Activity
-keepnames class jys.porten.app.** { public void set*(***); }

# ---------------------------------------------------------------------------------------------
# 4. Flutter（混合产物）
# ---------------------------------------------------------------------------------------------
# Flutter 引擎通过 JNI 回调宿主，相关类不得混淆
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }

# ---------------------------------------------------------------------------------------------
# 5. OkHttp / Retrofit
# ---------------------------------------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keepclasseswithmembers class * { @retrofit2.http.* <methods>; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ---------------------------------------------------------------------------------------------
# 6. Porten 安全模块
# ---------------------------------------------------------------------------------------------
# 安全检测类被内联后难以维持独立的检测链路与可观测性，统一整类保留。
-keep class jys.porten.core.security.** { *; }

# ---------------------------------------------------------------------------------------------
# 7. 危险 API 兜底：禁止 R8 移除前置校验（避免优化掉防御性空判断带来的崩溃风险）
# ---------------------------------------------------------------------------------------------
-keepclassmembers class jys.porten.** {
    public static void check*(...);
    public static void require*(...);
}
