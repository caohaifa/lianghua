import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Select, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

const STATUS_OPTIONS = [
  { label: '待支付', value: 'pending' },
  { label: '已支付', value: 'paid' },
  { label: '已过期', value: 'expired' },
]

export default function PlanOrders() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    if (status) params.status = status
    client
      .get('/admin/billing/plan-orders', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '用户ID', dataIndex: 'userId', width: 180 },
    {
      title: '套餐',
      dataIndex: 'planLevel',
      width: 130,
      render: (v) => <Tag color="blue">{planLabel(v)}</Tag>,
    },
    {
      title: '金额',
      dataIndex: 'amount',
      align: 'right',
      render: (v) => `¥${Number(v).toFixed(2)}`,
    },
    {
      title: '周期',
      dataIndex: 'period',
      width: 90,
      render: (v) => ({ month: '月付', quarter: '季付', year: '年付' }[v] || v),
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (v) => {
        const map = {
          pending: ['待支付', 'orange'],
          paid: ['已支付', 'green'],
          expired: ['已过期', 'default'],
        }
        const [text, color] = map[v] || [v]
        return <Tag color={color}>{text}</Tag>
      },
    },
    { title: '创建时间', dataIndex: 'createdAt', width: 180 },
  ]

  return (
    <Card title="订阅订单">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="用户ID"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 220 }}
          allowClear
        />
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 120 }}
          value={status}
          onChange={setStatus}
          options={STATUS_OPTIONS}
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

function planLabel(level) {
  return { basic: '基础版', advanced: '进阶版', professional: '专业版' }[level] || level
}
