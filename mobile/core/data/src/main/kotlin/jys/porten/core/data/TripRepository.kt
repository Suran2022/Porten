/*
 * 我的旅程仓储：Mock / 真实 API 双通道。
 *
 * Mock 通道（[TripMockEngine]）与 Flutter 侧行程页 mock（trip_page.dart 的
 * _kTripItems + 新建的 trip_store.dart）逐条对齐：
 *   - 3 条种子旅程（广州→大连 / 大连→东京 / 东京→旧金山）；
 *   - 创建时按出发日期派生标题（「N天后将前往X」/「明天将前往X」/「今天将前往X」）
 *     与提醒文案（出发倒计时，天气未配置时只有倒计时，同后端降级策略）。
 *
 * Live 通道走 :core:network 的 [PortenApiService]：标题 / 提醒 / 航司图标
 * 均由服务端派生，端上只展示，异常不静默回退 Mock。
 */

package jys.porten.core.data

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import jys.porten.core.model.TripAssistantCard
import jys.porten.core.model.TripCreatePayload
import jys.porten.core.model.TripItem
import jys.porten.core.network.PortenApiService
import kotlinx.serialization.Serializable

/** 航司名 → 品牌图标资产路径（与 Web/Flutter 端图标资源一一对应）。 */
private val AIRLINE_ICONS: Map<String, String> = mapOf(
    "四川航空" to "assets/icons/airline-sichuan.svg",
    "东方航空" to "assets/icons/airline-eastern.svg",
    "中国航空" to "assets/icons/airline-china.svg",
    "瑞丽航空" to "assets/icons/airline-ruili.svg",
    "南方航空" to "assets/icons/airline-southern.svg",
    "法国航空" to "assets/icons/airline-france.svg",
    "厦门航空" to "assets/icons/airline-xiamen.svg",
    "春秋航空" to "assets/icons/airline-spring.svg",
    "吉祥航空" to "assets/icons/airline-juneyao.svg",
    "大韩航空" to "assets/icons/airline-korean.svg",
    "山东航空" to "assets/icons/airline-shandong.svg",
)

/** 旅程 Mock 引擎（线程安全内存态，合成数据）。 */
public object TripMockEngine {

    private val lock: Any = Any()

    private val timeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    private val items: MutableList<TripItem> = mutableListOf()

    /** 当前全部旅程（副本，按出发时间排序由创建顺序保证）。 */
    public fun list(): List<TripItem> = synchronized(lock) {
        seedIfEmpty()
        items.map { it.copy() }
    }

    /** 创建旅程：标题与提醒由端上按与后端相同的规则派生（mock 通道自洽）。 */
    public fun create(payload: TripCreatePayload): TripItem = synchronized(lock) {
        seedIfEmpty()
        val departureAt = OffsetDateTime.parse(payload.departureAt).toLocalDateTime()
        val arrivalAt = payload.arrivalAt
            ?.let { runCatching { OffsetDateTime.parse(it).toLocalDateTime() }.getOrNull() }
        val item = TripItem(
            title = buildTitle(departureAt, payload.arrivalCity),
            departureCity = payload.departureCity,
            departureAirport = payload.departureAirport,
            departureTime = departureAt.format(timeFormatter),
            arrivalCity = payload.arrivalCity,
            arrivalAirport = payload.arrivalAirport,
            arrivalTime = arrivalAt?.format(timeFormatter),
            transferType = payload.transferType,
            airline = payload.airline,
            airlineIcon = AIRLINE_ICONS[payload.airline].orEmpty(),
            tips = buildTips(departureAt, payload.arrivalCity),
        )
        items += item
        item.copy()
    }

    /** 「我的旅程」入口卡片（mock：种子旅程全部计为即将出发）。 */
    public fun assistantCard(): TripAssistantCard = synchronized(lock) {
        seedIfEmpty()
        TripAssistantCard(
            count = items.size,
            lastMessage = items.firstOrNull()?.let {
                "您有一条在${it.title.substringBefore("将前往")}前往${it.arrivalCity}的旅程"
            },
        )
    }

    /** 卡片标题：今天 / 明天 / N天后将前往X。 */
    private fun buildTitle(departureAt: LocalDateTime, arrivalCity: String): String {
        val days = ChronoUnit.DAYS.between(LocalDate.now(), departureAt.toLocalDate())
        val prefix = when {
            days <= 0 -> "今天"
            days == 1L -> "明天"
            else -> "${days}天后"
        }
        return "${prefix}将前往${arrivalCity}"
    }

    /** 提醒文案：出发倒计时（mock 无天气数据源，与后端 NullWeatherProvider 降级一致）。 */
    private fun buildTips(departureAt: LocalDateTime, arrivalCity: String): String? {
        val now = LocalDateTime.now()
        if (!departureAt.isAfter(now)) return null
        val days = ChronoUnit.DAYS.between(now.toLocalDate(), departureAt.toLocalDate())
        return if (days >= 1) {
            "还有${days}天飞往${arrivalCity}"
        } else {
            val hours = ChronoUnit.HOURS.between(now, departureAt).coerceAtLeast(1)
            "还有${hours}小时飞往${arrivalCity}"
        }
    }

    private fun seedIfEmpty() {
        if (items.isNotEmpty()) return
        items += TripItem(
            title = "2天后将前往大连",
            departureCity = "广州",
            departureAirport = "白云机场",
            departureTime = "08:35",
            arrivalCity = "大连",
            arrivalAirport = "周水子机场",
            arrivalTime = "12:05",
            transferType = "直达",
            airline = "四川航空",
            airlineIcon = "assets/icons/airline-sichuan.svg",
            tips = "两天后可进行线上选座，当天有雨，注意带伞哦！",
        )
        items += TripItem(
            title = "7天后将前往东京",
            departureCity = "大连",
            departureAirport = "周水子机场",
            departureTime = "09:30",
            arrivalCity = "东京",
            arrivalAirport = "羽田机场",
            arrivalTime = "13:00",
            transferType = "直达",
            airline = "东方航空",
            airlineIcon = "assets/icons/airline-eastern.svg",
            tips = "请注意日本签证，注意出行安全！",
        )
        items += TripItem(
            title = "12天后将前往旧金山",
            departureCity = "东京",
            departureAirport = "羽田机场",
            departureTime = "17:10",
            arrivalCity = "旧金山",
            arrivalAirport = "旧金山国际机场",
            arrivalTime = "10:30",
            transferType = "中转",
            airline = "中国航空",
            airlineIcon = "assets/icons/airline-china.svg",
            tips = "请注意美国签证，注意出行安全！",
        )
    }
}

/** 我的旅程仓储。 */
public class TripRepository(
    modeProvider: () -> DataSourceMode,
    private val api: PortenApiService,
) : PortenRepository<TripRepository.TripBoard>(modeProvider) {

    /** 旅程页 + 入口卡片一次性所需数据。 */
    @Serializable
    public data class TripBoard(
        val items: List<TripItem>,
        val assistant: TripAssistantCard,
    )

    override suspend fun fetchLive(): TripBoard = TripBoard(
        items = api.listTrips().unwrap().items,
        assistant = api.tripAssistantCard().unwrap(),
    )

    override suspend fun fetchMock(): TripBoard = TripBoard(
        items = TripMockEngine.list(),
        assistant = TripMockEngine.assistantCard(),
    )

    /** 创建旅程（标题 / 提醒 / 图标在 Live 通道由服务端派生）。 */
    public suspend fun create(payload: TripCreatePayload): TripItem = dispatch(
        live = { api.createTrip(payload).unwrap() },
        mock = { TripMockEngine.create(payload) },
    )
}
