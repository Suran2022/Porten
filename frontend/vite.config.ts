import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tsconfigPaths from "vite-tsconfig-paths";

// https://vite.dev/config/
export default defineConfig({
  build: {
    // source map 用 hidden 模式：生成 .map 文件用于容灾恢复，但不暴露给浏览器
    sourcemap: 'hidden',
    // 代码分割：把大依赖拆成独立 chunk，并行加载
    rollupOptions: {
      output: {
        manualChunks: {
          // React 核心
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          // 状态管理
          'state': ['zustand'],
          // UI 图标库（最大的依赖）
          'icons': ['lucide-react'],
          // PDF 生成（懒加载，仅在下载协议时加载）
          'pdf': ['html2pdf.js', 'jspdf', 'html2canvas', 'canvg'],
        },
      },
    },
    // 提高 chunk 大小警告阈值
    chunkSizeWarningLimit: 600,
  },
  server: {
    port: 3002,
    // 开发环境代理：将前端请求转发到本地后端
    // 请根据你的后端实际地址和端口修改 target
    proxy: {
      '/api/v1': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
      },
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true,
        changeOrigin: true,
        secure: false,
      },
    },
  },
  plugins: [
    react({
      babel: {
        plugins: [
          'react-dev-locator',
        ],
      },
    }),
    tsconfigPaths()
  ],
})
