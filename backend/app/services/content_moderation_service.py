"""Rule-based synchronous content moderation (lite profile).

Design constraints (see security architecture doc):

* Only *confirmed-level* violations are blocked synchronously; anything
  uncertain is allowed and routed to the asynchronous review queue.
* Negative emotional expression and help-seeking content are never
  blocked -- the rule set deliberately excludes self-harm and venting
  language so the emergency help channel stays open. A detected help
  signal is only surfaced (category ``help_signal``) so care resources
  can follow up.
* All matching runs on the normalized form (see
  :mod:`app.utils.normalize`) so zero-width, leet and split-character
  evasions are folded before matching.
* Chat URLs are escalated to the URL scanner; malicious links are
  blocked as part of the backdoor-link defense.

Gender-identity vocabulary is intentionally absent from the rule set:
for this community such terms are protected expression, not violations.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Optional

from app.schemas.security import ModerationDecision, ModerationResult, UrlVerdictLevel
from app.services.url_scanner_service import LocalRuleUrlScanner
from app.utils.normalize import extract_urls, normalize_text

if TYPE_CHECKING:
    # Imported for type checking only: importing app.security at runtime
    # would create a factory <-> services import cycle.
    from app.security.protocols import UrlScanner


@dataclass(frozen=True)
class _Rule:
    """A confirmed-level violation rule.

    ``patterns`` are matched against the normalized text form; a single
    hit is sufficient to block. Patterns are normalized at import time
    so rule authors may write them naturally.
    """

    category: str
    reason: str
    patterns: tuple[str, ...]


_RAW_RULES: tuple[_Rule, ...] = (
    # Child safety: confirmed-level phrasing only. Broad terms such as
    # "teen" or "minor" alone are never matched.
    _Rule(
        category="csam",
        reason="child sexual abuse material",
        patterns=(
            "儿童色情",
            "幼女色情",
            "男童色情",
            "女童色情",
            "恋童癖",
            "pedophile",
            "childporn",
        ),
    ),
    # Drugs: named substances plus explicit trade phrasing.
    _Rule(
        category="drug",
        reason="illegal drug trade",
        patterns=(
            "冰毒",
            "麻古",
            "海洛因",
            "可卡因",
            "氯胺酮",
            "摇头丸",
            "k粉",
            "合成大麻素",
            "贩卖毒品",
            "毒品交易",
        ),
    ),
    # Weapons and explosives.
    _Rule(
        category="weapon",
        reason="illegal weapon trade",
        patterns=(
            "买枪",
            "卖枪",
            "枪支买卖",
            "枪械图纸",
            "弹药出售",
            "炸药制作",
            "炸弹制作",
            "雷管出售",
        ),
    ),
    # Violent extremism.
    _Rule(
        category="extremism",
        reason="violent extremism",
        patterns=(
            "圣战",
            "人肉炸弹",
            "自杀式袭击",
            "制造恐怖",
        ),
    ),
    # Gambling promotion.
    _Rule(
        category="gambling",
        reason="illegal gambling promotion",
        patterns=(
            "博彩网",
            "菠菜网",
            "现金网",
            "六合彩",
            "赌博平台",
            "网赌",
            "百家乐",
        ),
    ),
    # Fraud scripts (romance scam, refund scam, impersonation).
    _Rule(
        category="fraud",
        reason="fraud script",
        patterns=(
            "刷单",
            "杀猪盘",
            "安全账户",
            "涉嫌洗钱",
            "屏幕共享",
            "注销网贷",
        ),
    ),
    # Sex trade solicitation (explicit trade phrasing only).
    _Rule(
        category="prostitution",
        reason="sex trade solicitation",
        patterns=(
            "招嫖",
            "嫖娼",
            "买春",
            "性交易",
            "上门性服务",
            "包夜服务",
        ),
    ),
    # Pornographic content distribution.
    _Rule(
        category="pornography",
        reason="pornographic content",
        patterns=(
            "黄片",
            "毛片",
            "a片",
            "色情片",
            "裸聊",
            "裸照出售",
            "pornhub",
            "xvideos",
        ),
    ),
    # Human trafficking and illegal organ trade.
    _Rule(
        category="trafficking",
        reason="human trafficking",
        patterns=(
            "贩卖人口",
            "买孩子",
            "卖肾",
            "代孕",
        ),
    ),
)

# Help-seeking signals: recorded for care follow-up, never blocked.
_HELP_SIGNALS: tuple[str, ...] = (
    "自杀",
    "自残",
    "想死",
    "活不下去",
    "不想活",
    "割腕",
    "救命",
    "帮帮我",
    "报警求助",
)


def _normalize_patterns(patterns: tuple[str, ...]) -> tuple[str, ...]:
    """Fold rule patterns into the same normalized form as content."""
    return tuple(normalize_text(pattern) for pattern in patterns)


_RULES: tuple[_Rule, ...] = tuple(
    _Rule(
        category=rule.category,
        reason=rule.reason,
        patterns=_normalize_patterns(rule.patterns),
    )
    for rule in _RAW_RULES
)

_HELP_SIGNAL_PATTERNS: tuple[str, ...] = _normalize_patterns(_HELP_SIGNALS)


class RuleBasedModerator:
    """Content moderator backed by local rules only (lite profile)."""

    def __init__(self, url_scanner: Optional[UrlScanner] = None) -> None:
        # Injected so the moderator and the URL capability share one
        # scanner instance per profile; defaults keep standalone use easy.
        self._url_scanner = url_scanner or LocalRuleUrlScanner()

    def check(self, content: str, message_type: str) -> ModerationResult:
        """Return the allow/block decision for confirmed-level violations."""
        # Only text is moderated synchronously in the lite profile;
        # media pipelines are added in later profiles.
        if message_type != "text" or not content:
            return ModerationResult(decision=ModerationDecision.ALLOW)

        normalized = normalize_text(content)

        for rule in _RULES:
            for pattern in rule.patterns:
                if pattern in normalized:
                    return ModerationResult(
                        decision=ModerationDecision.BLOCK,
                        category=rule.category,
                        reason=rule.reason,
                    )

        for url in extract_urls(content):
            verdict = self._url_scanner.scan(url)
            if verdict.level == UrlVerdictLevel.MALICIOUS:
                return ModerationResult(
                    decision=ModerationDecision.BLOCK,
                    category="malicious_url",
                    reason=f"malicious link blocked: {verdict.reason}",
                )

        for pattern in _HELP_SIGNAL_PATTERNS:
            if pattern in normalized:
                return ModerationResult(
                    decision=ModerationDecision.ALLOW,
                    category="help_signal",
                    reason="help signal detected; routed to care resources",
                )

        return ModerationResult(decision=ModerationDecision.ALLOW)
