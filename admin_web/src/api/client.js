import axios from 'axios'
import { message } from 'antd'

/**
 * 统一 axios 实例
 * baseURL /api/v1(开发环境由 Vite 代理到 8080)
 * 自动携带管理员 Token;401 时清除登录态并跳转登录页。
 */
const client = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
})

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

client.interceptors.response.use(
  (response) => {
    const body = response.data
    // 后端统一包装 {code,message,data};非 200 视为业务错误
    if (body && typeof body.code !== 'undefined' && body.code !== 200) {
      message.error(body.message || '请求失败')
      return Promise.reject(new Error(body.message || 'Business error'))
    }
    return body
  },
  (error) => {
    const status = error.response?.status
    if (status === 401) {
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      message.error('登录已过期,请重新登录')
      // 避免在登录页重复跳转
      if (!window.location.hash.includes('/login')) {
        window.location.hash = '#/login'
      }
    } else if (status === 403) {
      message.error(error.response?.data?.message || '无操作权限')
    } else {
      message.error(error.response?.data?.message || error.message || '网络错误')
    }
    return Promise.reject(error)
  },
)

export default client
