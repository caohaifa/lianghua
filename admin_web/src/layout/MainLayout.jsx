import { useState } from 'react'
import { Layout, Menu, theme, Dropdown, Avatar, Space } from 'antd'
import {
  DashboardOutlined,
  UserOutlined,
  FundOutlined,
  TransactionOutlined,
  AppstoreOutlined,
  AuditOutlined,
  LogoutOutlined,
  SafetyCertificateOutlined,
  NotificationOutlined,
  WalletOutlined,
} from '@ant-design/icons'
import { useNavigate, useLocation, Outlet } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

const { Header, Sider, Content } = Layout

const menuItems = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: '数据看板' },
  { key: '/users', icon: <UserOutlined />, label: '用户管理' },
  {
    key: 'trades',
    icon: <TransactionOutlined />,
    label: '交易管理',
    children: [
      { key: '/orders', label: '委托订单' },
      { key: '/positions', label: '持仓记录' },
    ],
  },
  {
    key: 'billing',
    icon: <WalletOutlined />,
    label: '计费管理',
    children: [
      { key: '/plan-orders', label: '订阅订单' },
      { key: '/settlements', label: '分成结算' },
    ],
  },
  {
    key: 'content',
    icon: <AppstoreOutlined />,
    label: '内容管理',
    children: [
      { key: '/strategies', icon: <FundOutlined />, label: '策略管理' },
      { key: '/announcements', icon: <NotificationOutlined />, label: '系统公告' },
    ],
  },
  { key: '/audit-logs', icon: <AuditOutlined />, label: '审计日志' },
]

export default function MainLayout() {
  const [collapsed, setCollapsed] = useState(false)
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const {
    token: { colorBgContainer },
  } = theme.useToken()

  // 选中当前路径;父级菜单需展开
  const selectedKey = location.pathname
  const openKeys = ['trades', 'billing', 'content']

  const onLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed}>
        <div
          style={{
            height: 48,
            margin: 16,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            color: '#fff',
            fontWeight: 700,
            fontSize: collapsed ? 14 : 16,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
          }}
        >
          <SafetyCertificateOutlined style={{ color: '#3b82f6' }} />
          {!collapsed && 'AI量化运营后台'}
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selectedKey]}
          defaultOpenKeys={openKeys}
          items={menuItems}
          onClick={({ key }) => {
            if (key.startsWith('/')) navigate(key)
          }}
        />
      </Sider>
      <Layout>
        <Header
          style={{
            padding: '0 24px',
            background: colorBgContainer,
            display: 'flex',
            justifyContent: 'flex-end',
            alignItems: 'center',
          }}
        >
          <Dropdown
            trigger={['click']}
            menu={{
              items: [
                {
                  key: 'logout',
                  icon: <LogoutOutlined />,
                  label: '退出登录',
                  onClick: onLogout,
                },
              ],
            }}
          >
            <Space style={{ cursor: 'pointer' }}>
              <Avatar icon={<UserOutlined />} style={{ background: '#3b82f6' }} />
              <span>{user?.username}</span>
              <span style={{ color: '#94a3b8' }}>
                ({roleLabel(user?.role)})
              </span>
            </Space>
          </Dropdown>
        </Header>
        <Content style={{ margin: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}

function roleLabel(role) {
  return (
    {
      super_admin: '超级管理员',
      ops: '运营',
      compliance: '合规',
      finance: '财务',
    }[role] || role
  )
}
