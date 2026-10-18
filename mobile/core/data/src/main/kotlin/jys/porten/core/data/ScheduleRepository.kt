/*
 * 我的日程仓储：Mock / 真实 API 双通道。
 *
 * Mock 通道（[ScheduleMockEngine]）与 Flutter 侧 core/data/schedule_mock.dart
 * 的 ScheduleStore 行为逐条对齐：
 *   - 6 条种子数据，日期相对今天动态生成（-3 ~ +9 天）；
 *   - 创建随机分配 pink / coffee / blue（同 Web mockEngine）；
 *   - PATCH 语义：仅传入字段覆盖（含置空）；
 *   - 关联候选：旅程 3 条 / 约定 3 条 / 同胞 4 人。
 *
 * Live 通道走 :core:network 的 [PortenApiService]，异常不静默回退 Mock。
 */

package jys.porten.core.data

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import jys.porten.core.model.ScheduleComradeItem
import jys.porten.core.model.ScheduleCreatePayload
import jys.porten.core.model.ScheduleItem
import jys.porten.core.model.ScheduleRelatedData
import jys.porten.core.model.ScheduleRelatedItem
import jys.porten.core.model.ScheduleUpdatePayload
import jys.porten.core.network.PortenApiService
import kotlin.random.Random
import kotlinx.serialization.Serializable

/** 日程 Mock 引擎（线程安全的内存态，数据为合成数据，无真实用户信息）。 */
public object ScheduleMockEngine {

    private const val TAG: String = "ScheduleMockEngine"

    private val lock: Any = Any()

    private val dateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    private val items: MutableList<ScheduleItem> = mutableListOf()

    private var nextId: Long = 7L

    private val random: Random = Random.Default

    /** 当前全部日程（副本，按 date + start_time 升序，同后端排序）。 */
    public fun list(): List<ScheduleItem> = synchronized(lock) {
        seedIfEmpty()
        items.sortedWith(compareBy({ it.date }, { it.startTime }))
            .map { it.copy() }
    }

    /** 创建：随机三色之一，追加进列表。 */
    public fun create(payload: ScheduleCreatePayload): ScheduleItem =
        synchronized(lock) {
            seedIfEmpty()
            val color = listOf("pink", "coffee", "blue")[random.nextInt(3)]
            val item = ScheduleItem(
                id = nextId++,
                date = payload.date,
                startTime = payload.startTime,
                endTime = payload.endTime,
                title = payload.title,
                detail = payload.detail,
                category = payload.category,
                relatedType = payload.relatedType,
                relatedId = payload.relatedId,
                place = payload.place,
                participantIds = payload.participantIds,
                color = color,
                source = payload.source,
            )
            items += item
            item.copy()
        }

    /** 更新：PATCH 语义，仅传入字段覆盖（含置空）。 */
    public fun update(id: Long, payload: ScheduleUpdatePayload): ScheduleItem =
        synchronized(lock) {
            seedIfEmpty()
            val index = items.indexOfFirst { it.id == id }
            require(index >= 0) { "schedule not found" }
            val current = items[index]
            val updated = current.copy(
                date = payload.date ?: current.date,
                startTime = payload.startTime ?: current.startTime,
                endTime = payload.endTime ?: current.endTime,
                title = payload.title ?: current.title,
                detail = payload.detail ?: current.detail,
                category = payload.category ?: current.category,
                relatedType = payload.relatedType ?: current.relatedType,
                relatedId = payload.relatedId ?: current.relatedId,
                place = payload.place ?: current.place,
                participantIds = payload.participantIds ?: current.participantIds,
                source = payload.source ?: current.source,
            )
            items[index] = updated
            updated.copy()
        }

    /** 关联候选（旅程 3 条 / 约定 3 条 / 同胞 4 人，与 Dart mock 对齐）。 */
    public fun related(): ScheduleRelatedData = synchronized(lock) {
        ScheduleRelatedData(
            trips = listOf(
                ScheduleRelatedItem(1, "上海 → 北京 · 10月12日"),
                ScheduleRelatedItem(2, "广州 → 成都 · 11月3日"),
                ScheduleRelatedItem(3, "杭州 → 厦门 · 12月20日"),
            ),
            agreements = listOf(
                ScheduleRelatedItem(1, "每周三线上互助会"),
                ScheduleRelatedItem(2, "一起坚持晨间记录 21 天"),
                ScheduleRelatedItem(3, "月末同城聚会筹备"),
            ),
            comrades = listOf(
                ScheduleComradeItem(1003, "小雨", "assets/mock_avatars/friend_lin_wanqing.jpg"),
                ScheduleComradeItem(1005, "陈默", "assets/mock_avatars/friend_chen_yutong.jpg"),
                ScheduleComradeItem(1011, "领队", "assets/mock_avatars/friend_fu_juan.jpg"),
                ScheduleComradeItem(1014, "Luna", "assets/mock_avatars/friend_zhou_shihan.jpg"),
            ),
        )
    }

    /** 生成相对今天偏移 n 天的 YYYY-MM-DD（同 Dart dateKeyFromToday）。 */
    private fun dateKeyFromToday(dayOffset: Long): String =
        LocalDate.now().plusDays(dayOffset).format(dateFormatter)

    /** 种子数据（同 kMockSchedules，日期动态生成，保证任意时间打开都有演示）。 */
    private fun seedIfEmpty() {
        if (items.isNotEmpty()) return
        items += ScheduleItem(
            id = 1,
            date = dateKeyFromToday(0),
            startTime = "14:00",
            endTime = "15:30",
            title = "下午茶之约",
            detail = "和老朋友约在常去的那家店，聊聊最近的状态。",
            category = "date",
            relatedType = "agreement",
            relatedId = 1,
            place = "甜遇·社区茶店",
            participantIds = listOf(1003),
            color = "pink",
            source = "form",
        )
        items += ScheduleItem(
            id = 2,
            date = dateKeyFromToday(0),
            startTime = "19:00",
            endTime = null,
            title = null,
            detail = "沿着江边慢跑，顺便试试新买的运动手环。",
            category = "daily",
            relatedType = null,
            relatedId = null,
            place = null,
            participantIds = emptyList(),
            color = "blue",
            source = "quick",
        )
        items += ScheduleItem(
            id = 3,
            date = dateKeyFromToday(2),
            startTime = "09:30",
            endTime = "10:30",
            title = "心理咨询",
            detail = null,
            category = "visit",
            relatedType = null,
            relatedId = null,
            place = "北岸心理诊所",
            participantIds = emptyList(),
            color = "coffee",
            source = "form",
        )
        items += ScheduleItem(
            id = 4,
            date = dateKeyFromToday(5),
            startTime = "18:30",
            endTime = "21:00",
            title = "和同胞看电影",
            detail = "一起看新上映的音乐纪录片，散场后吃宵夜。",
            category = "date",
            relatedType = null,
            relatedId = null,
            place = "城南光影影城",
            participantIds = listOf(1014, 1005),
            color = "pink",
            source = "form",
        )
        items += ScheduleItem(
            id = 5,
            date = dateKeyFromToday(9),
            startTime = "10:00",
            endTime = "11:00",
            title = "激素复查",
            detail = "记得空腹，带上上次的检查单。",
            category = "visit",
            relatedType = null,
            relatedId = null,
            place = "市第三人民医院",
            participantIds = emptyList(),
            color = "coffee",
            source = "form",
        )
        items += ScheduleItem(
            id = 6,
            date = dateKeyFromToday(-3),
            startTime = "20:00",
            endTime = "21:30",
            title = "小组分享会",
            detail = null,
            category = "other",
            relatedType = null,
            relatedId = null,
            place = null,
            participantIds = emptyList(),
            color = "blue",
            source = "form",
        )
    }
}

/** 我的日程仓储。 */
public class ScheduleRepository(
    modeProvider: () -> DataSourceMode,
    private val api: PortenApiService,
) : PortenRepository<ScheduleRepository.ScheduleBoard>(modeProvider) {

    /** 日程页一次性所需数据：列表 + 关联候选。 */
    @Serializable
    public data class ScheduleBoard(
        val items: List<ScheduleItem>,
        val related: ScheduleRelatedData,
    )

    override suspend fun fetchLive(): ScheduleBoard = ScheduleBoard(
        items = api.listSchedules().unwrap().items,
        related = api.scheduleRelated().unwrap(),
    )

    override suspend fun fetchMock(): ScheduleBoard = ScheduleBoard(
        items = ScheduleMockEngine.list(),
        related = ScheduleMockEngine.related(),
    )

    /** 创建日程（双通道分发）。 */
    public suspend fun create(payload: ScheduleCreatePayload): ScheduleItem = dispatch(
        live = { api.createSchedule(payload).unwrap() },
        mock = { ScheduleMockEngine.create(payload) },
    )

    /** 更新日程（PATCH 语义，双通道分发）。 */
    public suspend fun update(id: Long, payload: ScheduleUpdatePayload): ScheduleItem =
        dispatch(
            live = { api.updateSchedule(id, payload).unwrap() },
            mock = { ScheduleMockEngine.update(id, payload) },
        )
}
