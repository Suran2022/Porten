/*
 * 记笔记仓储：Mock / 真实 API 双通道。
 *
 * Mock 通道（[NoteMockEngine]）与 Flutter 侧 core/data/notes_mock.dart 对齐：
 *   - 11 条种子笔记（time 为展示标签，同 Dart 常量）；
 *   - 标签切分（、,，空白）至多 4 个、去重；新建缺省回退「随记」；
 *   - 编辑刷新 time 标签（今天 / 昨天 / M月D日 HH:mm）；
 *   - 归档翻转与删除。
 *
 * Live 通道走 :core:network 的 [PortenApiService]（同样的归一化由服务端执行），
 * 异常不静默回退 Mock。
 */

package jys.porten.core.data

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import jys.porten.core.model.NoteItem
import jys.porten.core.model.NoteUpsertPayload
import jys.porten.core.network.PortenApiService
import kotlinx.serialization.Serializable

/** 笔记 Mock 引擎（线程安全内存态，合成数据）。 */
public object NoteMockEngine {

    private val lock: Any = Any()

    private val tagSplit: Regex = Regex("[、,，\\s]+")

    private const val MAX_TAGS: Int = 4

    private const val FALLBACK_TAG: String = "随记"

    private val items: MutableList<NoteItem> = mutableListOf()

    private var nextId: Long = 12L

    /** 当前全部笔记（副本，新到旧）。 */
    public fun list(): List<NoteItem> = synchronized(lock) {
        seedIfEmpty()
        items.map { it.copy() }
    }

    /** 创建：空标签回退「随记」。 */
    public fun create(payload: NoteUpsertPayload): NoteItem = synchronized(lock) {
        seedIfEmpty()
        val item = NoteItem(
            id = nextId++,
            content = payload.content.orEmpty(),
            time = currentTimeLabel(),
            tags = normalizeTags(payload.tags, fallback = true),
            archived = false,
        )
        items.add(0, item)
        item.copy()
    }

    /** 更新：PATCH 语义，仅传入字段覆盖（含置空标签）。 */
    public fun update(id: Long, payload: NoteUpsertPayload): NoteItem =
        synchronized(lock) {
            seedIfEmpty()
            val index = items.indexOfFirst { it.id == id }
            require(index >= 0) { "note not found" }
            val current = items[index]
            val updated = current.copy(
                content = payload.content ?: current.content,
                tags = payload.tags?.let { normalizeTags(it, fallback = false) }
                    ?: current.tags,
                archived = payload.archived ?: current.archived,
                time = currentTimeLabel(),
            )
            items[index] = updated
            updated.copy()
        }

    /** 删除。 */
    public fun delete(id: Long): Unit = synchronized(lock) {
        seedIfEmpty()
        items.removeAll { it.id == id }
    }

    /** 标签归一化：切分 / 去重 / 至多 4 个；fallback 控制新建空标签回退。 */
    private fun normalizeTags(tags: List<String>?, fallback: Boolean): List<String> {
        val normalized = mutableListOf<String>()
        for (tag in tags.orEmpty()) {
            for (part in tagSplit.split(tag)) {
                val trimmed = part.trim()
                if (trimmed.isNotEmpty() && trimmed !in normalized) {
                    normalized += trimmed
                }
            }
        }
        val limited = normalized.take(MAX_TAGS)
        return if (fallback && limited.isEmpty()) listOf(FALLBACK_TAG) else limited
    }

    /** time 展示标签：今天 HH:mm / 昨天 HH:mm / M月D日 HH:mm。 */
    private fun currentTimeLabel(): String {
        val now = LocalDateTime.now()
        val today = LocalDate.now()
        val hm = now.format(DateTimeFormatter.ofPattern("HH:mm"))
        return when (now.toLocalDate()) {
            today -> "今天 $hm"
            today.minusDays(1) -> "昨天 $hm"
            else -> "${now.monthValue}月${now.dayOfMonth}日 $hm"
        }
    }

    private fun seedIfEmpty() {
        if (items.isNotEmpty()) return
        items += NoteItem(
            id = 1,
            content = "今天把消息列表的交互流程重新梳理了一遍。优先让核心路径保持简单，再逐步补充细节和反馈。",
            time = "今天 10:24",
            tags = listOf("工作", "灵感"),
        )
        items += NoteItem(
            id = 2,
            content = "周末想去城南的植物园走走，带上相机，顺便记录春天刚长出来的新叶和傍晚的光。",
            time = "昨天 21:16",
            tags = listOf("生活", "计划"),
        )
        items += NoteItem(
            id = 3,
            content = "产品细节：动画不只是装饰，它应该帮助用户理解页面之间的空间关系，进入和退出必须保持方向一致。",
            time = "7月30日 16:08",
            tags = listOf("设计", "产品"),
        )
        items += NoteItem(
            id = 4,
            content = "最近循环播放的歌单很适合夜晚写东西。舒缓的节奏能让思绪慢下来，也更容易专注。",
            time = "7月28日 23:42",
            tags = listOf("音乐", "日常"),
        )
        items += NoteItem(
            id = 5,
            content = "下次社区分享会可以讨论如何建立更安全的表达空间，让每个人都能被认真倾听和温柔回应。",
            time = "7月26日 14:30",
            tags = listOf("社区", "想法"),
        )
        items += NoteItem(
            id = 6,
            content = "阅读摘录：真正的勇敢并不是从不害怕，而是在理解自己的害怕之后，仍然愿意向前走一步。",
            time = "7月24日 09:12",
            tags = listOf("阅读", "摘录"),
        )
        items += NoteItem(
            id = 7,
            content = "体检需要准备的材料：身份证、预约单、既往检查报告。提前半小时出门，避免早高峰。",
            time = "7月22日 18:05",
            tags = listOf("健康", "待办"),
        )
        items += NoteItem(
            id = 8,
            content = "新功能的颜色尽量降低饱和度，蓝色与粉色不要直接硬切，用更大的渐变半径自然融入白色背景。",
            time = "7月20日 11:47",
            tags = listOf("设计", "灵感"),
        )
        items += NoteItem(
            id = 9,
            content = "给未来的自己：不需要急着证明什么，按照自己的节奏生活，每一次认真选择都算数。",
            time = "7月18日 22:19",
            tags = listOf("心情", "给自己"),
        )
        items += NoteItem(
            id = 10,
            content = "会议记录：先完成移动端消息体验，再统一桌面端布局；测试阶段重点关注弱网和离线状态。",
            time = "7月16日 15:36",
            tags = listOf("工作", "会议"),
        )
        items += NoteItem(
            id = 11,
            content = "想学着做一道简单的番茄炖牛腩，少放一点糖，最后加几颗烤过的小番茄增加香气。",
            time = "7月14日 12:04",
            tags = listOf("生活", "美食"),
        )
    }
}

/** 记笔记仓储。 */
public class NoteRepository(
    modeProvider: () -> DataSourceMode,
    private val api: PortenApiService,
) : PortenRepository<NoteRepository.NoteBoard>(modeProvider) {

    /** 笔记页一次性所需数据。 */
    @Serializable
    public data class NoteBoard(
        val items: List<NoteItem>,
    )

    override suspend fun fetchLive(): NoteBoard = NoteBoard(
        items = api.listNotes().unwrap().items,
    )

    override suspend fun fetchMock(): NoteBoard = NoteBoard(
        items = NoteMockEngine.list(),
    )

    /** 创建笔记。 */
    public suspend fun create(payload: NoteUpsertPayload): NoteItem = dispatch(
        live = { api.createNote(payload).unwrap() },
        mock = { NoteMockEngine.create(payload) },
    )

    /** 更新笔记（PATCH 语义）。 */
    public suspend fun update(id: Long, payload: NoteUpsertPayload): NoteItem =
        dispatch(
            live = { api.updateNote(id, payload).unwrap() },
            mock = { NoteMockEngine.update(id, payload) },
        )

    /** 删除笔记。 */
    public suspend fun delete(id: Long): Unit = dispatch(
        live = { api.deleteNote(id).unwrap(); Unit },
        mock = { NoteMockEngine.delete(id) },
    )
}
