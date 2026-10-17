"""
Application configuration loaded from environment variables.

All sensitive values (passwords, secrets) must be provided via the environment.
This module centralizes configuration to make migration and switching easier.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "mysql+pymysql://root:password@localhost:3306/porten?charset=utf8mb4"

    # Security
    secret_key: str = "change-me"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080  # 7 days

    # SMTP
    smtp_host: str = "smtp.qq.com"
    smtp_port: int = 465
    # SMTP 登录用户名。注意与发件人是两个概念：部分服务商（如 Resend）
    # 登录名固定为 "resend"，而发件人必须是验证过的地址，故拆分为两个配置。
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_sender_name: str = "Porten"
    # 发件人地址；缺省回退 smtp_username（兼容 QQ 邮箱等登录名即发件人的服务）。
    smtp_from_address: str = ""

    # Application
    default_avatar_url: str = "https://haowallpaper.com/link//common/file/previewFileImg/19197325717754752"
    app_name: str = "Porten"
    app_env: str = "development"

    # Application timezone: every datetime is stored as UTC and
    # converted to this zone for display (defaults to Asia/Shanghai).
    app_timezone: str = "Asia/Shanghai"

    # Weather provider (trip reminders, design: pluggable provider).
    # The HTTP provider is enabled only when both the URL template and
    # the API key are configured; otherwise the null provider degrades
    # the weather sentence out of the reminder text.
    weather_url_template: str = ""
    weather_api_key: str = ""
    # Dotted paths plucked from the provider JSON response.
    weather_text_path: str = "now.text"
    weather_temp_path: str = "now.temp"
    weather_timeout_seconds: float = 5.0
    # Reminder mentions "feels colder" when the destination is at
    # least this many degrees below the departure city.
    weather_temp_drop_threshold: float = 3.0

    # Trip reminder sentence templates (placeholders in braces).
    trip_reminder_days_template: str = "还有{days}天飞往{arrival_city}"
    trip_reminder_hours_template: str = "还有{hours}小时飞往{arrival_city}"
    trip_reminder_weather_template: str = (
        "您当前所在城市天气{origin_text}，{arrival_city}{arrival_text}，"
        "气温{origin_temp}℃/{arrival_temp}℃"
    )
    trip_reminder_weather_cool_template: str = (
        "您当前所在城市天气{origin_text}，"
        "但{arrival_city}气温较低，注意保暖哦！"
    )

    # Security
    # Active security profile: lite | standard | advanced.
    # lite is the single-machine profile with no external dependencies.
    security_profile: str = "lite"
    # Master switches for individual capabilities (tunable on top of a profile).
    security_rate_limit_enabled: bool = True
    security_precheck_enabled: bool = True
    security_url_scan_enabled: bool = True
    # Retention window for security events and audit records, in days.
    security_event_retention_days: int = 90
    # Redis connection (standard/advanced profiles).
    redis_url: str = "redis://localhost:6379/0"
    # When True, a missing Redis in standard/advanced fails startup
    # instead of silently degrading to in-process implementations.
    security_redis_required: bool = False
    # Redis Stream keys for the asynchronous security event queue.
    security_event_stream_key: str = "porten:security:events"
    security_event_consumer_group: str = "security-review"
    # Redis key holding the versioned WAF rule set (hot-reloaded).
    security_waf_rules_key: str = "porten:security:waf:rules"
    # Redis SET holding blocked client IPs (hot-reloaded edge blocklist).
    security_blocklist_key: str = "porten:security:blocklist:ips"
    # Field-level encryption for P0 fields (design doc §5.4.2).
    # Master switch; effective only when a key is configured.
    security_field_encryption_enabled: bool = True
    # When True, startup fails if encryption is on but no key resolves.
    security_field_encryption_required: bool = False
    # Key-encryption key (base64, 32 bytes) from the environment.
    security_field_kek: str = ""
    security_field_kek_kid: str = "env"
    # Previous KEK kept decrypt-only during key rotation.
    security_field_kek_previous: str = ""
    security_field_kek_previous_kid: str = "env-previous"
    # KMS key source (standard/advanced profiles only).
    security_kms_url: str = ""
    security_kms_key_id: str = ""
    security_kms_timeout_seconds: float = 3.0
    security_kms_cache_seconds: float = 300.0
    # SSRF-hardened URL fetch sandbox (advanced profile, design doc §5.5).
    # Master switch for the local isolation sandbox; the remote sandbox
    # (security_sandbox_url) takes precedence when configured.
    security_url_fetch_enabled: bool = False
    security_url_fetch_timeout_seconds: float = 5.0
    security_url_fetch_max_bytes: int = 524288
    security_url_fetch_max_redirects: int = 3
    # Cluster-side fetch sandbox endpoint (advanced profile). When set,
    # fetches are delegated there instead of the in-process sandbox.
    security_sandbox_url: str = ""
    # External threat-intelligence feed (design doc §5.5). Disabled by
    # default; failures keep the locally cached reputation records.
    security_threat_feed_url: str = ""
    security_threat_feed_interval_seconds: int = 3600
    security_threat_feed_ttl_seconds: int = 604800
    # RFC 3161 trusted timestamp authority (design doc §9). Empty means
    # no timestamping: forensic records stay pending and the absence of
    # a timestamp is never forged.
    security_tsa_url: str = ""
    security_tsa_timeout_seconds: float = 5.0
    # Honeypot: decoy admin endpoints plus honeytoken detection on the
    # invalid-token path (design doc §5.5). Off in lite; the standard
    # and advanced deployments turn it on.
    security_honeypot_enabled: bool = False
    # Automatically blocklist client IPs that probe the decoys.
    security_honeypot_autoblock: bool = True
    # SIEM export: consumer-group exporter shipping the security event
    # stream to a webhook. Off by default; never blocks the business
    # path (background task, at-least-once delivery).
    security_siem_enabled: bool = False
    security_siem_webhook_url: str = ""
    security_siem_interval_seconds: int = 30
    security_siem_batch_size: int = 100
    security_siem_timeout_seconds: float = 5.0
    security_siem_consumer_group: str = "siem-export"
    # Two-person / two-key approval (design doc §10.1): sensitive
    # operations need a primary operator and a reviewer to each press
    # their hardware key within the validity window. Tickets are
    # one-shot and bound to the exact action and payload.
    security_approval_ttl_seconds: int = 300
    # Sweep interval for overdue approval tickets.
    security_approval_sweep_interval_seconds: int = 60
    # FIDO2/WebAuthn relying-party settings for the key carrier. The
    # origin must match the admin frontend exactly (scheme + host +
    # port); the rp id is the registrable domain of that origin.
    webauthn_rp_id: str = "localhost"
    webauthn_rp_name: str = "Porten Admin"
    webauthn_origin: str = "http://localhost:3000"
    # Registration challenge lifetime for the in-process challenge
    # store (the approval ceremonies use the ticket nonce instead).
    webauthn_challenge_ttl_seconds: int = 120
    # UEBA aggregation (design doc §5.3.2): periodic roll-up of
    # metadata-only per-entity risk signals into ueba_entity_scores,
    # feeding the admin triage queue. Windows are aligned to fixed
    # boundaries so re-runs are idempotent.
    security_ueba_enabled: bool = False
    security_ueba_window_minutes: int = 60
    security_ueba_interval_seconds: int = 300

    @property
    def sender_address(self) -> str:
        from_address = self.smtp_from_address or self.smtp_username
        return f"{self.smtp_sender_name} <{from_address}>"


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()
