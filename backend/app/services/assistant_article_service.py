"""Assistant article service.

数据流：
- 助手 / 文章元信息存放在 MySQL（assistant_articles 表）。
- 文章正文以 markdown 文件存放在 `app/data/articles/{slug}.md`，
  通过 slug 字段在文件系统定位。读取正文时按 UTF-8 读取，
  内容由前端用 `react-markdown` 渲染。
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.models import (
    AssistantArticle,
    UserAssistantArticleRead,
)

# 助手目录：直接挂在前端的 portenAssistants 静态配置，
# 新增助手时需要在这里追加。
@dataclass(frozen=True)
class AssistantInfo:
    id: str
    name: str
    avatar: Optional[str]
    bio: Optional[str]


ASSISTANTS: List[AssistantInfo] = [
    AssistantInfo(
        id="qin_xiaoxu",
        name="情小绪",
        avatar=None,
        bio="Porten 官方助手 · 通知公告 / 版本动态 / 安全提醒",
    ),
]

# markdown 文件根目录（相对 app 包根）
ARTICLES_DIR = Path(__file__).resolve().parent.parent / "data" / "articles"

# 启动时 / 首次访问时同步进数据库的文章种子
SEED_ARTICLES: List[Dict] = [
    {
        "assistant_id": "qin_xiaoxu",
        "slug": "001-talk-to-family",
        "title": "怎么跟家人聊自己的性别认同",
        "summary": (
            "如果你心里藏着一个小小的、大大的秘密，想要跟最亲的人分享，"
            "却又不知道该怎么开口，这篇文章像朋友一样陪你慢慢理一理思路 🌈"
        ),
        "publish_time": datetime(2026, 7, 22, 9, 0, 0),
        "publisher": "Porten 官方",
    },
]


def read_markdown(slug: str) -> str:
    """读取指定 slug 的 markdown 文件内容。

    - 文件不存在：返回空字符串（前端按"暂无内容"展示）。
    - 文件读取异常：抛 RuntimeError，由路由层转 500。
    """
    path = ARTICLES_DIR / f"{slug}.md"
    if not path.exists():
        return ""
    with open(path, "r", encoding="utf-8") as fp:
        return fp.read()


class AssistantArticleService:
    """助手 / 文章读取相关业务。"""

    # ===== 助手 =====

    def list_assistants(self, db: Session, user_id: int) -> List[Dict]:
        """返回所有助手，附带每个助手的文章总数与当前用户未读数。"""
        result: List[Dict] = []
        for info in ASSISTANTS:
            articles = (
                db.query(AssistantArticle)
                .filter_by(assistant_id=info.id, is_active=True)
                .all()
            )
            article_ids = {a.id for a in articles}
            read_ids: set[int] = set()
            if article_ids:
                read_ids = {
                    r.article_id
                    for r in db.query(UserAssistantArticleRead)
                    .filter_by(user_id=user_id, is_read=True)
                    .filter(UserAssistantArticleRead.article_id.in_(article_ids))
                    .all()
                }
            unread_count = len(article_ids - read_ids)
            result.append(
                {
                    "id": info.id,
                    "name": info.name,
                    "avatar": info.avatar,
                    "bio": info.bio,
                    "article_count": len(article_ids),
                    "unread_count": unread_count,
                }
            )
        return result

    # ===== 文章 =====

    def _get_read_state(
        self, db: Session, user_id: int, article_id: int
    ) -> UserAssistantArticleRead:
        read_state = (
            db.query(UserAssistantArticleRead)
            .filter_by(user_id=user_id, article_id=article_id)
            .first()
        )
        if not read_state:
            read_state = UserAssistantArticleRead(
                user_id=user_id,
                article_id=article_id,
                is_read=False,
            )
            db.add(read_state)
            db.flush()
        return read_state

    def list_articles(
        self, db: Session, user_id: int, assistant_id: str
    ) -> Dict:
        """返回指定助手下的所有文章列表 + 当前用户未读数。"""
        articles = (
            db.query(AssistantArticle)
            .filter_by(assistant_id=assistant_id, is_active=True)
            .order_by(AssistantArticle.publish_time.desc())
            .all()
        )
        article_ids = {a.id for a in articles}
        read_ids: set[int] = set()
        if article_ids:
            read_ids = {
                r.article_id
                for r in db.query(UserAssistantArticleRead)
                .filter_by(user_id=user_id, is_read=True)
                .filter(UserAssistantArticleRead.article_id.in_(article_ids))
                .all()
            }
        items = [
            {
                "id": a.id,
                "assistant_id": a.assistant_id,
                "title": a.title,
                "summary": a.summary,
                "publish_time": a.publish_time,
                "publisher": a.publisher,
                "is_read": a.id in read_ids,
            }
            for a in articles
        ]
        return {
            "assistant_id": assistant_id,
            "articles": items,
            "unread_count": len(article_ids - read_ids),
        }

    def get_article(
        self, db: Session, user_id: int, assistant_id: str, article_id: int
    ) -> Optional[Dict]:
        article = (
            db.query(AssistantArticle)
            .filter_by(
                id=article_id, assistant_id=assistant_id, is_active=True
            )
            .first()
        )
        if not article:
            return None
        read_state = self._get_read_state(db, user_id, article_id)
        return {
            "id": article.id,
            "assistant_id": article.assistant_id,
            "title": article.title,
            "summary": article.summary,
            "content": read_markdown(article.slug),
            "publish_time": article.publish_time,
            "publisher": article.publisher,
            "is_read": read_state.is_read,
        }

    def mark_article_read(
        self, db: Session, user_id: int, article_id: int
    ) -> bool:
        article = db.query(AssistantArticle).filter_by(id=article_id).first()
        if not article:
            return False
        read_state = self._get_read_state(db, user_id, article_id)
        if not read_state.is_read:
            read_state.is_read = True
            read_state.read_at = datetime.utcnow()
            db.commit()
        return True

    # ===== 种子数据 =====

    def seed_articles(self, db: Session) -> None:
        """把 SEED_ARTICLES 同步到数据库。新增 / 更新元信息，slug 不变则不删。"""
        for item in SEED_ARTICLES:
            exists = (
                db.query(AssistantArticle)
                .filter_by(
                    assistant_id=item["assistant_id"],
                    slug=item["slug"],
                )
                .first()
            )
            if not exists:
                db.add(
                    AssistantArticle(
                        assistant_id=item["assistant_id"],
                        slug=item["slug"],
                        title=item["title"],
                        summary=item["summary"],
                        publish_time=item["publish_time"],
                        publisher=item["publisher"],
                        is_active=True,
                    )
                )
            else:
                # 元信息变更时同步更新
                exists.title = item["title"]
                exists.summary = item["summary"]
                exists.publish_time = item["publish_time"]
                exists.publisher = item["publisher"]
                exists.is_active = True
        db.commit()
