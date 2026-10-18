/*
 * 旅程业务模型（与后端 /api/v1/trips 系列接口 JSON 严格一致）。
 *
 * 规范约束（同 PortenModels.kt）：
 *   1. 纯 Kotlin，禁止依赖 Android / UI 类型；
 *   2. kotlinx.serialization + @SerialName 显式标注 snake_case，禁止运行时猜测；
 *   3. 字段与 Web 端 mock 行程卡片（TripItem）一个不多一个不少（11 字段）。
 */

package jys.porten.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 旅程卡片（对齐 TripItem，11 字段）。 */
@Serializable
public data class TripItem(
    /** 卡片标题，如「2天后将前往大连」（服务端派生） */
    val title: String,
    @SerialName("departure_city") public val departureCity: String,
    @SerialName("departure_airport") public val departureAirport: String,
    /** 出发时刻，HH:mm（服务端按展示时区派生） */
    @SerialName("departure_time") public val departureTime: String,
    @SerialName("arrival_city") public val arrivalCity: String,
    @SerialName("arrival_airport") public val arrivalAirport: String,
    /** 到达时刻，HH:mm；选填 */
    @SerialName("arrival_time") public val arrivalTime: String? = null,
    /** 航段类型：直达 / 中转 */
    @SerialName("transfer_type") public val transferType: String,
    /** 航司名称 */
    val airline: String,
    /** 航司品牌图标资产路径（服务端按航司映射派生） */
    @SerialName("airline_icon") public val airlineIcon: String,
    /** 卡片下方提醒（出发倒计时 + 天气，服务端派生）；选填 */
    val tips: String? = null,
)

/** 创建旅程提交载荷（创建表单字段：出发/到达城市机场、出发时间、航司）。 */
@Serializable
public data class TripCreatePayload(
    @SerialName("departure_city") public val departureCity: String,
    @SerialName("departure_airport") public val departureAirport: String,
    /** 出发日期时间，ISO-8601（含时刻） */
    @SerialName("departure_at") public val departureAt: String,
    @SerialName("arrival_city") public val arrivalCity: String,
    @SerialName("arrival_airport") public val arrivalAirport: String,
    /** 到达日期时间，ISO-8601；选填 */
    @SerialName("arrival_at") public val arrivalAt: String? = null,
    @SerialName("transfer_type") public val transferType: String = "直达",
    val airline: String,
)

/** 旅程列表响应 data 段。 */
@Serializable
public data class TripListData(
    val items: List<TripItem> = emptyList(),
)

/**
 * 消息列表「我的旅程」入口卡片（对齐 TripAssistantCard）。
 *
 * [lastMessage] 为最新旅程摘要（端上拼接「[行程助手]：」前缀，同 mock）。
 */
@Serializable
public data class TripAssistantCard(
    val count: Int,
    @SerialName("last_message") public val lastMessage: String? = null,
)
