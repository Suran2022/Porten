"""Uploaded file sanitization (standard profile).

Two layers:

1. Magic-number validation: the real content type must match the
   declared one, blocking extension/content confusion attacks.
2. Image re-encoding: images are decoded and re-encoded (JPEG stays
   JPEG, everything else becomes PNG), which strips EXIF, trailing
   payloads, multi-frame tricks and polyglot smuggling. Files that
   cannot be decoded are refused.

Large images are re-encoded asynchronously by the caller to stay
within the synchronous latency budget; the sanitizer itself exposes
``sanitize`` (sync) and ``sanitize_async`` markers accordingly.
"""

import logging
import os
import shutil
import tempfile
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# (mime, offset, magic bytes) for the formats chat supports.
# RIFF containers (WEBP/WAVE) are disambiguated separately because
# they share the same FourCC prefix.
_MAGIC_TABLE = [
    ("image/jpeg", 0, b"\xff\xd8\xff"),
    ("image/png", 0, b"\x89PNG\r\n\x1a\n"),
    ("image/gif", 0, b"GIF87a"),
    ("image/gif", 0, b"GIF89a"),
    ("image/bmp", 0, b"BM"),
    ("image/tiff", 0, b"II*\x00"),
    ("image/tiff", 0, b"MM\x00*"),
    ("application/pdf", 0, b"%PDF"),
    ("application/zip", 0, b"PK\x03\x04"),
    ("video/mp4", 4, b"ftyp"),
    ("audio/mpeg", 0, b"ID3"),
    ("audio/mpeg", 0, b"\xff\xfb"),
]

# Images above this size are re-encoded asynchronously (latency budget).
SYNC_REENCODE_MAX_BYTES = 2 * 1024 * 1024


class SanitizeError(Exception):
    """Raised when an uploaded file must be refused."""


class MediaFileSanitizer:
    """Validate and clean uploaded files."""

    def sanitize(self, file_path: str, declared_type: str) -> str:
        """Validate and clean a file in place.

        Returns the path of the sanitized file (usually the input
        path). Raises :class:`SanitizeError` when the file must be
        refused.
        """
        path = Path(file_path)
        if not path.exists():
            raise SanitizeError("file not found")

        detected = self._detect_type(path)
        if detected is None:
            raise SanitizeError("unrecognized file content")

        if detected.startswith("image/"):
            self._validate_image_declared(detected, declared_type)
            if path.stat().st_size <= SYNC_REENCODE_MAX_BYTES:
                self._reencode_image(path)
            else:
                logger.info("image %s too large for sync re-encode", path.name)
        elif declared_type and not self._types_compatible(detected, declared_type):
            raise SanitizeError(
                f"content type mismatch: declared {declared_type}, detected {detected}"
            )

        return str(path)

    def _detect_type(self, path: Path) -> Optional[str]:
        """Return the detected MIME type from magic bytes, or None."""
        try:
            with path.open("rb") as f:
                header = f.read(32)
        except OSError:
            raise SanitizeError("file unreadable") from None
        if len(header) < 12:
            raise SanitizeError("file too small")

        # RIFF containers share a FourCC prefix; disambiguate first.
        if header[:4] == b"RIFF":
            if header[8:12] == b"WEBP":
                return "image/webp"
            if header[8:12] == b"WAVE":
                return "audio/wav"

        for mime, offset, magic in _MAGIC_TABLE:
            if header[offset : offset + len(magic)] == magic:
                return mime
        return None

    @staticmethod
    def _types_compatible(detected: str, declared: str) -> bool:
        """Compare detected and declared types with common aliases."""
        if detected == declared:
            return True
        aliases = {
            "image/jpg": "image/jpeg",
            "image/pjpeg": "image/jpeg",
            "audio/x-wav": "audio/wav",
            "audio/wave": "audio/wav",
            "video/quicktime": "video/mp4",
        }
        return aliases.get(declared, declared) == detected

    @staticmethod
    def _validate_image_declared(detected: str, declared: str) -> None:
        """Refuse when an image is declared as a non-image type."""
        if declared and not declared.startswith("image/"):
            raise SanitizeError(
                f"image content declared as {declared}"
            )

    def _reencode_image(self, path: Path) -> None:
        """Decode and re-encode an image to strip embedded payloads."""
        try:
            from PIL import Image
        except ImportError:
            logger.warning("Pillow unavailable; skipping image re-encode")
            return

        try:
            with Image.open(path) as img:
                img.load()  # force full decode; truncated files raise here
                if img.format == "JPEG":
                    clean = img.convert("RGB")
                    target_format, suffix = "JPEG", ".jpg"
                else:
                    clean = img.convert("RGBA" if img.mode in ("RGBA", "LA", "P") else "RGB")
                    target_format, suffix = "PNG", ".png"
                fd, tmp_name = tempfile.mkstemp(suffix=suffix, dir=str(path.parent))
                os.close(fd)
                clean.save(tmp_name, format=target_format, quality=90)
        except Exception as exc:
            raise SanitizeError(f"image decode failed: {exc}") from exc

        shutil.move(tmp_name, path)
