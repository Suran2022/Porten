/*
 * 我的日程业务模型（与后端 /api/v1/schedules 系列接口 JSON 严格一致）。
 *
 * 规范约束（同 PortenModels.kt）：
 *   1. 纯 Kotlin，禁止依赖 Android / UI 类型；
 *   2. kotlinx.serialization + @SerialName 显式标注 snake_case，禁止运行时猜测；
 *   3. 字段与 Web 端 mock 模型（MockSchedule）一个不多一个不少。
 */

package jys.porten.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 日程条目（对齐 MockSchedule，13 字段）。 */
@Serializable
public data class ScheduleItem(
    val id: Long,
    /** 日程日期，YYYY-MM-DD */
    val date: String,
    /** 开始时间，HH:mm */
    @SerialName("start_time") public val startTime: String,
    /** 结束时间，HH:mm；选填 */
    @SerialName("end_time") public val endTime: String? = null,
    /** 标题，选填 */
    val title: String? = null,
    /** 详情，选填 */
    val detail: String? = null,
    /** 分类：travel/date/visit/work/daily/study/other */
    val category: String? = null,
    /** 关联对象类型：trip / agreement */
    @SerialName("related_type") public val relatedType: String? = null,
    /** 关联对象 id */
    @SerialName("related_id") public val relatedId: Long? = null,
    /** 地点，选填 */
    val place: String? = null,
    /** 参与同胞的用户 id 列表 */
    @SerialName("participant_ids") public val participantIds: List<Long> = emptyList(),
    /** 卡片配色：pink / coffee / blue（创建时服务端随机分配） */
    val color: String,
    /** 创建来源：form / quick */
    val source: String,
)

/** 创建日程提交载荷（对齐 ScheduleCreatePayload）。 */
@Serializable
public data class ScheduleCreatePayload(
    val date: String,
    @SerialName("start_time") public val startTime: String,
    @SerialName("end_time") public val endTime: String? = null,
    val title: String? = null,
    val detail: String? = null,
    val category: String? = null,
    @SerialName("related_type") public val relatedType: String? = null,
    @SerialName("related_id") public val relatedId: Long? = null,
    val place: String? = null,
    @SerialName("participant_ids") public val participantIds: List<Long> = emptyList(),
    val source: String,
)

/** 更新日程提交载荷（PATCH 语义：仅传入字段覆盖）。 */
@Serializable
public data class ScheduleUpdatePayload(
    val date: String? = null,
    @SerialName("start_time") public val startTime: String? = null,
    @SerialName("end_time") public val endTime: String? = null,
    val title: String? = null,
    val detail: String? = null,
    val category: String? = null,
    @SerialName("related_type") public val relatedType: String? = null,
    @SerialName("related_id") public val relatedId: Long? = null,
    val place: String? = null,
    @SerialName("participant_ids") public val participantIds: List<Long>? = null,
    val source: String? = null,
)

/** 关联候选项（旅程 / 约定，对齐 MockRelatedItem）。 */
@Serializable
public data class ScheduleRelatedItem(
    val id: Long,
    val label: String,
)

/** 参与同胞候选（对齐 MockComrade）。 */
@Serializable
public data class ScheduleComradeItem(
    val id: Long,
    val nickname: String,
    val avatar: String? = null,
)

/** 关联数据与同胞候选集合（对齐 ScheduleRelatedData）。 */
@Serializable
public data class ScheduleRelatedData(
    val trips: List<ScheduleRelatedItem> = emptyList(),
    val agreements: List<ScheduleRelatedItem> = emptyList(),
    val comrades: List<ScheduleComradeItem> = emptyList(),
)

/** 日程列表响应 data 段。 */
@Serializable
public data class ScheduleListData(
    val items: List<ScheduleItem> = emptyList(),
)
