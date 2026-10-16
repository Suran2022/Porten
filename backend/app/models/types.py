"""Custom column types shared by ORM models."""

from typing import Optional

from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.types import Text, TypeDecorator


class EncryptedText(TypeDecorator):
    """Transparently application-encrypted text column (design doc §5.4.2).

    Values are sealed by the active profile's field encryptor on write
    and opened on read, so business code keeps working with plaintext
    while P0 fields never reach the database unencrypted. Legacy
    plaintext rows (written before encryption was enabled) are detected
    by the missing envelope prefix and pass through unchanged.

    The column is LONGTEXT on MySQL (envelopes exceed plaintext length)
    and plain TEXT elsewhere. The encryptor is resolved lazily per
    operation so profile switches and key configuration apply without
    restarting the mapper.
    """

    impl = Text().with_variant(LONGTEXT(), "mysql")
    cache_ok = True

    def process_bind_param(self, value: Optional[str], dialect) -> Optional[str]:
        if not value:
            return value
        from app.services.field_encryption_service import get_field_encryptor

        return get_field_encryptor().encrypt(value)

    def process_result_value(self, value: Optional[str], dialect) -> Optional[str]:
        if not value:
            return value
        from app.services.field_encryption_service import get_field_encryptor

        return get_field_encryptor().decrypt(value)
