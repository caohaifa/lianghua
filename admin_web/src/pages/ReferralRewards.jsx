import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Input, Select, Button, Space, Tag, Tabs, Statistic, Row, Col } from 'antd'
import { ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import client from '../api/client'

/**
 * 返佣/团队管理:
 * Tab1 返佣流水(分页/筛选);Tab2 团队聚合(推荐人团队人数/活跃/流水/返佣)。
 */
export default function ReferralRewards() {
  const [tab, setTab] = useState('rewards')
  return (
    <Card title="返佣 / 团队管理">
      <Tabs
        activeKey={tab}
        onChange={setTab}
        items={[
          { key: 'rewards', label: '返佣流水', children: <RewardsTable /> },
          { key: 'teams', label: '团队聚合', children: <TeamsTable /> },
        ]}
      />
    </Card>
  )
}

function RewardsTable() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [referrer, setReferrer] = useState('')
  const [currency, setCurrency] = useState()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (referrer) params.referrer = referrer
    if (currency) params.currency = currency
    client
      .get('/admin/referral/rewards', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, referrer, currency])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '推荐人', dataIndex: 'referrerid', width: 150 },
    { title: '被推荐人', dataIndex: 'traderid', width: 150 },
    { title: '标的', dataIndex: 'symbol', width: 120 },
    {
      title: '币种',
      dataIndex: 'currency',
      width: 80,
      render: (v) => <Tag color={v === 'USDT' ? 'green' : 'blue'}>{v}</Tag>,
    },
    {
      title: '成交额',
      dataIndex: 'volume',
      align: 'right',
      width: 130,
      render: (v) => Number(v).toFixed(4),
    },
    {
      title: '返佣',
      dataIndex: 'reward',
      align: 'right',
      width: 110,
      render: (v) => (
        <span style={{ color: '#10b981', fontWeight: 600 }}>+{Number(v).toFixed(4)}</span>
      ),
    },
    { title: '订单号', dataIndex: 'orderid', ellipsis: true },
    { title: '时间', dataIndex: 'createdat', width: 170 },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="推荐人ID"
          value={referrer}
          onChange={(e) => setReferrer(e.target.value)}
          style={{ width: 180 }}
          allowClear
        />
        <Select
          placeholder="币种"
          allowClear
          style={{ width: 110 }}
          value={currency}
          onChange={setCurrency}
          options={[
            { label: 'USDT', value: 'USDT' },
            { label: 'CNY', value: 'CNY' },
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
    </>
  )
}

function TeamsTable() {
  const [list, setList] = useState([])
  const [loading, setLoading] = useState(false)

  const fetchData = useCallback(() => {
    setLoading(true)
    client
      .get('/admin/referral/teams')
      .then((res) => setList(res.data.list))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const columns = [
    { title: '推荐人', dataIndex: 'referrerid', width: 170 },
    {
      title: '团队人数',
      dataIndex: 'teamcount',
      width: 100,
      render: (v) => <Tag color="purple">{v}</Tag>,
    },
    { title: '活跃成员', dataIndex: 'activecount', width: 100 },
    {
      title: '流水(USDT)',
      dataIndex: 'volusdt',
      align: 'right',
      render: (v) => Number(v).toFixed(2),
    },
    {
      title: '流水(CNY)',
      dataIndex: 'volcny',
      align: 'right',
      render: (v) => Number(v).toFixed(2),
    },
    {
      title: '返佣(USDT)',
      dataIndex: 'rewardusdt',
      align: 'right',
      render: (v) => <span style={{ color: '#10b981' }}>+{Number(v).toFixed(4)}</span>,
    },
    {
      title: '返佣(CNY)',
      dataIndex: 'rewardcny',
      align: 'right',
      render: (v) => <span style={{ color: '#10b981' }}>+{Number(v).toFixed(4)}</span>,
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>
          刷新
        </Button>
      </Space>
      <Table
        rowKey="referrerid"
        columns={columns}
        dataSource={list}
        loading={loading}
        pagination={{ showTotal: (t) => `共 ${t} 位推荐人`, pageSize: 20 }}
      />
    </>
  )
}
