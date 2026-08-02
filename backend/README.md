# Porten Backend

基于 FastAPI + SQLAlchemy 的 Porten 通信平台后端服务。

## 技术栈

- **Web 框架**：FastAPI 0.115+
- **ORM**：SQLAlchemy 2.0（声明式映射）
- **数据库迁移**：Alembic
- **数据库**：MySQL 8.0+（utf8mb4）
- **认证**：JWT（python-jose）+ bcrypt 密码哈希
- **实时通信**：WebSocket（FastAPI 原生）
- **邮件**：aiosmtplib（异步发送验证码）
- **媒体处理**：ffmpeg（图片缩略图生成、视频转码）
- **配置管理**：pydantic-settings（环境变量 + .env 文件）

## 目录结构

```
backend/
├── app/
│   ├── migrations/          # Alembic 数据库迁移
│   │   ├── versions/        # 各版本迁移脚本（0001 ~ 0015）
│   │   ├── env.py
│   │   └── script.py.mako
│   ├── models/              # 数据模型（User/Conversation/Message 等）
│   ├── routers/             # API 路由（auth/messages/upload 等）
│   ├── schemas/             # Pydantic 请求/响应模型
│   ├── services/            # 业务逻辑服务
│   ├── dependencies/        # FastAPI 依赖注入
│   ├── utils/               # 工具函数（安全/校验）
│   ├── config.py            # 配置加载（环境变量）
│   ├── database.py          # 数据库会话
│   └── main.py              # 应用入口
├── tests/                   # 测试
├── alembic.ini              # Alembic 配置
├── requirements.txt         # Python 依赖
└── .env.example             # 环境变量示例
```

## 本地运行

### 1. 环境准备

- Python 3.11+
- MySQL 8.0+
- ffmpeg（媒体处理可选，但建议安装）

### 2. 安装依赖

```bash
cd backend
python -m venv venv
source venv/bin/activate    # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入数据库密码、SMTP 配置等
```

### 4. 创建数据库并执行迁移

```sql
-- 在 MySQL 中创建数据库
CREATE DATABASE porten CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

```bash
# 执行数据库迁移
alembic upgrade head
```

### 5. 启动服务

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

服务启动后访问 `http://localhost:8000/docs` 查看自动生成的 API 文档。

## 主要 API 模块

| 模块 | 路径前缀 | 说明 |
|------|----------|------|
| 认证 | `/api/v1/auth` | 注册/登录/验证码 |
| 用户 | `/api/v1/users` | 个人资料/头像/昵称 |
| 会话 | `/api/v1/conversations` | 好友/群组会话 |
| 消息 | `/api/v1/messages` | 文本/图片/视频/语音/文件 |
| 上传 | `/api/v1/upload` | 媒体文件上传（含缩略图/转码） |
| 联系人 | `/api/v1/contacts` | 好友/群组列表 |
| 群组 | `/api/v1/groups` | 创建/管理群组 |
| 情绪日记 | `/api/v1/emotion-diaries` | 情绪记录与分享 |
| 系统消息 | `/api/v1/system-messages` | 官方公告推送 |
| WebSocket | `/ws` | 实时消息推送 |
