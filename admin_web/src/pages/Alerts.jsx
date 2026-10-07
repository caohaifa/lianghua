import { useEffect, useState } from 'react'
import { Card, Switch, Table, Tag, message, Space, Typography } from 'antd'
import { AlertOutlined } from '@ant-design/icons'
import client from '../api/client'

const { Text } = Typography

const typeLabels = {
  copy_skip: { text: '跟单跳过', color: 'orange' },
  risk: { text: '风控', color: 'red' },
  system: { text: '系统', color: 'blue' },
}

/** 全局风控:一键暂停/恢复跟单信号分发 + 站内告警列表 */
export default function Alerts() {
  const [paused, setPaused] = useState(false)
  const [pauseLoading, setPauseLoading] = useState(false)
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(false)

  const loadStatus = async () => {
    try {
      const { data } = await client.get('/admin/risk/copy-status')
      setPaused(!!data?.data?.paused)
    } catch {
      /* 忽略 */
    }
  }

  const loadAlerts = async () => {
    setLoading(true)
    try {
      const { data } = await client.get('/admin/risk/alerts', { params: { limit: 100 } })
      setAlerts(data?.data || [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadStatus()
    loadAlerts()
  }, [])

  const onPauseChange = async (value) => {
    setPauseLoading(true)
    try {
      const { data } = await client.put('/admin/risk/copy-pause', { paused: value })
      setPaused(!!data?.paused)
      message.success(value ? '已暂停全部跟单信号分发' : '已恢复全部跟单信号分发')
    } catch {
      /* 拦截器已提示 */
    } finally {
      setPauseLoading(false)
    }
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    {
      title: '类型',
      dataIndex: 'type',
      width: 110,
      render: (t) => {
        const meta = typeLabels[t] || { text: t, color: 'default' }
        return <Tag color={meta.color}>{meta.text}</Tag>
      },
    },
    { title: '标题', dataIndex: 'title', width: 180 },
    { title: '内容', dataIndex: 'content', ellipsis: true },
    { title: '用户', dataIndex: 'userId', width: 130 },
    {
      title: '时间',
      dataIndex: 'createdAt',
      width: 180,
      render: (v) => (v ? String(v).replace('T', ' ').slice(0, 19) : '-'),
    },
  ]

  return (
    <Space direction="vertical" size={16} style={{ width: '100%' }}>
      <Card title="全局跟单风控">
        <Space size={16} align="center">
          <AlertOutlined style={{ fontSize: 20, color: paused ? '#ef4444' : '#22c55e' }} />
          <Text strong>跟单信号分发</Text>
          <Switch
            checked={!paused}
            loading={pauseLoading}
            checkedChildren="正常分发"
            unCheckedChildren="已暂停"
            onChange={(v) => onPauseChange(!v)}
          />
          <Text type="secondary">
            {paused
              ? '已暂停:所有个人策略信号与跟单复制均不执行'
              : '正常:个人策略信号按跟单模式自动分发执行'}
          </Text>
        </Space>
      </Card>
      <Card title="站内告警(最近 100 条)">
        <Table
          rowKey="id"
          size="small"
          loading={loading}
          columns={columns}
          dataSource={alerts}
          pagination={{ pageSize: 10, showTotal: (t) => `共 ${t} 条` }}
        />
      </Card>
    </Space>
  )
}
