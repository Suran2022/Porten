"""System message service."""

import textwrap
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import SystemMessage, SystemMessageType, User, UserSystemMessageRead


# Built-in system messages that are synchronized on every startup.
# Update this list when deploying a new version.
SYSTEM_MESSAGES_SEED = [
    {
        "version": "v 0.1.0",
        "title": "新增系统消息页面",
        "content": "新增系统消息入口，可查看版本更新与问题修复公告；支持标记已读与一键全部已读。",
        "message_type": SystemMessageType.UPDATE.value,
    },
    {
        "version": "v 0.1.1",
        "title": "修复登录状态与首页列表预览问题",
        "content": "修复刷新页面后意外退回登录页的问题，登录成功后的 token 有效期保持 7 天；修复首页消息列表卡片未能正确显示最后一条最新消息内容的问题；系统消息入口调整回顶部栏邮箱图标。",
        "message_type": SystemMessageType.FIX.value,
    },
    {
        "version": "v 0.2.0",
        "title": "新增创建营地功能",
        "content": "首页 Plus 菜单新增组建营地入口，支持选择营地类型、完善营地资料并创建营地；创建成功后自动生成营地会话，并在聊天页面显示系统提示消息。",
        "message_type": SystemMessageType.UPDATE.value,
    },
    {
        "version": "v 0.2.1",
        "title": "营地号与营地搜索上线",
        "content": "创建营地时自动生成唯一营地号；首页加号菜单支持搜索营地，搜索结果根据营地可发现设置过滤，匹配关键词使用粉色高亮展示。",
        "message_type": SystemMessageType.UPDATE.value,
    },
    {
        "version": "v 0.2.2",
        "title": "MtF.wiki（跨儿说）组织上新啦！",
        "content": textwrap.dedent("""\
            亲爱的同胞们：
                    感谢大家对Porten一路走来的支持与陪伴，在Porten我们一起走过了129个日夜，陪伴着彼此不在黑夜里独自哭泣，这是我们携手共同对抗偏见与伤害的最好诠释。
                    对于大家在生活中遇到的困难，Porten也为大家积极寻找可靠的跨儿组织，让大家能够在遇到不公时有路可走，有心可靠！由于每个组织覆盖地区不一样，我们整理了不同地区跨儿组织的对接方法。
                     本次整理的跨儿组织是MtF.wiki（跨儿说）一个以跨性别女性为主要代表的跨儿组织，大家可以访问：https://mtf.wiki/zh-cn/docs/useful-info/organizations联系和预览组织的情况，同时也提供了丰富的医疗资源和MtF的一些交流渠道，也希望同胞们在遇到不公时勇敢的去面对，每一次对不公的反击，都是为自己和更多同胞们铺下的路！
                    我们的存在本身就是对恶意最大的反抗！🏳️‍⚧️
            """),
        "message_type": SystemMessageType.UPDATE.value,
        "is_custom_title": True,
    },
    {
        "version": "v 0.3.0",
        "title": "新增语音消息功能",
        "content": "聊天页面支持发送语音消息：长按底部语音按钮即可录音，松手自动发送；语音消息支持本地缓存、播放时波形动画，最长可录制 1 分 20 秒。",
        "message_type": SystemMessageType.UPDATE.value,
    },
    {
        "version": "v 0.4.0",
        "title": "新增情绪日记功能",
        "content": "现在可以记录自己的情绪日记啦！在首页新增情绪日记入口，支持选择心情标签（开心、平静、难过、焦虑、愤怒、疲惫、感恩、孤独、充满希望、迷茫），写下此刻的心情与故事，系统会自动保存历史日记并支持查看自己的情绪轨迹。",
        "message_type": SystemMessageType.UPDATE.value,
    },
    {
        "version": "v 0.5.0",
        "title": "新增全局搜索功能",
        "content": "首页顶部新增搜索入口，点击进入搜索页。支持按五个分类查找内容：同胞（按昵称 / Porten 账号）、营地（按名称 / 营地号）、文件、知识（文章 / 视频 / 分享）、图片。切到「全部」视图会按 同胞 → 营地 → 文件 → 知识 → 图片 的顺序聚合展示所有匹配结果，分类切换带平滑指示器动画。",
        "message_type": SystemMessageType.UPDATE.value,
    },
]


class SystemMessageService:
    """Service for system messages and per-user read state."""

    def seed_system_messages(self, db: Session) -> None:
        """Ensure built-in system messages exist in the database."""
        for item in SYSTEM_MESSAGES_SEED:
            exists = (
                db.query(SystemMessage)
                .filter_by(version=item["version"], is_active=True)
                .first()
            )
            if not exists:
                db.add(
                    SystemMessage(
                        version=item["version"],
                        title=item["title"],
                        content=item["content"],
                        message_type=item["message_type"],
                        is_custom_title=item.get("is_custom_title", False),
                        is_active=True,
                    )
                )
            else:
                exists.title = item["title"]
                exists.content = item["content"]
                exists.message_type = item["message_type"]
                exists.is_custom_title = item.get("is_custom_title", False)
        db.commit()

    def _get_read_state(
        self, db: Session, user_id: int, system_message_id: int
    ) -> UserSystemMessageRead:
        """Get or create the read state row for a user and message."""
        read_state = (
            db.query(UserSystemMessageRead)
            .filter_by(user_id=user_id, system_message_id=system_message_id)
            .first()
        )
        if not read_state:
            read_state = UserSystemMessageRead(
                user_id=user_id,
                system_message_id=system_message_id,
                is_read=False,
            )
            db.add(read_state)
            db.flush()
        return read_state

    def get_messages_for_user(
        self, db: Session, user: User
    ) -> dict:
        """Return all active system messages with the user's read state."""
        messages = (
            db.query(SystemMessage)
            .filter_by(is_active=True)
            .order_by(SystemMessage.created_at.desc())
            .all()
        )
        unread_count = 0
        result = []
        for msg in messages:
            read_state = self._get_read_state(db, user.id, msg.id)
            if not read_state.is_read:
                unread_count += 1
            result.append(
                {
                    "id": msg.id,
                    "version": msg.version,
                    "title": msg.title,
                    "content": msg.content,
                    "message_type": msg.message_type,
                    "is_custom_title": msg.is_custom_title,
                    "is_read": read_state.is_read,
                    "created_at": msg.created_at,
                }
            )
        return {"messages": result, "unread_count": unread_count}

    def get_unread_count(self, db: Session, user: User) -> int:
        """Return the number of unread active system messages for the user."""
        messages = (
            db.query(SystemMessage.id)
            .filter_by(is_active=True)
            .all()
        )
        message_ids = {m.id for m in messages}
        if not message_ids:
            return 0
        read_ids = {
            r.system_message_id
            for r in db.query(UserSystemMessageRead)
            .filter_by(user_id=user.id, is_read=True)
            .filter(UserSystemMessageRead.system_message_id.in_(message_ids))
            .all()
        }
        return len(message_ids - read_ids)

    def mark_as_read(self, db: Session, user: User, system_message_id: int) -> None:
        """Mark a single system message as read for the user."""
        read_state = self._get_read_state(db, user.id, system_message_id)
        if not read_state.is_read:
            read_state.is_read = True
            read_state.read_at = datetime.now(timezone.utc)
            db.commit()

    def mark_all_as_read(self, db: Session, user: User) -> None:
        """Mark all active system messages as read for the user."""
        messages = (
            db.query(SystemMessage.id)
            .filter_by(is_active=True)
            .all()
        )
        now = datetime.now(timezone.utc)
        for msg in messages:
            read_state = self._get_read_state(db, user.id, msg.id)
            if not read_state.is_read:
                read_state.is_read = True
                read_state.read_at = now
        db.commit()
