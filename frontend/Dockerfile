# Porten 前端镜像：Vite 构建产物 + Nginx 托管（含 /api 反代与 /ws WebSocket 升级）
FROM node:20-alpine AS build

WORKDIR /app
COPY package.json package-lock.json* ./
# fetch-retry 系列：CI runner 访问 npm registry 偶发 ECONNRESET，加重试避免流水线随机失败
RUN npm ci --fetch-retries=5 --fetch-retry-mintimeout=20000 --fetch-retry-maxtimeout=120000 --no-audit --no-fund

COPY . .
# 构建期注入后端地址（build args），产物为纯静态文件
ARG VITE_API_BASE_URL=/api/v1
ARG VITE_API_WS_URL=/ws
ARG VITE_USE_MOCK=false
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_API_WS_URL=$VITE_API_WS_URL \
    VITE_USE_MOCK=$VITE_USE_MOCK
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK CMD wget -qO- http://localhost/ >/dev/null 2>&1 || exit 1
