import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Select, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

const STATUS_OPTIONS = [
  { label: '待成交', value: 'pending' },
  { label: '已成交', value: 'filled' },
  { label: '已取消', value: 'cancelled' },
]

export default function Orders() {
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
      .get('/admin/trades/orders', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: '订单号', dataIndex: 'orderId', width: 180 },
    { title: '用户ID', dataIndex: 'userId', width: 160 },
    {
      title: '标的',
      dataIndex: 'symbol',
      width: 140,
      render: (v) => <Tag color="blue">{v}</Tag>,
    },
    {
      title: '币种',
      dataIndex: 'currency',
      width: 80,
      render: (v) => <Tag color={v === 'USDT' ? 'gold' : 'cyan'}>{v}</Tag>,
    },
    {
      title: '方向',
      dataIndex: 'side',
      width: 80,
      render: (v) => (
        <Tag color={v === 'buy' ? 'green' : 'red'}>
          {v === 'buy' ? '买入' : '卖出'}
        </Tag>
      ),
    },
    {
      title: '类型',
      dataIndex: 'orderType',
      width: 90,
      render: (v) => (v === 'market' ? '市价' : '限价'),
    },
    {
      title: '委托价',
      dataIndex: 'price',
      align: 'right',
      render: (v) => (v ?? '-'),
    },
    { title: '委托量', dataIndex: 'amount', align: 'right' },
    { title: '已成交', dataIndex: 'filledAmount', align: 'right' },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) => {
        const map = {
          pending: ['待成交', 'orange'],
          filled: ['已成交', 'green'],
          cancelled: ['已取消', 'default'],
        }
        const [text, color] = map[v] || [v]
        return <Tag color={color}>{text}</Tag>
      },
    },
    { title: '策略', dataIndex: 'strategyName', width: 120, render: (v) => v || '-' },
    { title: '创建时间', dataIndex: 'createdAt', width: 180 },
  ]

  return (
    <Card title="委托订单">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="标的 / 订单号 / 用户ID"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 240 }}
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
        scroll={{ x: 1500 }}
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
