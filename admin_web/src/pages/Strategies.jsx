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
  Form,
  message,
  Popconfirm,
} from 'antd'
import {
  ReloadOutlined,
  SearchOutlined,
  PlusOutlined,
  EditOutlined,
} from '@ant-design/icons'
import client from '../api/client'

const STATUS_FILTER = [
  { label: '草稿', value: 'draft' },
  { label: '待审核', value: 'review' },
  { label: '灰度中', value: 'gray' },
  { label: '已上架', value: 'online' },
  { label: '已下架', value: 'offline' },
]

export default function Strategies() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState()
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form] = Form.useForm()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.name = keyword
    if (status) params.status = status
    client
      .get('/admin/content/strategies', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const openCreate = () => {
    setEditing(null)
    form.resetFields()
    setModalOpen(true)
  }

  const openEdit = (record) => {
    setEditing(record)
    form.setFieldsValue(record)
    setModalOpen(true)
  }

  const submitForm = async () => {
    const values = await form.validateFields()
    if (editing) {
      await client.put(`/admin/content/strategies/${editing.id}`, values)
      message.success('已保存')
    } else {
      await client.post('/admin/content/strategies', values)
      message.success('已创建')
    }
    setModalOpen(false)
    fetchData()
  }

  const changeStatus = async (record, nextStatus) => {
    let grayPercent = record.grayPercent || 0
    if (nextStatus === 'gray') {
      const input = await promptGray(grayPercent)
      if (input === null) return
      grayPercent = input
    }
    await client.put(`/admin/content/strategies/${record.id}/status`, {
      status: nextStatus,
      grayPercent,
    })
    message.success('状态已更新')
    fetchData()
  }

  const columns = [
    { title: '策略ID', dataIndex: 'strategyId', width: 150 },
    { title: '名称', dataIndex: 'name', width: 140 },
    { title: '交易所', dataIndex: 'exchange', width: 100 },
    { title: '适用标的', dataIndex: 'symbols' },
    {
      title: '风险等级',
      dataIndex: 'riskLevel',
      width: 90,
      render: (v) => (v ? <Tag>{v}</Tag> : '-'),
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (v) => <Tag color={statusColor(v)}>{statusLabel(v)}</Tag>,
    },
    {
      title: '灰度',
      dataIndex: 'grayPercent',
      width: 80,
      render: (v) => (v ? `${v}%` : '-'),
    },
    { title: '创建人', dataIndex: 'creator', width: 100 },
    {
      title: '操作',
      width: 260,
      fixed: 'right',
      render: (_, record) => (
        <Space size="small" wrap>
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>
            编辑
          </Button>
          {record.status === 'draft' && (
            <Button size="small" onClick={() => changeStatus(record, 'review')}>
              送审
            </Button>
          )}
          {record.status === 'review' && (
            <Button size="small" onClick={() => changeStatus(record, 'gray')}>
              灰度
            </Button>
          )}
          {record.status === 'gray' && (
            <Button size="small" type="primary" onClick={() => changeStatus(record, 'online')}>
              上架
            </Button>
          )}
          {record.status === 'online' && (
            <Popconfirm title="确认下架该策略?" onConfirm={() => changeStatus(record, 'offline')}>
              <Button size="small" danger>
                下架
              </Button>
            </Popconfirm>
          )}
          {record.status === 'offline' && (
            <Popconfirm title="确认重新上架该策略?" onConfirm={() => changeStatus(record, 'online')}>
              <Button size="small" type="primary">
                重新上架
              </Button>
            </Popconfirm>
          )}
        </Space>
      ),
    },
  ]

  return (
    <Card title="策略管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="策略名称"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 180 }}
          allowClear
        />
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 120 }}
          value={status}
          onChange={setStatus}
          options={STATUS_FILTER}
        />
        <Button type="primary" icon={<SearchOutlined />} onClick={() => setPage(1)}>
          查询
        </Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>
          刷新
        </Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} ghost>
          新建策略
        </Button>
      </Space>
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data.list}
        loading={loading}
        scroll={{ x: 1300 }}
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

      <Modal
        title={editing ? '编辑策略' : '新建策略'}
        open={modalOpen}
        onOk={submitForm}
        onCancel={() => setModalOpen(false)}
        width={620}
        destroyOnClose
      >
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Form.Item
            name="name"
            label="策略名称"
            rules={[{ required: true, message: '请输入名称' }]}
          >
            <Input placeholder="如 BTC趋势跟踪策略" />
          </Form.Item>
          <Form.Item name="description" label="策略说明">
            <Input.TextArea rows={3} placeholder="策略逻辑、适用行情等" />
          </Form.Item>
          <Space size="large">
            <Form.Item name="exchange" label="交易所">
              <Select
                style={{ width: 150 }}
                allowClear
                options={['okx', 'binance', 'htsc'].map((v) => ({ label: v, value: v }))}
                getPopupContainer={(trigger) => trigger.parentElement}
              />
            </Form.Item>
            <Form.Item name="riskLevel" label="适用风险等级">
              <Select
                style={{ width: 150 }}
                allowClear
                options={['R1', 'R2', 'R3', 'R4', 'R5'].map((v) => ({ label: v, value: v }))}
                getPopupContainer={(trigger) => trigger.parentElement}
              />
            </Form.Item>
          </Space>
          <Form.Item name="symbols" label="适用标的(逗号分隔)">
            <Input placeholder="BTC-USDT,ETH-USDT" />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  )
}

/** 灰度比例输入(返回 null 表示取消或非法输入) */
function promptGray(current) {
  return new Promise((resolve) => {
    let value = current || 10
    Modal.confirm({
      title: '设置灰度放量比例',
      content: (
        <Input
          type="number"
          min={1}
          max={100}
          defaultValue={value}
          style={{ marginTop: 16 }}
          onChange={(e) => (value = Number(e.target.value))}
        />
      ),
      onOk: () => {
        if (value < 1 || value > 100) {
          message.warning('比例需在 1~100 之间')
          resolve(null)
          return
        }
        resolve(value)
      },
      onCancel: () => resolve(null),
    })
  })
}

function statusLabel(s) {
  return { draft: '草稿', review: '待审核', gray: '灰度中', online: '已上架', offline: '已下架' }[s] || s
}
function statusColor(s) {
  return { draft: 'default', review: 'orange', gray: 'blue', online: 'green', offline: 'red' }[s]
}
