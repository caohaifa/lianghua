import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import zhCN from 'antd/locale/zh_CN'
import { AuthProvider, useAuth } from './auth/AuthContext'
import MainLayout from './layout/MainLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import Orders from './pages/Orders'
import Positions from './pages/Positions'
import Wallet from './pages/Wallet'
import Strategies from './pages/Strategies'
import CopyApprovals from './pages/CopyApprovals'
import Announcements from './pages/Announcements'
import AuditLogs from './pages/AuditLogs'
import Alerts from './pages/Alerts'
import ReferralRewards from './pages/ReferralRewards'
import Bots from './pages/Bots'
import SystemConfig from './pages/SystemConfig'
import Monitors from './pages/Monitors'
import Banners from './pages/Banners'
import Faq from './pages/Faq'
import PushNotifications from './pages/PushNotifications'

/** 需要登录才能访问;未登录跳登录页 */
function RequireAuth({ children }) {
  const { isAuthenticated } = useAuth()
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }
  return children
}

export default function App() {
  return (
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: '#3b82f6',
          borderRadius: 6,
        },
      }}
    >
      <AuthProvider>
        <HashRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route
              element={
                <RequireAuth>
                  <MainLayout />
                </RequireAuth>
              }
            >
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/users" element={<Users />} />
              <Route path="/orders" element={<Orders />} />
              <Route path="/positions" element={<Positions />} />
              <Route path="/wallet" element={<Wallet />} />
              <Route path="/strategies" element={<Strategies />} />
              <Route path="/copy-approvals" element={<CopyApprovals />} />
              <Route path="/announcements" element={<Announcements />} />
              <Route path="/alerts" element={<Alerts />} />
              <Route path="/audit-logs" element={<AuditLogs />} />
              <Route path="/referral" element={<ReferralRewards />} />
              <Route path="/bots" element={<Bots />} />
              <Route path="/monitors" element={<Monitors />} />
              <Route path="/banners" element={<Banners />} />
              <Route path="/faq" element={<Faq />} />
              <Route path="/push-notifications" element={<PushNotifications />} />
              <Route path="/system-config" element={<SystemConfig />} />
            </Route>
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </HashRouter>
      </AuthProvider>
    </ConfigProvider>
  )
}
