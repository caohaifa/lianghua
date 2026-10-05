import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

const ACTION_LABELS = {
  freeze_user: ['冻结用户', 'red'],
  unfreeze_user: ['解冻用户', 'green'],
  adjust_risk_level: ['调整风险等级', 'orange'],
  create_strategy: ['创建策略', 'blue'],
  update_strategy_status: ['变更策略状态', 'blue'],
  publish_announcement: ['发布公告', 'purple'],
}

export default function AuditLogs() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [actorId, setActorId] = useState('')
  const [action, setAction] = useState('')

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (actorId) params.actorId = actorId
    if (action) params.action = action
    client
      .get('/admin/system/audit-logs', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, actorId, action])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    {
      title: '操作人',
      dataIndex: 'actorId',
      width: 120,
      render: (v) => <Tag>{v}</Tag>,
    },
    {
      title: '动作',
      dataIndex: 'action',
      width: 150,
      render: (v) => {
        const [text, color] = ACTION_LABELS[v] || [v, 'default']
        return <Tag color={color}>{text}</Tag>
      },
    },
    { title: '资源', dataIndex: 'resource', width: 160 },
    { title: '明细', dataIndex: 'detailJson' },
    { title: 'IP', dataIndex: 'ip', width: 150 },
    { title: '时间', dataIndex: 'createTime', width: 220 },
  ]

  return (
    <Card title="审计日志（后台操作留痕，保留 ≥ 5 年）">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="操作人"
          value={actorId}
          onChange={(e) => setActorId(e.target.value)}
          style={{ width: 160 }}
          allowClear
        />
        <Input
          placeholder="动作关键词"
          value={action}
          onChange={(e) => setAction(e.target.value)}
          style={{ width: 180 }}
          allowClear
        />
        <Button type="primary" icon={<SearchOutlined />} onClick={() => setPage(1)}>
          查询
        </Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>
          刷新
        </Button>
      </Space>
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data.list}
        loading={loading}
        scroll={{ x: 1200 }}
        pagination={{
          current: page,
          pageSize: size,
          total: data.total,
          showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p, s) => {
            setPage(p)
            setSize(s)
          },
        }}
      />
    </Card>
  )
}
