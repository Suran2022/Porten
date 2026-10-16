"""WAF rule provider with hot-reload (standard profile).

The active rule set lives in Redis as a versioned JSON document; this
provider caches the compiled rules locally and re-pulls the document
when its version changes, so rule updates take effect without a
restart. A built-in seed rule set is the fallback whenever Redis is
unreachable or holds no version.
"""

import json
import logging
import re
import threading
import time
from typing import Any, Optional
from urllib.parse import unquote_plus

import redis

logger = logging.getLogger(__name__)

# Built-in baseline rules (lite profile equivalent). Patterns are
# matched against the URL-decoded path and query, lowercased.
_SEED_RULES: list[dict[str, str]] = [
    {"name": "sql_union_select", "pattern": r"union\s+select", "action": "block"},
    {"name": "sql_tautology", "pattern": r"(\bor\b|\band\b)\s+['\"]?\d+['\"]?\s*=\s*['\"]?\d+", "action": "block"},
    {"name": "sql_comment", "pattern": r"(/\*|--\s|;\s*--)", "action": "block"},
    {"name": "sql_schema_probe", "pattern": r"information_schema|pg_catalog", "action": "block"},
    {"name": "sql_time_probe", "pattern": r"\b(sleep|benchmark|pg_sleep)\s*\(", "action": "block"},
    {"name": "xss_script_tag", "pattern": r"<\s*script", "action": "block"},
    {"name": "xss_event_handler", "pattern": r"\bon(error|load|click|mouseover)\s*=", "action": "block"},
    {"name": "xss_js_uri", "pattern": r"javascript\s*:", "action": "block"},
    {"name": "path_traversal", "pattern": r"(\.\.[/\\]|%2e%2e)", "action": "block"},
    {"name": "command_injection", "pattern": r"[;|`]\s*(cat|ls|whoami|id|curl|wget|nc|bash|sh)\b", "action": "block"},
]

_DEFAULT_REFRESH_SECONDS = 5


class WafRule:
    """A single compiled WAF rule."""

    __slots__ = ("name", "regex", "action")

    def __init__(self, name: str, pattern: str, action: str) -> None:
        self.name = name
        self.action = action
        self.regex = re.compile(pattern, re.IGNORECASE)


class RedisWafRuleProvider:
    """Versioned WAF rules cached locally with hot-reload."""

    def __init__(
        self,
        client: redis.Redis,
        rules_key: str,
        refresh_seconds: int = _DEFAULT_REFRESH_SECONDS,
    ) -> None:
        self._client = client
        self._rules_key = rules_key
        self._refresh_seconds = refresh_seconds
        self._lock = threading.Lock()
        self._version = ""
        self._rules: list[WafRule] = []
        self._last_refresh = 0.0
        self._load_seed()

    def current_version(self) -> str:
        """Return the version identifier of the active rule set."""
        self._maybe_refresh()
        return self._version

    def matches(self, path: str, query: str) -> Optional[str]:
        """Return the matched rule name for a request, or None."""
        self._maybe_refresh()
        if not self._rules:
            return None
        for candidate in self._match_targets(path, query):
            for rule in self._rules:
                if rule.regex.search(candidate):
                    return rule.name
        return None

    @staticmethod
    def _match_targets(path: str, query: str) -> list[str]:
        """Lowercased match surfaces: raw plus progressive decodings.

        Attack payloads arrive URL-encoded (``+``/``%XX``, sometimes
        double-encoded); matching only the raw form would let every
        encoded payload through. Decoding is additive, so the raw
        request is always among the candidates.
        """
        raw = f"{path}?{query}" if query else path
        candidates = {raw.lower()}
        current = raw
        for _ in range(2):  # raw, single-decoded, double-decoded
            current = unquote_plus(current)
            candidates.add(current.lower())
        return sorted(candidates, key=len, reverse=True)

    def _maybe_refresh(self) -> None:
        """Re-pull the rule document when the refresh interval elapsed."""
        now = time.monotonic()
        if now - self._last_refresh < self._refresh_seconds:
            return
        with self._lock:
            if now - self._last_refresh < self._refresh_seconds:
                return
            self._last_refresh = now
            try:
                raw = self._client.get(self._rules_key)
            except redis.RedisError:
                logger.warning("waf rules refresh failed, keeping current", exc_info=True)
                return
            if not raw:
                # No document in Redis: fall back to the built-in seed
                # set rather than keeping a stale custom rule set.
                if self._version != "seed":
                    self._load_seed()
                return
            self._apply_document(raw)

    def _apply_document(self, raw: str) -> None:
        """Parse and install a rule document, ignoring bad payloads."""
        try:
            document = json.loads(raw)
            version = str(document.get("version", ""))
            compiled = self._compile(document.get("rules", []))
        except (ValueError, TypeError, re.error):
            logger.warning("waf rules document invalid, keeping current")
            return
        if version == self._version and compiled == self._rules:
            return
        self._version = version
        self._rules = compiled
        logger.info("waf rules updated to version %s (%d rules)", version, len(compiled))

    @staticmethod
    def _compile(rules: Any) -> list[WafRule]:
        compiled: list[WafRule] = []
        if not isinstance(rules, list):
            return compiled
        for rule in rules:
            try:
                compiled.append(
                    WafRule(
                        name=str(rule["name"]),
                        pattern=str(rule["pattern"]),
                        action=str(rule.get("action", "block")),
                    )
                )
            except (KeyError, TypeError, re.error):
                logger.warning("skipping invalid waf rule: %r", rule)
        return compiled

    def _load_seed(self) -> None:
        """Install the built-in baseline rule set."""
        self._version = "seed"
        self._rules = self._compile(_SEED_RULES)
        self._last_refresh = time.monotonic()

    def publish_rules(self, rules: list[dict[str, str]], version: str) -> None:
        """Write a new rule document to Redis (management-side helper)."""
        document = json.dumps({"version": version, "rules": rules}, ensure_ascii=False)
        self._client.set(self._rules_key, document)
        self._last_refresh = 0.0  # force refresh on next use
        self._maybe_refresh()
