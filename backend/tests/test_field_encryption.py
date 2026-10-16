"""Tests for application-layer field encryption (design doc §5.4.2).

Covers the envelope codec, both key sources (environment and KMS with
degradation), the profile-aware factory wiring, and transparent
round-tripping through the ORM column type.
"""

import base64
from datetime import datetime, timezone

import httpx
import pytest
from sqlalchemy import Integer, create_engine, text
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.models import (
    Conversation,
    EmotionDiary,
    EmotionDiaryView,
    Message,
    User,
)
from app.security import build_security_capabilities
from app.services.field_encryption_service import (
    ENVELOPE_VERSION,
    EnvKeyProvider,
    EnvelopeError,
    FieldEncryptor,
    KmsKeyProvider,
    build_field_encryptor,
    get_field_encryptor,
    reset_field_encryptors,
)

KEK = base64.urlsafe_b64encode(b"k" * 32).decode()
OTHER_KEK = base64.urlsafe_b64encode(b"o" * 32).decode()
KMS_KEY = base64.urlsafe_b64encode(b"m" * 32).decode()


class _FakeProvider:
    """Key provider double with scripted resolutions."""

    def __init__(self, keys: dict, active: str = None) -> None:
        self._keys = keys
        self._active = active or next(iter(keys))

    def active_kid(self):
        return self._active

    def resolve(self, kid: str):
        return self._keys.get(kid)


@pytest.fixture(autouse=True)
def _clean_encryptors(settings):
    """Snapshot settings and drop cached encryptors around every test."""
    keys = (
        "security_field_encryption_enabled",
        "security_field_encryption_required",
        "security_field_kek",
        "security_field_kek_kid",
        "security_field_kek_previous",
        "security_field_kek_previous_kid",
        "security_kms_url",
        "security_kms_key_id",
        "security_kms_cache_seconds",
        "security_profile",
    )
    snapshot = {key: getattr(settings, key) for key in keys}
    reset_field_encryptors()
    yield
    for key, value in snapshot.items():
        setattr(settings, key, value)
    reset_field_encryptors()


@pytest.fixture()
def settings():
    return get_settings()


def _encryptor(**kwargs) -> FieldEncryptor:
    provider = _FakeProvider({"k1": b"1" * 32}, **kwargs)
    return FieldEncryptor(provider)


# ---------------------------------------------------------------------------
# Envelope codec
# ---------------------------------------------------------------------------


class TestEnvelopeCodec:

    def test_round_trip(self):
        enc = _encryptor()
        envelope = enc.encrypt("私密消息内容 secret")
        assert envelope != "私密消息内容 secret"
        assert envelope.startswith(ENVELOPE_VERSION + ".")
        assert enc.decrypt(envelope) == "私密消息内容 secret"

    def test_envelope_structure(self):
        enc = _encryptor()
        parts = enc.encrypt("hello").split(".")
        assert len(parts) == 4
        assert parts[0] == ENVELOPE_VERSION
        assert parts[1] == "k1"
        # wrapped DEK = nonce(12) + key(32) + tag(16) -> 60 bytes
        assert len(base64.urlsafe_b64decode(parts[2] + "==")) == 60

    def test_fresh_dek_per_value(self):
        enc = _encryptor()
        first = enc.encrypt("same plaintext")
        second = enc.encrypt("same plaintext")
        assert first != second  # fresh DEK + nonces, never deterministic

    def test_unicode_and_long_content(self):
        enc = _encryptor()
        for value in ("", "😀  crisis support 消息", "x" * 60_000):
            envelope = enc.encrypt(value)
            assert enc.decrypt(envelope) == value

    def test_legacy_plaintext_passes_through(self):
        enc = _encryptor()
        assert enc.decrypt("plain old row") == "plain old row"
        # near-miss prefixes must not be mistaken for envelopes
        assert enc.decrypt("pfx1.not-an-envelope") == "pfx1.not-an-envelope"
        assert enc.decrypt("pfx1.k1.only.two") == "pfx1.k1.only.two"

    def test_tampered_payload_rejected(self):
        enc = _encryptor()
        version, kid, wrapped, payload = enc.encrypt("tamper me").split(".")
        raw = bytearray(base64.urlsafe_b64decode(payload + "=="))
        raw[-1] ^= 0xFF
        broken = ".".join(
            (version, kid, wrapped, base64.urlsafe_b64encode(bytes(raw)).decode())
        )
        with pytest.raises(EnvelopeError):
            enc.decrypt(broken)

    def test_tampered_wrapped_dek_rejected(self):
        enc = _encryptor()
        version, kid, wrapped, payload = enc.encrypt("tamper me").split(".")
        raw = bytearray(base64.urlsafe_b64decode(wrapped + "=="))
        raw[0] ^= 0xFF
        broken = ".".join(
            (version, kid, base64.urlsafe_b64encode(bytes(raw)).decode(), payload)
        )
        with pytest.raises(EnvelopeError):
            enc.decrypt(broken)

    def test_unknown_key_id_rejected(self):
        enc = _encryptor()
        envelope = enc.encrypt("rotated away")
        _, _, wrapped, payload = envelope.split(".")
        forged = ".".join(("pfx1", "unknown-kid", wrapped, payload))
        with pytest.raises(EnvelopeError):
            enc.decrypt(forged)

    def test_wrong_key_rejected(self):
        enc = FieldEncryptor(_FakeProvider({"k1": b"1" * 32, "k2": b"2" * 32}))
        envelope = enc.encrypt("sealed with k1")
        # k1 removed from the provider (key lost): unwrap must fail
        rotated = FieldEncryptor(_FakeProvider({"k2": b"2" * 32}))
        with pytest.raises(EnvelopeError):
            rotated.decrypt(envelope)

    def test_disabled_encryptor_passes_through(self):
        enc = FieldEncryptor(_FakeProvider({"k1": b"1" * 32}), enabled=False)
        assert enc.encrypt("plaintext stays") == "plaintext stays"
        assert not enc.available
        # decryption of existing envelopes still works when disabled
        live = FieldEncryptor(_FakeProvider({"k1": b"1" * 32}))
        assert enc.decrypt(live.encrypt("old envelope")) == "old envelope"

    def test_missing_key_fails_closed(self):
        enc = FieldEncryptor(_FakeProvider({"k1": None}, active="k1"))
        assert enc.available  # key id configured...
        with pytest.raises(EnvelopeError):
            enc.encrypt("cannot seal")  # ...but unresolvable: no plaintext write


# ---------------------------------------------------------------------------
# Environment key provider
# ---------------------------------------------------------------------------


class TestEnvKeyProvider:

    def test_active_key(self, settings):
        settings.security_field_kek = KEK
        settings.security_field_kek_kid = "env-a"
        provider = EnvKeyProvider()
        assert provider.active_kid() == "env-a"
        assert provider.resolve("env-a") == b"k" * 32
        assert provider.resolve("nope") is None

    def test_invalid_key_ignored(self, settings):
        settings.security_field_kek = "not-base64!!"
        provider = EnvKeyProvider()
        assert provider.active_kid() is None

    def test_rotation_window(self, settings):
        settings.security_field_kek = KEK
        settings.security_field_kek_kid = "env-new"
        settings.security_field_kek_previous = OTHER_KEK
        settings.security_field_kek_previous_kid = "env-old"
        provider = EnvKeyProvider()
        assert provider.active_kid() == "env-new"
        assert provider.resolve("env-old") == b"o" * 32

    def test_no_keys(self, settings):
        settings.security_field_kek = ""
        settings.security_field_kek_previous = ""
        provider = EnvKeyProvider()
        assert provider.active_kid() is None
        assert provider.resolve("env") is None


# ---------------------------------------------------------------------------
# KMS key provider (mocked transport)
# ---------------------------------------------------------------------------


def _kms_settings(settings, **overrides):
    settings.security_kms_url = overrides.get("url", "https://kms.test/")
    settings.security_kms_key_id = overrides.get("key_id", "kms-1")
    settings.security_kms_cache_seconds = overrides.get("cache_seconds", 300.0)
    settings.security_field_kek = overrides.get("env_kek", "")
    settings.security_field_kek_previous = ""


class TestKmsKeyProvider:

    def _client(self, handler) -> httpx.Client:
        return httpx.Client(transport=httpx.MockTransport(handler))

    def test_fetch_and_cache(self, settings):
        _kms_settings(settings)
        calls = []

        def handler(request: httpx.Request) -> httpx.Response:
            calls.append(str(request.url))
            return httpx.Response(200, json={"key": KMS_KEY})

        provider = KmsKeyProvider(
            fallback=EnvKeyProvider(), client=self._client(handler)
        )
        assert provider.active_kid() == "kms-1"
        assert provider.resolve("kms-1") == b"m" * 32
        assert provider.resolve("kms-1") == b"m" * 32
        assert len(calls) == 1  # second resolve served from cache
        assert calls[0] == "https://kms.test/v1/keys/kms-1"

    def test_cache_expiry_refetches(self, settings):
        _kms_settings(settings, cache_seconds=0.0)
        calls = []

        def handler(request: httpx.Request) -> httpx.Response:
            calls.append(1)
            return httpx.Response(200, json={"key": KMS_KEY})

        provider = KmsKeyProvider(
            fallback=EnvKeyProvider(), client=self._client(handler)
        )
        provider.resolve("kms-1")
        provider.resolve("kms-1")
        assert len(calls) == 2

    def test_kms_down_falls_back_to_env_key(self, settings):
        _kms_settings(settings, env_kek=KEK)
        settings.security_field_kek_kid = "env"

        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("kms unreachable")

        provider = KmsKeyProvider(
            fallback=EnvKeyProvider(), client=self._client(handler)
        )
        assert provider.resolve("env") == b"k" * 32  # env fallback wins
        assert provider.active_kid() == "kms-1"  # new values still target KMS

    def test_kms_invalid_key_falls_back(self, settings):
        _kms_settings(settings, env_kek=KEK)
        settings.security_field_kek_kid = "env"

        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"key": "too-short"})

        provider = KmsKeyProvider(
            fallback=EnvKeyProvider(), client=self._client(handler)
        )
        assert provider.resolve("env") == b"k" * 32

    def test_no_fallback_returns_none(self, settings):
        _kms_settings(settings)

        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(500)

        provider = KmsKeyProvider(
            fallback=EnvKeyProvider(), client=self._client(handler)
        )
        assert provider.resolve("kms-1") is None


# ---------------------------------------------------------------------------
# Profile-aware assembly
# ---------------------------------------------------------------------------


class TestFactoryWiring:

    def _patch_kms(self, monkeypatch, handler):
        """Force the KMS client onto a mocked transport."""
        original = httpx.Client

        def factory(*args, **kwargs):
            kwargs["transport"] = httpx.MockTransport(handler)
            return original(*args, **kwargs)

        monkeypatch.setattr(httpx, "Client", factory)

    def test_lite_uses_env_key_even_with_kms_configured(self, settings):
        _kms_settings(settings, env_kek=KEK)
        settings.security_field_kek_kid = "env"
        encryptor = build_field_encryptor("lite")
        assert type(encryptor._provider).__name__ == "EnvKeyProvider"
        assert encryptor.available

    def test_standard_uses_kms_when_configured(self, settings, monkeypatch):
        _kms_settings(settings, env_kek=KEK)

        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"key": KMS_KEY})

        self._patch_kms(monkeypatch, handler)
        encryptor = build_field_encryptor("standard")
        assert type(encryptor._provider).__name__ == "KmsKeyProvider"
        envelope = encryptor.encrypt("via kms")
        assert envelope.startswith(f"{ENVELOPE_VERSION}.kms-1.")
        assert encryptor.decrypt(envelope) == "via kms"

    def test_standard_without_kms_uses_env_key(self, settings):
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        settings.security_field_kek_kid = "env"
        encryptor = build_field_encryptor("standard")
        assert type(encryptor._provider).__name__ == "EnvKeyProvider"
        assert encryptor.decrypt(encryptor.encrypt("x")) == "x"

    def test_required_without_key_fails_startup(self, settings):
        settings.security_kms_url = ""
        settings.security_field_kek = ""
        settings.security_field_encryption_required = True
        with pytest.raises(RuntimeError):
            build_field_encryptor("lite")

    def test_required_with_unreachable_kms_fails_startup(self, settings, monkeypatch):
        _kms_settings(settings)
        settings.security_field_encryption_required = True

        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("down")

        self._patch_kms(monkeypatch, handler)
        with pytest.raises(RuntimeError):
            build_field_encryptor("standard")

    def test_capabilities_expose_encryptor(self, settings):
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        settings.security_field_kek_kid = "env"
        for profile in ("lite", "standard"):
            caps = build_security_capabilities(profile)
            assert caps.field_encryptor.available
            assert caps.field_encryptor.decrypt(
                caps.field_encryptor.encrypt("profile check")
            ) == "profile check"

    def test_get_field_encryptor_caches_per_profile(self, settings):
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        assert get_field_encryptor("lite") is get_field_encryptor("lite")
        assert get_field_encryptor("lite") is not get_field_encryptor("standard")


# ---------------------------------------------------------------------------
# ORM transparency (SQLite)
# ---------------------------------------------------------------------------


@pytest.fixture()
def db_session():
    """In-memory SQLite with the tables carrying encrypted columns."""
    engine = create_engine("sqlite://")
    tables = (
        User.__table__,
        Conversation.__table__,
        Message.__table__,
        EmotionDiary.__table__,
        EmotionDiaryView.__table__,
    )
    # SQLite only autoincrements INTEGER PRIMARY KEY (rowid alias) and
    # renders the MySQL LONGTEXT columns as TEXT; production MySQL is
    # unaffected by the temporary retype.
    from sqlalchemy.dialects.mysql import LONGTEXT
    from sqlalchemy.types import Text

    originals = {table: table.c.id.type for table in tables}
    longtext_columns = []
    for table in tables:
        table.c.id.type = Integer()
        for column in table.columns:
            if isinstance(column.type, LONGTEXT):
                longtext_columns.append((column, column.type))
                column.type = Text()
        table.create(engine)
        table.c.id.type = originals[table]
    for column, original in longtext_columns:
        column.type = original
    factory = sessionmaker(bind=engine)
    session = factory()
    yield session, engine
    session.close()
    engine.dispose()


def _user(session) -> User:
    user = User(
        porten_id="enc-user",
        email="enc@example.com",
        password_hash="x",
        nickname="enc",
    )
    session.add(user)
    session.flush()
    return user


class TestOrmTransparency:

    def test_message_content_encrypted_at_rest(self, db_session, settings):
        session, engine = db_session
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        settings.security_field_kek_kid = "env"
        reset_field_encryptors()
        try:
            user = _user(session)
            conversation = Conversation(
                type="friend", user_id=user.id, friend_user_id=user.id
            )
            session.add(conversation)
            session.flush()
            message = Message(
                conversation_id=conversation.id,
                sender_id=user.id,
                content="数据库里不该看到这句话",
                message_type="text",
                created_at=datetime.now(timezone.utc),
            )
            session.add(message)
            session.commit()

            # raw driver read bypasses result processing: envelope on disk
            raw = engine.connect().exec_driver_sql(
                "SELECT content FROM messages"
            ).scalar()
            assert raw.startswith(f"{ENVELOPE_VERSION}.env.")
            assert "不该看到" not in raw

            # ORM read decrypts transparently
            session.expire_all()
            assert session.get(Message, message.id).content == "数据库里不该看到这句话"
        finally:
            reset_field_encryptors()

    def test_legacy_plaintext_row_readable(self, db_session, settings):
        session, engine = db_session
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        reset_field_encryptors()
        try:
            user = _user(session)
            conversation = Conversation(
                type="friend", user_id=user.id, friend_user_id=user.id
            )
            session.add(conversation)
            session.flush()
            # Row written before encryption was enabled (raw SQL insert).
            inserted = engine.connect().exec_driver_sql(
                "INSERT INTO messages (conversation_id, sender_id, content, "
                "message_type, created_at) VALUES (?, ?, ?, ?, ?)",
                (
                    conversation.id,
                    user.id,
                    "legacy plaintext",
                    "text",
                    "2026-10-15 00:00:00",
                ),
            )
            legacy_id = inserted.lastrowid
            session.expire_all()
            # Note: encrypted columns are not searchable in SQL by design,
            # so the legacy row is fetched by primary key and must pass
            # through the decrypt path unchanged.
            assert session.get(Message, legacy_id).content == "legacy plaintext"
        finally:
            reset_field_encryptors()

    def test_preview_and_gender_round_trip(self, db_session, settings):
        session, _ = db_session
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        reset_field_encryptors()
        try:
            user = _user(session)
            user.gender = "non_binary"
            user.latest_diary = "今天的情绪日记内容"
            conversation = Conversation(
                type="friend",
                user_id=user.id,
                friend_user_id=user.id,
                last_message_text="预览：你好",
            )
            session.add(conversation)
            session.commit()
            session.expire_all()

            reloaded = session.get(User, user.id)
            assert reloaded.gender == "non_binary"
            assert reloaded.latest_diary == "今天的情绪日记内容"
            convo = session.get(Conversation, conversation.id)
            assert convo.last_message_text == "预览：你好"
        finally:
            reset_field_encryptors()

    def test_diary_content_encrypted_at_rest(self, db_session, settings):
        session, engine = db_session
        settings.security_kms_url = ""
        settings.security_field_kek = KEK
        reset_field_encryptors()
        try:
            user = _user(session)
            diary = EmotionDiary(
                user_id=user.id,
                content="日记正文，属于 P0 字段",
                mood="calm",
                is_current=True,
            )
            session.add(diary)
            session.commit()

            raw = engine.connect().exec_driver_sql(
                "SELECT content FROM emotion_diaries"
            ).scalar()
            assert raw.startswith(f"{ENVELOPE_VERSION}.env.")
            assert "日记正文" not in raw
            session.expire_all()
            assert session.get(EmotionDiary, diary.id).content == "日记正文，属于 P0 字段"
        finally:
            reset_field_encryptors()

    def test_no_key_configured_stores_plaintext(self, db_session, settings):
        session, engine = db_session
        settings.security_kms_url = ""
        settings.security_field_kek = ""
        reset_field_encryptors()
        try:
            user = _user(session)
            conversation = Conversation(
                type="friend", user_id=user.id, friend_user_id=user.id
            )
            session.add(conversation)
            session.flush()
            message = Message(
                conversation_id=conversation.id,
                sender_id=user.id,
                content="plaintext fallback",
                message_type="text",
                created_at=datetime.now(timezone.utc),
            )
            session.add(message)
            session.commit()
            raw = engine.connect().exec_driver_sql(
                "SELECT content FROM messages"
            ).scalar()
            assert raw == "plaintext fallback"
        finally:
            reset_field_encryptors()
