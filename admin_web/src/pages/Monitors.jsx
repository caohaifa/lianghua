import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Select, Button, Space, Tag } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

/**
 * 监控总览:全用户监控列表(运行状态/信号/跟单聚合),策略/状态/来源筛选。
 */
export default function Monitors() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [strategies, setStrategies] = useState([])
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [strategy, setStrategy] = useState()
  const [status, setStatus] = useState()
  const [source, setSource] = useState()

  useEffect(() => {
    client.get('/admin/monitors/strategies').then((res) => setStrategies(res.data))
  }, [])

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (strategy) params.strategy = strategy
    if (status) params.status = status
    if (source) params.source = source
    client
      .get('/admin/monitors', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, strategy, status, source])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '用户ID', dataIndex: 'userid', width: 150 },
    { title: '标的', dataIndex: 'symbol', width: 110 },
    {
      title: '策略',
      dataIndex: 'strategy',
      width: 130,
      render: (v) => (
        <Tag color={v === '个人策略' ? 'purple' : 'blue'}>{v}</Tag>
      ),
    },
    {
      title: '来源',
      dataIndex: 'source',
      width: 80,
      render: (v) =>
        v === 'bot' ? <Tag color="cyan">机器人</Tag> : <Tag>用户</Tag>,
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) =>
        v === 'running' ? <Tag color="green">运行中</Tag> : <Tag>已暂停</Tag>,
    },
    { title: '当前信号', dataIndex: 'signal', width: 150, render: (v) => v || '-' },
    {
      title: '信号数',
      dataIndex: 'signalcount',
      width: 80,
      align: 'right',
      render: (v) => (v > 0 ? <Tag color="orange">{v}</Tag> : v),
    },
    {
      title: '跟单数',
      dataIndex: 'followcount',
      width: 80,
      align: 'right',
      render: (v) => (v > 0 ? <Tag color="purple">{v}</Tag> : v),
    },
    { title: '创建时间', dataIndex: 'createdat', width: 170 },
  ]

  return (
    <Card title="监控总览">
      <Space style={{ marginBottom: 16 }} wrap>
        <Select
          placeholder="策略"
          allowClear
          style={{ width: 160 }}
          value={strategy}
          onChange={setStrategy}
          options={strategies.map((s) => ({ label: s, value: s }))}
        />
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 110 }}
          value={status}
          onChange={setStatus}
          options={[
            { label: '运行中', value: 'running' },
            { label: '已暂停', value: 'paused' },
          ]}
        />
        <Select
          placeholder="来源"
          allowClear
          style={{ width: 110 }}
          value={source}
          onChange={setSource}
          options={[
            { label: '用户', value: 'user' },
            { label: '机器人', value: 'bot' },
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
