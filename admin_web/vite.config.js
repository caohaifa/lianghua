import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',   // 监听所有网卡,规避 Windows localhost 解析到 IPv6 导致拒绝连接
    port: 5173,
    strictPort: true,  // 端口被占直接报错,而不是悄悄换端口
    // 开发环境把 /api 代理到 Java 后端,避免跨域并与生产路径一致
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
})
