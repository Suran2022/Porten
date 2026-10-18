# Porten 部署文档

> 三种部署方式按需选一。**先读 [通用准备](#0-通用准备)**，所有方式都依赖它。

| 方式 | 适合场景 | 难度 | 上线耗时 |
|---|---|---|---|
| [方式一：Docker Compose](#一docker-部署推荐) | 自有服务器，一键起全套 | ⭐ | ~10 分钟 |
| [方式二：手动部署](#二手动部署) | 宝塔面板用户 / 需要精细控制 | ⭐⭐ | ~30 分钟 |
| [方式三：Railway 体验部署](#三体验型部署railway) | 零服务器快速体验 | ⭐ | ~5 分钟 |

技术栈：后端 FastAPI + MySQL 8 + Redis（Python 3.11）；前端 React 18 + Vite（Node 20）；后端依赖 **ffmpeg**（聊天视频转码）。

---

## 0. 通用准备

无论哪种方式，都需要先准备以下配置项（后端 `backend/.env`，从 `backend/.env.example` 复制）：

```ini
# 数据库（按部署方式填写，Docker/Railway 见对应章节）
database_url=mysql+pymysql://用户:密码@主机:3306/porten?charset=utf8mb4

# Redis
redis_url=redis://主机:6379/0

# 邮件验证码（二选一：配了 resend_api_key 走 Resend API，否则走 SMTP）
resend_api_key=re_xxxxxxxx          # 推荐，注册 Railway/Resend 免费额度即可用
smtp_host=smtp.qq.com
smtp_port=465
smtp_username=xxx@qq.com
smtp_password=授权码                  # QQ 邮箱是"授权码"不是登录密码
smtp_sender_name=Porten

# 应用
app_timezone=Asia/Shanghai
```

前端环境变量（构建期注入，见各方式说明）：

| 变量 | 说明 | 示例 |
|---|---|---|
| `VITE_API_BASE_URL` | 后端 API 地址 | `/api/v1`（同域反代）或 `https://api.xxx.com/api/v1` |
| `VITE_API_WS_URL` | WebSocket 地址 | `/ws`（同域）或 `wss://api.xxx.com/ws` |
| `VITE_USE_MOCK` | 必须为 `false` 才连真实后端 | `false` |

---

## 一、Docker 部署（推荐）

```bash
# 1. 服务器安装 Docker（已装跳过）
curl -fsSL https://get.docker.com | sh

# 2. 拉取代码
git clone https://github.com/Suran2022/Porten.git && cd Porten

# 3. 配置后端环境变量
cp backend/.env.example backend/.env && vi backend/.env   # 按第 0 节填写

# 4. 一键启动（自动建库 + 自动执行数据库迁移）
docker compose up -d

# 5. 查看状态与日志
docker compose ps
docker compose logs -f backend    # 看到 "Uvicorn running" 即成功
```

访问 `http://服务器IP`（前端容器映射 80 端口）。数据持久化在 `mysql-data`、`redis-data`、`backend-uploads` 三个卷中，`docker compose down` 不丢数据。

### 常见问题排查

| 现象 | 原因 | 解决 |
|---|---|---|
| `backend` 容器反复重启 | MySQL 未就绪或 `database_url` 错误 | `docker compose logs backend` 看报错；compose 已配健康检查会自动等待 |
| 迁移报 `Access denied` | root 密码不一致 | `MYSQL_ROOT_PASSWORD` 与注入 backend 的 `database_url` 必须一致（compose 已自动对齐，勿手改） |
| 验证码邮件收不到 | Resend key 无效 / SMTP 授权码错 / 发件人未验证 | 先在 Railway 日志或 `docker compose logs backend` 搜 `email`；Resend 需先在后台验证发件域名或用 `onboarding@resend.dev` 测试 |
| 图片/视频上传失败 | 上传目录权限或体积限制 | compose 已挂载 `backend-uploads` 卷；Nginx 默认限 100m，按需改 `frontend/nginx.conf` |
| 前端能开但一直加载中 | `VITE_API_*` 指向错误 | 前端变量是**构建期**注入的，改 `.env` 后需 `docker compose build frontend && docker compose up -d frontend` |
| WebSocket 连不上 | 反代未升级协议 | compose 内置 nginx.conf 已处理；自配反代时必须加 `Upgrade`/`Connection` 头 |
| 80 端口被占用 | 服务器已有其他站点 | 改 compose 里 `ports: "8080:80"`，用 `http://IP:8080` 访问 |

---

## 二、手动部署

### 2A. 宝塔面板

```bash
# 1. 面板内安装：Nginx、MySQL 8.0、Redis（软件商店）
# 2. 创建数据库：面板 → 数据库 → 添加，名为 porten，编码 utf8mb4，记下账号密码
# 3. 上传代码：面板 → 文件 → 上传并解压到 /www/wwwroot/Porten
```

**后端（面板 → 网站 → Python 项目 → 添加项目）：**

| 配置项 | 值 |
|---|---|
| 项目路径 | `/www/wwwroot/Porten/backend` |
| Python 版本 | 3.11+ |
| 启动方式 | `gunicorn` 或命令启动 |
| 启动命令 | `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2` |
| 环境变量 | 按第 0 节填 `backend/.env` |

**前端（面板终端执行）：**

```bash
cd /www/wwwroot/Porten/frontend
npm ci
VITE_API_BASE_URL=/api/v1 VITE_API_WS_URL=/ws VITE_USE_MOCK=false npm run build
# 产物在 dist/，面板 → 网站 → 添加静态站点，根目录指向 dist
```

**反向代理（站点设置 → 反向代理 → 配置文件，替换默认内容）：** 直接粘贴仓库内 `frontend/nginx.conf` 中 `/api/` 与 `/ws` 两段 location 到站点配置，并把 `proxy_pass http://backend:8000` 改为 `proxy_pass http://127.0.0.1:8000`。

### 2B. 命令行（裸机 / VPS）

```bash
# ---- 后端 ----
git clone https://github.com/Suran2022/Porten.git && cd Porten/backend
python3.11 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
sudo apt install -y ffmpeg                    # 视频转码依赖，必须
cp .env.example .env && vi .env               # 按第 0 节填写
alembic upgrade head                          # 建表/迁移
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2

# ---- 前端 ----
cd ../frontend
npm ci
VITE_API_BASE_URL=/api/v1 VITE_API_WS_URL=/ws VITE_USE_MOCK=false npm run build
# 用 Nginx 托管 dist/ 并反代 /api 与 /ws（配置参考 frontend/nginx.conf）
```

**进程守护（生产必须，任选其一）：**

```bash
# systemd（推荐）：写入 /etc/systemd/system/porten.service
[Unit]
Description=Porten Backend
After=network.target mysql.service
[Service]
WorkingDirectory=/opt/Porten/backend
EnvironmentFile=/opt/Porten/backend/.env
ExecStart=/opt/Porten/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
Restart=always
[Install]
WantedBy=multi-user.target
# systemctl daemon-reload && systemctl enable --now porten
```

### 常见问题排查

| 现象 | 原因 | 解决 |
|---|---|---|
| `pip install` 报 `numpy` 编译错误 | Python 版本低于 3.10 | 升级 Python 3.11；或先 `pip install --upgrade pip setuptools wheel` |
| `alembic` 报 `Can't connect to MySQL` | 连接串/防火墙 | 检查 `database_url`；`mysql -h 主机 -u 用户 -p` 手动连通性测试；MySQL 8 认证插件问题加 `?charset=utf8mb4`（已含） |
| 视频上传后无法播放 / 缩略图空白 | 未装 ffmpeg | `ffmpeg -version` 验证；宝塔用户在终端手动 `apt/yum install ffmpeg` |
| 启动报 `ModuleNotFoundError` | 未激活虚拟环境就启动 | `source venv/bin/activate` 后再执行；或用 venv 内绝对路径的 uvicorn |
| 前端刷新 404 | Nginx 未配 SPA 回落 | `try_files $uri $uri/ /index.html;` 必须有（见 nginx.conf） |
| Nginx 反代后上传大文件 413 | 体积限制 | 站点配置加 `client_max_body_size 100m;` |
| 邮件发送超时 | 服务器封锁 465/587 端口（如部分云商默认封 25/465） | 优先改用 `resend_api_key`（走 HTTPS 443，不依赖 SMTP 端口） |

---

## 三、体验型部署（Railway）

> 零服务器、5 分钟上线，适合体验与演示。免费额度足够小规模试用。

```text
1. Fork 本仓库到你的 GitHub 账号
2. Railway 控制台 → New Project → Deploy from GitHub repo → 选择 Fork
```

**依次创建 4 个服务：**

| 服务 | 来源 | 关键配置 |
|---|---|---|
| MySQL | Railway Database → MySQL | 创建后复制 `DATABASE_URL` |
| Redis | Railway Database → Redis | 复制 `REDIS_URL` |
| Backend | 同一仓库，Root Directory=`backend` | 环境变量见下表；`database_url` 用 MySQL 内网地址（把 `mysql://` 改为 `mysql+pymysql://`，库名后加 `?charset=utf8mb4`） |
| Frontend | 同一仓库，Root Directory=`frontend` | 构建变量 `VITE_API_BASE_URL=https://<后端域名>/api/v1`、`VITE_API_WS_URL=wss://<后端域名>/ws`、`VITE_USE_MOCK=false`；启动命令 `npx serve dist -l $PORT -s`（静态托管 SPA） |

**后端环境变量（Railway → Backend → Variables）：**

```ini
database_url=mysql+pymysql://root:密码@mysql容器主机:3306/railway?charset=utf8mb4
redis_url=redis://redis容器主机:6379/0
resend_api_key=re_xxxxxxxx
app_timezone=Asia/Shanghai
```

**生成公网域名**：每个服务 → Settings → Networking → Generate Domain。前端域名即为体验入口。

**首次部署**：Backend 部署命令设为 `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2`（Railway 注入 `$PORT`）。

### 常见问题排查

| 现象 | 原因 | 解决 |
|---|---|---|
| Backend 部署后立刻 Crash | 未配 `database_url` 或格式错 | 必须是 `mysql+pymysql://` 前缀；Railway MySQL 的私网变量是 `MYSQLURL`，手动改前缀后粘贴 |
| 日志大量 `Root logger` 无输出 | 日志级别 | 正常现象；邮件投递日志为 warning 级可见 |
| 前端 CORS 报错 | 后端 CORS 中间件限制了来源 | 当前代码 `allow_origins=["*"]` 全放行，一般不会出现；若收紧过 `backend/app/main.py` 的 CORS 配置，把前端域名加入 `allow_origins` |
| 验证码邮件进垃圾箱 / 收不到 | Resend 免费发件域名限制 | 用 `onboarding@resend.dev` 发件测试；正式使用需在 Resend 验证自有域名 |
| 免费额度耗尽服务休眠 | Railway 试用计划限制 | 升级 Hobby 计划；或部署到自有服务器（方式一） |
| 数据库表不存在（500 错误） | 未跑迁移 | 确认启动命令含 `alembic upgrade head` |

---

## CI/CD 自动化部署

仓库内置两条 GitHub Actions 流水线，Fork 后即可使用：

| 流水线 | 文件 | 触发 | 作用 |
|---|---|---|---|
| CI | `.github/workflows/ci.yml` | push / PR 到 main | 后端 pytest + 前端类型检查与构建，不通过不允许合并 |
| CD | `.github/workflows/deploy.yml` | push 到 main | 自动构建前后端 Docker 镜像并推送 GHCR（`ghcr.io/<用户>/porten-backend/frontend`） |

**开启自动部署到自有服务器（可选）：**

1. 服务器上按「方式一」完成首次部署，确保 `docker-compose.yml` 与 `backend/.env` 就位
2. 仓库 Settings → **Variables** 新增 `DEPLOY_ENABLED=true`
3. Settings → **Secrets → Actions** 依次添加：

   | Secret | 值 |
   |---|---|
   | `DEPLOY_HOST` | 服务器 IP |
   | `DEPLOY_USER` | SSH 用户（需 docker 权限） |
   | `DEPLOY_SSH_KEY` | SSH 私钥全文（`cat ~/.ssh/id_ed25519`） |
   | `DEPLOY_PATH` | 服务器项目路径，如 `/opt/Porten` |

4. 之后每次 push 到 main：CI 测试 → 构建镜像 → SSH 到服务器执行 `docker compose pull && up -d`，全自动

**拉取预构建镜像（不想自己构建）：** 镜像公开后可直接 `docker pull ghcr.io/<仓库所有者>/porten-backend:latest`，配合仓库内 `docker-compose.yml` 把 `build:` 段替换为 `image:` 即可。

### CI/CD 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| CI 后端测试失败：数据库连接 | 测试默认用 SQLite 内存库 | 无需配置 MySQL；若改过测试配置，检查 `database_url` 环境变量 |
| CD 推送 GHCR 403 | 仓库 Packages 权限 | Settings → Actions → General → Workflow permissions 选 Read and write |
| GHCR 镜像拉取 401 | 镜像默认私有 | GitHub → Packages → 该镜像 → Package settings → Change visibility → Public |
| SSH 部署步骤被跳过 | 未设 `DEPLOY_ENABLED` | 这是设计行为（未配置服务器时只构建不部署） |
| 服务器 `docker compose pull` 失败 | 未登录 GHCR | 服务器执行 `docker login ghcr.io -u <用户名> -p <PAT>` |

---

## 部署后验证清单

```bash
# 1. 后端存活（健康端点不带 /api/v1 前缀）
curl http://<后端地址>/health   # 返回 JSON 即通

# 2. 注册流程：前端注册页输入真实邮箱 → 收到验证码邮件 → 完成注册
# 3. 登录后检查 WebSocket：进入消息页，控制台 Network → WS 显示 101
# 4. 上传验证：发送一张图片与一段视频，刷新后仍可查看（持久化生效）
# 5. 数据持久化：docker compose down && up -d 后数据仍在
```
