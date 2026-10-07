import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Select, Button, Space, Tag, Popconfirm, message } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'
import client from '../api/client'

const STATUS_FILTER = [
  { label: '待审核', value: 'pending' },
  { label: '已通过', value: 'published' },
  { label: '已驳回', value: 'rejected' },
  { label: '已下架', value: 'offline' },
]

/** 跟单审核:会员发布的策略,通过后才在客户端策略广场展示 */
export default function CopyApprovals() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [status, setStatus] = useState()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (status) params.status = status
    client
      .get('/admin/copy/publishes', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, status])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const review = async (record, nextStatus) => {
    await client.put(`/admin/copy/publishes/${record.id}/status`, { status: nextStatus })
    message.success(nextStatus === 'published' ? '已通过并上架' : '已驳回')
    fetchData()
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '标题', dataIndex: 'title', width: 180 },
    { title: '申请人', dataIndex: 'leaderName', width: 120 },
    {
      title: '策略',
      dataIndex: 'strategy',
      width: 140,
      render: (v) => (
        <Space size={4}>
          <span>{v}</span>
          {v === '个人策略' && <Tag color="purple">人工信号</Tag>}
        </Space>
      ),
    },
    { title: '标的', dataIndex: 'symbol', width: 120 },
    { title: '说明', dataIndex: 'description', ellipsis: true },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (v) => <Tag color={statusColor(v)}>{statusLabel(v)}</Tag>,
    },
    { title: '申请时间', dataIndex: 'createdAt', width: 170 },
    {
      title: '操作',
      width: 180,
      render: (_, record) => (
        <Space size="small">
          {record.status === 'pending' && (
            <>
              <Button size="small" type="primary" onClick={() => review(record, 'published')}>
                通过
              </Button>
              <Popconfirm title="确认驳回该发布?" onConfirm={() => review(record, 'rejected')}>
                <Button size="small" danger>
                  驳回
                </Button>
              </Popconfirm>
            </>
          )}
        </Space>
      ),
    },
  ]

  return (
    <Card title="跟单审核">
      <Space style={{ marginBottom: 16 }} wrap>
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 130 }}
          value={status}
          onChange={(v) => {
            setStatus(v)
            setPage(1)
          }}
          options={STATUS_FILTER}
        />
        <Button icon={<ReloadOutlined />} onClick={fetchData}>
          刷新
        </Button>
      </Space>
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data.list}
        loading={loading}
        scroll={{ x: 1100 }}
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

function statusLabel(s) {
  return { pending: '待审核', published: '已通过', rejected: '已驳回', offline: '已下架' }[s] || s
}
function statusColor(s) {
  return { pending: 'orange', published: 'green', rejected: 'red', offline: 'default' }[s]
}
