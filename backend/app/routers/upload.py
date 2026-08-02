"""File upload endpoints for chat media and files."""

from __future__ import annotations

import os
import subprocess
import tempfile
import uuid
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models import MediaFile, User
from app.schemas.common import ResponseModel

router = APIRouter(prefix="/api/v1/upload", tags=["upload"])

UPLOAD_ROOT = Path(os.environ.get("PORTEN_UPLOAD_DIR", "uploads")).resolve()
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

# 缩略图最大宽度（按此宽度等比缩放，聊天列表用缩略图，预览用原图）
THUMB_MAX_WIDTH = 320

ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/heic",
    "image/heif",
    "image/avif",
    "image/bmp",
    "image/tiff",
}
ALLOWED_VIDEO_TYPES = {
    "video/mp4",
    "video/quicktime",
    "video/webm",
    "video/x-msvideo",
    "video/hevc",
    "video/h265",
    "video/x-matroska",
    "video/mpeg",
    "video/3gpp",
}
ALLOWED_FILE_TYPES = {
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "text/plain",
    "application/zip",
    "application/x-rar-compressed",
    "application/x-7z-compressed",
}
ALLOWED_VOICE_TYPES = {
    "audio/webm",
    "audio/mp4",
    "audio/mpeg",
    "audio/wav",
    "audio/wave",
    "audio/ogg",
    "audio/aac",
    "audio/opus",
    "audio/amr",
    "audio/x-m4a",
    "audio/x-wav",
}

MAX_IMAGE_SIZE = 20 * 1024 * 1024  # 20MB
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100MB
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
MAX_VOICE_SIZE = 10 * 1024 * 1024  # 10MB


def _save_upload_file(upload_file: UploadFile, subfolder: str) -> Path:
    ext = Path(upload_file.filename or "blob").suffix
    if not ext or len(ext) > 10:
        ext = ""
    filename = f"{uuid.uuid4().hex}{ext}"
    folder = UPLOAD_ROOT / subfolder
    folder.mkdir(parents=True, exist_ok=True)
    dest = folder / filename
    with dest.open("wb") as f:
        while True:
            chunk = upload_file.file.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
    return dest


def _public_url(file_path: Path) -> str:
    rel = file_path.relative_to(UPLOAD_ROOT)
    return f"/uploads/{rel.as_posix()}"


def _generate_image_thumbnail(source: Path) -> Optional[Path]:
    """用 ffmpeg 生成图片缩略图，宽度限制为 THUMB_MAX_WIDTH，等比缩放。
    生成 JPEG 格式（体积小），保存到 images/_thumbs/ 目录。
    返回缩略图路径；失败返回 None。
    """
    try:
        thumb_dir = UPLOAD_ROOT / "images" / "_thumbs"
        thumb_dir.mkdir(parents=True, exist_ok=True)
        thumb_name = f"{source.stem}.jpg"
        thumb_path = thumb_dir / thumb_name
        # -vf scale=W:-1 表示宽度固定 W，高度按比例自适应
        result = subprocess.run(
            [
                "ffmpeg", "-y", "-i", str(source),
                "-vf", f"scale={THUMB_MAX_WIDTH}:-1",
                "-q:v", "3",
                str(thumb_path),
            ],
            capture_output=True,
            timeout=30,
        )
        if result.returncode != 0 or not thumb_path.exists():
            return None
        return thumb_path
    except Exception:
        return None


def _transcode_video_to_mp4(source: Path) -> Optional[Path]:
    """用 ffmpeg 把视频转码为 H.264 + AAC 的 mp4（所有浏览器兼容）。
    返回新的 mp4 路径；失败返回 None（调用方保留原文件）。
    """
    try:
        out_dir = source.parent
        out_path = out_dir / f"{source.stem}.mp4"
        result = subprocess.run(
            [
                "ffmpeg", "-y", "-i", str(source),
                "-c:v", "libx264", "-preset", "veryfast",
                "-crf", "26",
                "-c:a", "aac", "-b:a", "128k",
                "-movflags", "+faststart",
                "-pix_fmt", "yuv420p",
                str(out_path),
            ],
            capture_output=True,
            timeout=300,
        )
        if result.returncode != 0 or not out_path.exists():
            return None
        return out_path
    except Exception:
        return None


@router.post("/image", response_model=ResponseModel[dict])
def upload_image(
    file: UploadFile = File(...),
    permanent: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload an image for a chat message or group avatar."""
    content_type = file.content_type or ""
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="unsupported image type",
        )
    if file.size and file.size > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="image too large",
        )

    from datetime import datetime, timezone
    from app.models.media_file import MEDIA_TTL_DAYS
    from datetime import timedelta

    dest = _save_upload_file(file, "images")
    # 生成缩略图（失败不影响上传，预览用原图，列表用缩略图）
    thumb_path = _generate_image_thumbnail(dest)
    media = MediaFile(
        uploader_id=current_user.id,
        file_path=str(dest),
        file_type="image",
        original_name=file.filename,
        file_size=file.size,
        expires_at=None if permanent else datetime.now(timezone.utc) + timedelta(days=MEDIA_TTL_DAYS),
    )
    db.add(media)
    db.commit()
    db.refresh(media)

    # 返回缩略图 URL（聊天列表用），thumb_url 缺省时前端回退用原图
    thumb_url = _public_url(thumb_path) if thumb_path else None
    return ResponseModel(
        data={
            "media_file_id": media.id,
            "url": _public_url(dest),
            "thumb_url": thumb_url,
            "name": file.filename,
            "size": file.size,
        }
    )


@router.post("/video", response_model=ResponseModel[dict])
def upload_video(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a video for a chat message."""
    content_type = file.content_type or ""
    if content_type not in ALLOWED_VIDEO_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="unsupported video type",
        )
    if file.size and file.size > MAX_VIDEO_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="video too large",
        )

    dest = _save_upload_file(file, "videos")
    # 非 mp4 视频转码为 H.264 mp4（浏览器兼容），转码成功后删除原文件
    final_path = dest
    if dest.suffix.lower() != ".mp4":
        transcoded = _transcode_video_to_mp4(dest)
        if transcoded is not None:
            try:
                dest.unlink()
            except OSError:
                pass
            final_path = transcoded
    media = MediaFile(
        uploader_id=current_user.id,
        file_path=str(final_path),
        file_type="video",
        original_name=file.filename,
        file_size=final_path.stat().st_size if final_path.exists() else file.size,
        expires_at=None,
    )
    db.add(media)
    db.commit()
    db.refresh(media)

    return ResponseModel(
        data={
            "media_file_id": media.id,
            "url": _public_url(final_path),
            "name": file.filename,
            "size": file.size,
        }
    )


@router.post("/file", response_model=ResponseModel[dict])
def upload_file(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a generic file for a chat message."""
    content_type = file.content_type or ""
    if content_type not in ALLOWED_FILE_TYPES:
        # Allow arbitrary files up to size limit as a fallback
        pass
    if file.size and file.size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="file too large",
        )

    dest = _save_upload_file(file, "files")
    media = MediaFile(
        uploader_id=current_user.id,
        file_path=str(dest),
        file_type="file",
        original_name=file.filename,
        file_size=file.size,
        expires_at=None,
    )
    db.add(media)
    db.commit()
    db.refresh(media)

    return ResponseModel(
        data={
            "media_file_id": media.id,
            "url": _public_url(dest),
            "name": file.filename,
            "size": file.size,
        }
    )


@router.post("/voice", response_model=ResponseModel[dict])
def upload_voice(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a voice message audio file."""
    content_type = file.content_type or ""
    if content_type not in ALLOWED_VOICE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="unsupported audio type",
        )
    if file.size and file.size > MAX_VOICE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="voice message too large",
        )

    dest = _save_upload_file(file, "voice")
    media = MediaFile(
        uploader_id=current_user.id,
        file_path=str(dest),
        file_type="voice",
        original_name=file.filename,
        file_size=file.size,
        expires_at=None,
    )
    db.add(media)
    db.commit()
    db.refresh(media)

    return ResponseModel(
        data={
            "media_file_id": media.id,
            "url": _public_url(dest),
            "name": file.filename,
            "size": file.size,
        }
    )
