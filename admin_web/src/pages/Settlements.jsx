import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Button, Space } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

export default function Settlements() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    client
      .get('/admin/billing/settlements', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '用户ID', dataIndex: 'userId', width: 180 },
    {
      title: '净盈利',
      dataIndex: 'profitAmount',
      align: 'right',
      render: (v) => `¥${Number(v).toFixed(2)}`,
    },
    {
      title: '分成比例',
      dataIndex: 'shareRatio',
      align: 'right',
      render: (v) => `${Number(v)}%`,
    },
    {
      title: '分成金额',
      dataIndex: 'shareAmount',
      align: 'right',
      render: (v) => (
        <span style={{ fontWeight: 600, color: '#8b5cf6' }}>
          ¥{Number(v).toFixed(2)}
        </span>
      ),
    },
    { title: '结算时间', dataIndex: 'settledAt', width: 200 },
  ]

  return (
    <Card title="分成结算">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="用户ID"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 220 }}
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
