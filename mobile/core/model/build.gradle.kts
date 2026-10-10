/*
 * :core:model —— 跨层 / 跨端数据结构。
 *
 * 约束：只放纯数据模型（data class / enum / 值对象），
 *       不放任何 Android API 调用、不放任何业务逻辑。
 *       这样该模块可被 Flutter 侧同名 model 一对一映射，也可未来下沉到 KMP。
 */

plugins {
    alias(libs.plugins.porten.kotlin.library)
}
