"""Profile-based security capability factory.

The active profile is configured via ``SECURITY_PROFILE`` (lite by default).
Each profile assembles the capability set defined in
:mod:`app.security.protocols`; unknown profiles fail fast at startup so
misconfiguration can never silently disable protections.

Degradation contract (standard): every Redis-backed capability falls back
to its lite equivalent when Redis is unreachable, so a degraded standard
deployment behaves like lite instead of failing. Capabilities that need no
Redis (file sanitizing, behavior analysis) stay active regardless. When
``SECURITY_REDIS_REQUIRED`` is set, an unreachable Redis fails fast at
build time instead.
"""

import logging
from dataclasses import dataclass
from typing import Optional

from app.config import get_settings
from app.security.protocols import (
    BehaviorAnalyzer,
    ContentModerator,
    EdgeBlocklist,
    EventQueuePublisher,
    FieldEncryptor,
    FileSanitizer,
    RateLimiter,
    SecurityEventSink,
    UrlFetchSandbox,
    UrlScanner,
    WafRuleProvider,
)
from app.security.redis_client import create_redis_client
from app.services.behavior_analysis_service import BehaviorAnalyzer as BehaviorAnalyzerImpl
from app.services.content_moderation_service import RuleBasedModerator
from app.services.edge_blocklist_service import RedisEdgeBlocklist
from app.services.event_queue_service import RedisStreamEventQueue, StreamingEventSink
from app.services.field_encryption_service import get_field_encryptor
from app.services.file_sanitizer_service import MediaFileSanitizer
from app.services.rate_limit_service import InMemoryRateLimiter
from app.services.redis_rate_limit_service import RedisRateLimiter
from app.services.security_event_service import SecurityEventService
from app.services.threat_intel_service import ThreatIntelService
from app.services.url_scanner_service import CachedUrlScanner, LocalRuleUrlScanner
from app.services.url_fetch_sandbox_service import build_url_fetch_sandbox
from app.services.waf_service import RedisWafRuleProvider

logger = logging.getLogger(__name__)

settings = get_settings()


@dataclass
class SecurityCapabilities:
    """Assembled security capabilities for the active profile.

    The first four capabilities exist in every profile; the remaining
    ones are optional and absent (``None``) when the active profile or
    a degraded dependency does not provide them.
    """

    rate_limiter: RateLimiter
    url_scanner: UrlScanner
    content_moderator: ContentModerator
    event_sink: SecurityEventSink
    # Present in every profile (environment key at minimum); degrades
    # to passthrough when no key is configured.
    field_encryptor: FieldEncryptor
    event_queue: Optional[EventQueuePublisher] = None
    waf_rules: Optional[WafRuleProvider] = None
    file_sanitizer: Optional[FileSanitizer] = None
    behavior_analyzer: Optional[BehaviorAnalyzer] = None
    edge_blocklist: Optional[EdgeBlocklist] = None
    # Advanced only: SSRF-hardened fetch sandbox (remote endpoint, local
    # isolation sandbox or disabled, per config).
    url_sandbox: Optional[UrlFetchSandbox] = None


def _build_lite() -> SecurityCapabilities:
    """Assemble the zero-middleware profile (all in-process)."""
    url_scanner = LocalRuleUrlScanner()
    return SecurityCapabilities(
        rate_limiter=InMemoryRateLimiter(),
        url_scanner=url_scanner,
        content_moderator=RuleBasedModerator(url_scanner=url_scanner),
        event_sink=SecurityEventService(),
        field_encryptor=get_field_encryptor("lite"),
    )


def _build_standard() -> SecurityCapabilities:
    """Assemble the Redis-backed profile with per-capability degradation."""
    client = create_redis_client()
    if client is None:
        if settings.security_redis_required:
            raise RuntimeError(
                "security profile 'standard' requires Redis but "
                f"{settings.redis_url} is unreachable"
            )
        logger.warning(
            "standard profile: redis unreachable, degrading redis-backed "
            "capabilities to in-process implementations"
        )

    # Rate limiting: Redis sliding window, in-memory fallback inside.
    if client is not None:
        rate_limiter: RateLimiter = RedisRateLimiter(client)
    else:
        rate_limiter = InMemoryRateLimiter()

    # URL scanning: local rules plus host reputation when Redis is up.
    local_scanner = LocalRuleUrlScanner()
    if client is not None:
        intel = ThreatIntelService(client)
        url_scanner: UrlScanner = CachedUrlScanner(local_scanner, intel)
    else:
        url_scanner = local_scanner

    # Event sink: durable DB record plus best-effort stream fan-out.
    db_sink = SecurityEventService()
    event_queue: Optional[EventQueuePublisher] = None
    if client is not None:
        event_queue = RedisStreamEventQueue(
            client,
            stream_key=settings.security_event_stream_key,
            cursor_key=f"{settings.security_event_stream_key}:cursor",
        )
    event_sink: SecurityEventSink = (
        StreamingEventSink(db_sink, event_queue) if event_queue else db_sink
    )

    # WAF: seed rules locally, hot-reload from Redis when reachable.
    waf_rules: Optional[WafRuleProvider] = None
    if client is not None:
        waf_rules = RedisWafRuleProvider(
            client, rules_key=settings.security_waf_rules_key
        )

    # Edge blocklist: hot-reloaded from Redis when reachable.
    edge_blocklist: Optional[EdgeBlocklist] = None
    if client is not None:
        edge_blocklist = RedisEdgeBlocklist(
            client, key=settings.security_blocklist_key
        )

    return SecurityCapabilities(
        rate_limiter=rate_limiter,
        url_scanner=url_scanner,
        content_moderator=RuleBasedModerator(url_scanner=url_scanner),
        event_sink=event_sink,
        field_encryptor=get_field_encryptor("standard"),
        event_queue=event_queue,
        waf_rules=waf_rules,
        # Redis-independent capabilities stay active even without Redis.
        file_sanitizer=MediaFileSanitizer(),
        behavior_analyzer=BehaviorAnalyzerImpl(),
        edge_blocklist=edge_blocklist,
    )


def _build_advanced() -> SecurityCapabilities:
    """Assemble the advanced profile: standard set plus the fetch sandbox.

    The advanced-only background jobs (approval expiry sweep, UEBA
    aggregation) and the honeypot/SIEM pipeline are wired in the app
    lifespan and config-gated; the factory only adds capabilities that
    are injected into request paths.
    """
    capabilities = _build_standard()
    capabilities.url_sandbox = build_url_fetch_sandbox("advanced")
    return capabilities


def build_security_capabilities(
    profile: Optional[str] = None,
) -> SecurityCapabilities:
    """Assemble capabilities for the given or configured security profile."""
    active = profile or settings.security_profile

    if active == "lite":
        return _build_lite()
    if active == "standard":
        return _build_standard()
    if active == "advanced":
        return _build_advanced()

    raise ValueError(
        f"unsupported security profile: {active}; "
        "expected one of: lite, standard, advanced"
    )
