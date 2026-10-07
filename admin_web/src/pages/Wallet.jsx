import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Select, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

const TYPE_OPTIONS = [
  { label: '充值', value: 'deposit' },
  { label: '提现', value: 'withdraw' },
  { label: '交易手续费', value: 'fee' },
  { label: '其他', value: 'other' },
]

const STATUS_MAP = {
  pending: { label: '处理中', color: 'orange' },
  success: { label: '成功', color: 'green' },
  failed: { label: '失败', color: 'red' },
}

export default function Wallet() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [type, setType] = useState()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    if (type) params.type = type
    client
      .get('/admin/billing/wallet', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, type])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '用户ID', dataIndex: 'userId', width: 180 },
    {
      title: '币种',
      dataIndex: 'currency',
      width: 80,
      render: (v) => <Tag color="blue">{v}</Tag>,
    },
    {
      title: '类型',
      dataIndex: 'type',
      width: 110,
      render: (v) => {
        const opt = TYPE_OPTIONS.find((o) => o.value === v)
        return <Tag>{opt ? opt.label : v}</Tag>
      },
    },
    {
      title: '金额',
      dataIndex: 'amount',
      align: 'right',
      width: 120,
      render: (v) => {
        const num = Number(v)
        const isOut = ['withdraw', 'fee'].includes(null)
        return (
          <span style={{ fontWeight: 600, color: num >= 0 ? '#10b981' : '#ef4444' }}>
            {num >= 0 ? '+' : ''}
            {num.toFixed(4)}
          </span>
        )
      },
    },
    { title: '渠道', dataIndex: 'channel', width: 100 },
    {
      title: '地址',
      dataIndex: 'address',
      ellipsis: true,
      render: (v) => v || '-',
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) => {
        const s = STATUS_MAP[v] || { label: v, color: 'default' }
        return <Tag color={s.color}>{s.label}</Tag>
      },
    },
    { title: '时间', dataIndex: 'createdAt', width: 170 },
  ]

  return (
    <Card title="钱包流水">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="用户ID"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 200 }}
          allowClear
        />
        <Select
          placeholder="类型"
          allowClear
          style={{ width: 130 }}
          value={type}
          onChange={setType}
          options={TYPE_OPTIONS}
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
