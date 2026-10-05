import { useState } from 'react'
import { Card, Form, Input, Button, Typography } from 'antd'
import { SafetyCertificateOutlined, UserOutlined, LockOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

const { Title, Text } = Typography

export default function Login() {
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const onFinish = async (values) => {
    setLoading(true)
    try {
      await login(values.username, values.password)
      navigate('/dashboard', { replace: true })
    } catch (e) {
      // 错误已由拦截器统一提示
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
      }}
    >
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <SafetyCertificateOutlined
          style={{ fontSize: 40, color: '#3b82f6', marginBottom: 12 }}
        />
        <Title level={3} style={{ color: '#fff', margin: 0 }}>
          AI 量化运营后台
        </Title>
      </div>
      <Card style={{ width: 380 }} styles={{ body: { padding: 28 } }}>
        <Form
          name="admin-login"
          initialValues={{ username: 'admin' }}
          onFinish={onFinish}
          size="large"
        >
          <Form.Item
            name="username"
            rules={[{ required: true, message: '请输入用户名' }]}
          >
            <Input prefix={<UserOutlined />} placeholder="用户名" autoComplete="username" />
          </Form.Item>
          <Form.Item
            name="password"
            rules={[{ required: true, message: '请输入密码' }]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="密码"
              autoComplete="current-password"
            />
          </Form.Item>
          <Form.Item style={{ marginBottom: 8 }}>
            <Button
              type="primary"
              htmlType="submit"
              block
              loading={loading}
            >
              登 录
            </Button>
          </Form.Item>
        </Form>
      </Card>
      <Text style={{ color: '#64748b', marginTop: 16 }}>
        默认账号 admin / admin123
      </Text>
    </div>
  )
}
