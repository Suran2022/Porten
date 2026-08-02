<div align="center">

# Porten

### 一个为跨性别群体打造的温暖通信与社区平台

💌 安全 · 包容 · 连接 · 治愈

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Frontend](https://img.shields.io/badge/Frontend-React_18-61DAFB.svg)](https://react.dev/)
[![Backend](https://img.shields.io/badge/Backend-FastAPI-009688.svg)](https://fastapi.tiangolo.com/)
[![Database](https://img.shields.io/badge/Database-MySQL_8-4479A1.svg)](https://www.mysql.com/)

</div>

---

## 📖 项目介绍

**Porten** 是一个专门为跨性别群体设计与开发的通信与社区平台。我们希望为同胞们提供一个安全、友善、包容的线上家园，让每一位个体都能在这里自由表达、彼此连接、获得支持。

在这里，你可以与同胞即时通信、分享心情日记、获取知识与资源、感受音乐治愈——在一个理解你、尊重你的社区中，做最真实的自己。

### 🌈 核心理念

- **安全包容**：为跨性别群体提供免于歧视与骚扰的安全空间
- **温暖治愈**：通过情绪日记、音乐分享等功能陪伴每一位同胞
- **连接互助**：打通同胞之间的沟通桥梁，构建互助社区
- **资源赋能**：整合医疗、法律、组织等资源，为同胞提供实用支持

---

## ✨ 功能特性

### 即时通信
- 💬 **多类型消息**：文本、图片、视频、语音、文件，全方位沟通
- 🖼️ **媒体智能处理**：图片自动生成缩略图、视频自动转码为 mp4，加载快人一步
- 🔒 **媒体永久保存**：聊天媒体永久存储，不会过期"被清理"
- ⚡ **WebSocket 实时推送**：消息即时到达，离线消息自动同步
- 👥 **好友与群组**：一对一私聊与多人群聊，自由连接同胞
- 📱 **移动端优化**：双指缩放预览、语音录制、移动端交互全面适配

### 情绪日记
- 📝 **每日心情记录**：用文字与心情标签记录每一天
- 🎨 **多维度情绪标签**：开心、平静、焦虑、感恩……精准表达内心
- 👀 **可见性管理**：自主控制日记的可见范围
- 📜 **历史回顾**：翻阅过往日记，见证成长轨迹

### 同胞社区
- 🤝 **同胞资料页**：了解每一位同胞的故事
- 🎵 **音乐分享**：用音乐传递情感，治愈彼此
- 📢 **系统通知**：官方公告与版本更新及时触达
- 🏥 **资源中心**：医疗、组织、流程指引等实用资源聚合

### 账号与安全
- 🔐 **邮箱验证码登录**：无需记忆密码，验证码即可登录
- 🛡️ **Porten ID**：专属身份标识，保护隐私
- 📋 **完善的协议体系**：用户协议、隐私政策、跨性别权益保护声明
- 🔄 **邮箱更换**：支持安全更换绑定邮箱

---

## 📸 功能截图

<div align="center">

| 登录页面 | 即时通信 | 个人主页与情绪日记 |
|:---:|:---:|:---:|
| ![登录页面](./docs/screenshots/login.jpg) | ![即时通信](./docs/screenshots/chat.jpg) | ![个人主页](./docs/screenshots/profile.jpg) |

> 以上为产品概念展示图，实际界面请下载运行后体验。

</div>

---

## 🛠️ 技术栈

### 前端

| 技术 | 说明 |
|------|------|
| [React 18](https://react.dev/) | UI 框架（Hooks + 函数组件） |
| [TypeScript](https://www.typescriptlang.org/) | 类型安全 |
| [Vite](https://vitejs.dev/) | 构建工具（快速 HMR + 代码分割） |
| [Tailwind CSS](https://tailwindcss.com/) | 原子化 CSS 样式 |
| [Zustand](https://github.com/pmndrs/zustand) | 轻量状态管理 |
| [React Router](https://reactrouter.com/) | 路由管理 |
| [Lucide React](https://lucide.dev/) | 图标库 |
| IndexedDB | 本地消息缓存（离线可读） |

### 后端

| 技术 | 说明 |
|------|------|
| [FastAPI](https://fastapi.tiangolo.com/) | 高性能异步 Web 框架 |
| [SQLAlchemy 2.0](https://www.sqlalchemy.org/) | ORM（声明式映射） |
| [Alembic](https://alembic.sqlalchemy.org/) | 数据库迁移 |
| [MySQL 8.0+](https://www.mysql.com/) | 关系型数据库 |
| [python-jose](https://github.com/mpdavis/python-jose) | JWT 认证 |
| [aiosmtplib](https://github.com/cole/aiosmtplib) | 异步邮件发送 |
| [WebSocket](https://fastapi.tiangolo.com/advanced/websockets/) | 实时消息推送 |
| [ffmpeg](https://ffmpeg.org/) | 媒体处理（缩略图/转码） |
| [pydantic-settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/) | 配置管理 |

---

## 🚀 本地运行

### 环境要求

- **Node.js** 18+（推荐 20 LTS）
- **Python** 3.11+
- **MySQL** 8.0+
- **ffmpeg**（可选，用于媒体处理）

### 1. 克隆仓库

```bash
git clone https://github.com/Suran2022/Porten.git
cd Porten
```

### 2. 启动后端

```bash
cd backend

# 创建虚拟环境
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env，填入数据库密码、SMTP 配置等
```

创建数据库并执行迁移：

```sql
-- 在 MySQL 中执行
CREATE DATABASE porten CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

```bash
# 执行数据库迁移
alembic upgrade head

# 启动后端服务（默认端口 8000）
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

启动后访问 `http://localhost:8000/docs` 查看 API 文档。

### 3. 启动前端

```bash
cd frontend

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 默认配置已指向 localhost:8000，无需修改即可本地开发

# 启动开发服务器（默认端口 5173）
npm run dev
```

浏览器访问 `http://localhost:5173` 即可使用。

### 4. 生产构建

```bash
cd frontend
npm run build
# 构建产物在 frontend/dist/，可由 Nginx 托管
```

---

## 📁 项目结构

```
Porten/
├── backend/                    # 后端服务
│   ├── app/
│   │   ├── migrations/         # 数据库迁移脚本
│   │   ├── models/             # 数据模型
│   │   ├── routers/            # API 路由
│   │   ├── schemas/            # 请求/响应模型
│   │   ├── services/           # 业务逻辑
│   │   ├── dependencies/       # 依赖注入
│   │   ├── utils/              # 工具函数
│   │   ├── config.py           # 配置加载
│   │   ├── database.py         # 数据库会话
│   │   └── main.py             # 应用入口
│   ├── tests/
│   ├── alembic.ini
│   ├── requirements.txt
│   └── .env.example
├── frontend/                   # 前端应用
│   ├── src/
│   │   ├── components/         # 组件（home/profile/knowledge/resource）
│   │   ├── pages/              # 页面
│   │   ├── store/              # Zustand 状态管理
│   │   ├── hooks/              # 自定义 Hooks
│   │   ├── lib/                # API/缓存/工具
│   │   ├── types/              # TypeScript 类型
│   │   └── data/               # 静态数据
│   ├── public/
│   ├── index.html
│   ├── vite.config.ts
│   └── package.json
├── docs/
│   └── screenshots/            # 功能截图
├── LICENSE
├── README.md
└── .gitignore
```

---

## 🔧 配置说明

### 后端配置（`backend/.env`）

| 变量 | 说明 | 示例 |
|------|------|------|
| `DATABASE_URL` | MySQL 连接串 | `mysql+pymysql://root:password@localhost:3306/porten?charset=utf8mb4` |
| `SECRET_KEY` | JWT 签名密钥 | 随机字符串（至少 32 字符） |
| `SMTP_HOST` | SMTP 服务器 | `smtp.qq.com` |
| `SMTP_PORT` | SMTP 端口 | `465` |
| `SMTP_USERNAME` | 发件邮箱 | `your_email@qq.com` |
| `SMTP_PASSWORD` | SMTP 授权码 | 邮箱开启 SMTP 后获取 |
| `DEFAULT_AVATAR_URL` | 默认头像 | URL 地址 |

### 前端配置（`frontend/.env`）

| 变量 | 说明 | 示例 |
|------|------|------|
| `VITE_API_BASE_URL` | API 基础路径 | `/api/v1` |
| `VITE_API_WS_URL` | WebSocket 地址 | `ws://localhost:8000/ws` |

---

## 📜 开源协议

本项目基于 [**Apache License 2.0**](./LICENSE) 开源。

你可以自由地使用、修改、分发本项目，但请保留原始版权声明。我们鼓励同胞们参与共建，让 Porten 变得更好。

---

## 🤝 参与贡献

欢迎同胞们为 Porten 贡献力量！

- 🐛 发现 Bug？[提交 Issue](https://github.com/Suran2022/Porten/issues)
- 💡 有新想法？欢迎在 Issue 中讨论
- 🔧 想贡献代码？欢迎提交 Pull Request
- ⭐ 觉得有用？给项目点个 Star 是对我们最大的鼓励

---

## ❤️ 支持与资助

Porten 是一个由热爱驱动的开源项目，致力于为跨性别群体提供温暖的数字家园。如果你喜欢这个项目，欢迎支持我们：

### 点赞支持

⭐ **给项目点 Star** —— 这是对我们最简单也最重要的鼓励，让更多同胞看到这个项目

### 资助渠道

如果你的经济条件允许，欢迎资助我们，帮助我们：

- 🖥️ 维持服务器与带宽运转
- 🎨 持续优化产品体验
- 📱 投入 APP 研发，为同胞带来更流畅的移动体验
- 🌍 推动项目长期可持续发展

> 💝 **资助方式**：请通过 Issue 或项目主页公布的联系方式与我们取得联系，我们将提供资助渠道。
>
> 每一份支持，都是对同胞群体的温暖守护。感谢你的信任与陪伴。

---

## 📮 联系我们

- **项目仓库**：[https://github.com/Suran2022/Porten](https://github.com/Suran2022/Porten)
- **Issue 反馈**：[https://github.com/Suran2022/Porten/issues](https://github.com/Suran2022/Porten/issues)

---

<div align="center">

**愿每一位同胞，都能在 Porten 找到归属与温暖。** 🌈

Made with ❤️ by Porten Team

</div>
