import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Select, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

export default function Positions() {
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
    if (status !== undefined) params.status = status
    client
      .get('/admin/trades/positions', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
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
        <Tag color={v === 'long' ? 'green' : 'red'}>
          {v === 'long' ? '做多' : '做空'}
        </Tag>
      ),
    },
    { title: '持仓量', dataIndex: 'amount', align: 'right' },
    { title: '开仓价', dataIndex: 'entryPrice', align: 'right' },
    { title: '当前价', dataIndex: 'currentPrice', align: 'right', render: (v) => v ?? '-' },
    {
      title: '盈亏',
      dataIndex: 'pnl',
      align: 'right',
      render: (v) => {
        const n = Number(v)
        return (
          <span style={{ color: n >= 0 ? '#10b981' : '#ef4444', fontWeight: 600 }}>
            {n.toFixed(2)}
          </span>
        )
      },
    },
    {
      title: '盈亏比例',
      dataIndex: 'pnlPct',
      align: 'right',
      render: (v) => `${(Number(v) * 100).toFixed(2)}%`,
    },
    { title: '策略', dataIndex: 'strategyName', render: (v) => v || '-' },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) => (v === 0 ? <Tag color="green">持仓中</Tag> : <Tag>已平仓</Tag>),
    },
    { title: '开仓时间', dataIndex: 'openedAt', width: 180 },
  ]

  return (
    <Card title="持仓记录">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="标的 / 用户ID"
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
          options={[
            { label: '持仓中', value: 0 },
            { label: '已平仓', value: 1 },
          ]}
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
        scroll={{ x: 1400 }}
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
