# Porten 后端镜像：FastAPI + uvicorn（含 ffmpeg：聊天媒体视频转码依赖）
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# ffmpeg：上传媒体的视频转 mp4 / 缩略图生成；curl 用于容器健康检查
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# 上传媒体挂载点（聊天图片/视频/语音永久存储）
RUN mkdir -p /app/uploads

EXPOSE 8000

# 启动前自动执行数据库迁移；失败即退出，避免带病启动
CMD alembic upgrade head && \
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
