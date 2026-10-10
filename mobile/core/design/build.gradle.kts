/*
 * :core:design —— 设计令牌（Design Tokens）唯一出口。
 *
 * 承载：品牌色（跨性别旗帜色系）、字阶、间距、圆角、动效时长、渐变。
 * 原则：所有取值必须与 React Web 端 100% 一致；此处是原生侧唯一允许定义视觉常量的地方，
 *       其它模块禁止硬编码颜色与尺寸（硬编码 = 无法通过一次改动完成全端换肤）。
 */

plugins {
    alias(libs.plugins.porten.android.library)
    alias(libs.plugins.porten.android.compose)
}

android {
    namespace = "jys.porten.core.design"
}
