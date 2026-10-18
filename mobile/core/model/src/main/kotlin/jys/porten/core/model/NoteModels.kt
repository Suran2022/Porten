/*
 * 记笔记业务模型（与后端 /api/v1/notes 系列接口 JSON 严格一致）。
 *
 * 规范约束（同 PortenModels.kt）：
 *   1. 纯 Kotlin，禁止依赖 Android / UI 类型；
 *   2. kotlinx.serialization + @SerialName 显式标注 snake_case，禁止运行时猜测；
 *   3. 字段与 Web 端 mock 笔记（NoteItem）一个不多一个不少（5 字段）。
 */

package jys.porten.core.model

import kotlinx.serialization.Serializable

/** 笔记条目（对齐 NoteItem，5 字段）。 */
@Serializable
public data class NoteItem(
    val id: Long,
    /** 笔记正文 */
    val content: String,
    /** 展示时间：「今天 HH:mm」/「昨天 HH:mm」/「M月D日 HH:mm」（服务端派生） */
    val time: String,
    /** 标签（至多 4 个；缺省时服务端回退「随记」） */
    val tags: List<String> = emptyList(),
    /** 是否归档 */
    val archived: Boolean = false,
)

/** 创建 / 更新笔记提交载荷（PATCH 语义：仅传入字段覆盖）。 */
@Serializable
public data class NoteUpsertPayload(
    val content: String? = null,
    val tags: List<String>? = null,
    val archived: Boolean? = null,
)

/** 笔记列表响应 data 段。 */
@Serializable
public data class NoteListData(
    val items: List<NoteItem> = emptyList(),
)
