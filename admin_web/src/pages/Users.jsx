import { useEffect, useState, useCallback } from 'react'
import {
  Card,
  Table,
  Input,
  Select,
  Button,
  Space,
  Tag,
  Modal,
  message,
  Popconfirm,
  Drawer,
  Descriptions,
  Divider,
} from 'antd'
import { ReloadOutlined, SearchOutlined, EyeOutlined } from '@ant-design/icons'
import client from '../api/client'

const RISK_OPTIONS = ['R1', 'R2', 'R3', 'R4', 'R5'].map((v) => ({
  label: v,
  value: v,
}))

export default function Users() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState()
  const [riskLevel, setRiskLevel] = useState()
  const [detail, setDetail] = useState(null)
  const [detailOpen, setDetailOpen] = useState(false)

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    if (status !== undefined) params.status = status
    if (riskLevel) params.riskLevel = riskLevel
    client
      .get('/admin/users', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status, riskLevel])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const toggleStatus = async (record) => {
    const next = record.status === 0 ? 1 : 0
    await client.put(`/admin/users/${record.userId}/status`, { status: next })
    message.success(next === 1 ? '已冻结' : '已解冻')
    fetchData()
  }

  const changeRisk = (record) => {
    let value = record.riskLevel
    Modal.confirm({
      title: `调整用户 ${record.phone} 的风险等级`,
      content: (
        <Select
          defaultValue={record.riskLevel || undefined}
          options={RISK_OPTIONS}
          style={{ width: '100%', marginTop: 16 }}
          onChange={(v) => (value = v)}
          placeholder="选择风险等级"
          getPopupContainer={(trigger) => trigger.parentElement}
        />
      ),
      onOk: async () => {
        if (!value) {
          message.warning('请选择风险等级')
          throw new Error()
        }
        await client.put(`/admin/users/${record.userId}/risk-level`, {
          riskLevel: value,
        })
        message.success('风险等级已调整')
        fetchData()
      },
    })
  }

  const columns = [
    { title: '手机号', dataIndex: 'phone', width: 140 },
    { title: '昵称', dataIndex: 'nickname' },
    {
      title: '风险等级',
      dataIndex: 'riskLevel',
      width: 100,
      render: (v) =>
        v ? <Tag color={riskColor(v)}>{v}</Tag> : <Tag>未测评</Tag>,
    },
    {
      title: '协议',
      dataIndex: 'agreementSigned',
      width: 80,
      render: (v) => (v ? <Tag color="green">已签</Tag> : <Tag>未签</Tag>),
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) =>
        v === 0 ? (
          <Tag color="green">正常</Tag>
        ) : (
          <Tag color="red">冻结</Tag>
        ),
    },
    { title: '注册时间', dataIndex: 'createdAt', width: 180 },
    {
      title: '操作',
      width: 260,
      fixed: 'right',
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EyeOutlined />} onClick={() => { setDetail(record); setDetailOpen(true) }}>
            详情
          </Button>
          <Button size="small" onClick={() => changeRisk(record)}>
            风险等级
          </Button>
          <Popconfirm
            title={record.status === 0 ? '确认冻结该用户?' : '确认解冻该用户?'}
            onConfirm={() => toggleStatus(record)}
          >
            <Button size="small" danger={record.status === 0}>
              {record.status === 0 ? '冻结' : '解冻'}
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <Card>
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="手机号 / 昵称 / 用户ID"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onPressEnter={() => {
            setPage(1)
          }}
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
            { label: '正常', value: 0 },
            { label: '冻结', value: 1 },
          ]}
        />
        <Select
          placeholder="风险等级"
          allowClear
          style={{ width: 120 }}
          value={riskLevel}
          onChange={setRiskLevel}
          options={RISK_OPTIONS}
        />
        <Button
          type="primary"
          icon={<SearchOutlined />}
          onClick={() => setPage(1)}
        >
          查询
        </Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>
          刷新
        </Button>
      </Space>
      <Table
        rowKey="userId"
        columns={columns}
        dataSource={data.list}
        loading={loading}
        scroll={{ x: 1000 }}
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

      <Drawer
        title="用户详情"
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        width={480}
      >
        {detail && (
          <div>
            <Descriptions column={1} bordered size="small">
              <Descriptions.Item label="用户ID">{detail.userId}</Descriptions.Item>
              <Descriptions.Item label="手机号">{detail.phone}</Descriptions.Item>
              <Descriptions.Item label="昵称">{detail.nickname || '-'}</Descriptions.Item>
              <Descriptions.Item label="邀请人">{detail.invitedBy || '-'}</Descriptions.Item>
              <Descriptions.Item label="风险等级">
                {detail.riskLevel ? <Tag color={riskColor(detail.riskLevel)}>{detail.riskLevel}</Tag> : <Tag>未测评</Tag>}
              </Descriptions.Item>
              <Descriptions.Item label="协议签署">
                {detail.agreementSigned ? <Tag color="green">已签署</Tag> : <Tag>未签署</Tag>}
              </Descriptions.Item>
              <Descriptions.Item label="账号状态">
                {detail.status === 0 ? <Tag color="green">正常</Tag> : <Tag color="red">冻结</Tag>}
              </Descriptions.Item>
              <Descriptions.Item label="注册时间">{detail.createdAt}</Descriptions.Item>
              <Descriptions.Item label="最后登录">{detail.lastLoginAt || '-'}</Descriptions.Item>
            </Descriptions>
            <Divider />
            <Space wrap>
              <Button size="small" onClick={() => changeRisk(detail)}>调整风险等级</Button>
              <Button size="small" danger={detail.status === 0} onClick={() => { toggleStatus(detail); setDetailOpen(false) }}>
                {detail.status === 0 ? '冻结用户' : '解冻用户'}
              </Button>
            </Space>
          </div>
        )}
      </Drawer>
    </Card>
  )
}

function riskColor(level) {
  return { R1: 'green', R2: 'lime', R3: 'orange', R4: 'volcano', R5: 'red' }[
    level
  ]
}
