/*
 * 安全存储：基于 Android Keystore 的加密 KV。
 *
 * 威胁模型（面向敏感身份用户）：
 *   - token、用户身份字段等若以明文 SharedPreferences 落盘，
 *     root 设备 / ADB backup / 云备份均可直接读取；
 *   - 本模块以 EncryptedSharedPreferences（AES256-GCM + Keystore 硬件密钥）承载敏感 KV；
 *   - app 级 allowBackup=false 与 dataExtractionRules 已从系统层封死备份通道。
 */

package jys.porten.core.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import jys.porten.core.common.log.AppLogger

/** 安全存储契约（可注入 Fake 便于单测）。 */
public interface SecureStore {
    public fun getString(key: String): String?
    public fun putString(key: String, value: String)
    public fun remove(key: String)
    public fun clear()
}

/** EncryptedSharedPreferences 实现。 */
public class KeystoreSecureStore private constructor(
    private val prefs: SharedPreferences,
) : SecureStore {

    public companion object {
        private const val TAG: String = "SecureStore"
        private const val FILE_NAME: String = "porten_secure_prefs"

        /** 工厂方法：Keystore 初始化失败时降级为内存实现（绝不崩溃、绝不明文落盘）。 */
        public fun create(context: Context): SecureStore = runCatching {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            val prefs = EncryptedSharedPreferences.create(
                context,
                FILE_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
            KeystoreSecureStore(prefs)
        }.getOrElse { error ->
            AppLogger.e(TAG, "Keystore 初始化失败，降级为内存存储（数据不落盘）: ${error.message}")
            InMemorySecureStore()
        }
    }

    override fun getString(key: String): String? =
        runCatching { prefs.getString(key, null) }.getOrNull()

    override fun putString(key: String, value: String) {
        runCatching { prefs.edit().putString(key, value).apply() }
            .onFailure { AppLogger.e(TAG, "写入失败: $key") }
    }

    override fun remove(key: String) {
        runCatching { prefs.edit().remove(key).apply() }
    }

    override fun clear() {
        runCatching { prefs.edit().clear().apply() }
    }
}

/** 内存实现：Keystore 不可用时的降级载体 + 单测 Fake。 */
public class InMemorySecureStore : SecureStore {
    private val map: MutableMap<String, String> = mutableMapOf()

    override fun getString(key: String): String? = map[key]
    override fun putString(key: String, value: String) {
        map[key] = value
    }

    override fun remove(key: String) {
        map.remove(key)
    }

    override fun clear() = map.clear()
}
