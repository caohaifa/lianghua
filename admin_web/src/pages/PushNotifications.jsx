import { useEffect, useState, useCallback } from 'react'
import {
  Card, Table, Input, Select, Button, Space, Tag, Modal, Form,
  message, Popconfirm, DatePicker, InputNumber, Descriptions,
} from 'antd'
import {
  ReloadOutlined, SearchOutlined, PlusOutlined, EditOutlined,
  SendOutlined, StopOutlined, EyeOutlined,
} from '@ant-design/icons'
import client from '../api/client'
import dayjs from 'dayjs'

const TARGET_TYPES = [
  { label: '全部用户', value: 'all' },
  { label: '按风险等级', value: 'risk_level' },
  { label: '指定用户ID', value: 'user_ids' },
]
const STATUS_MAP = {
  0: { text: '草稿', color: 'default' },
  1: { text: '待发送', color: 'processing' },
  2: { text: '已发送', color: 'green' },
  3: { text: '已取消', color: 'red' },
}

export default function PushNotifications() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState()
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [detailOpen, setDetailOpen] = useState(false)
  const [detailRecord, setDetailRecord] = useState(null)
  const [form] = Form.useForm()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    if (status !== undefined) params.status = status
    client.get('/admin/content/push-notifications', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => { fetchData() }, [fetchData])

  const openCreate = () => {
    setEditing(null)
    form.resetFields()
    form.setFieldsValue({ targetType: 'all', status: 0 })
    setModalOpen(true)
  }

  const openEdit = (record) => {
    setEditing(record)
    form.setFieldsValue({
      ...record,
      scheduledAt: record.scheduledAt ? dayjs(record.scheduledAt) : null,
    })
    setModalOpen(true)
  }

  const submitForm = async () => {
    const values = await form.validateFields()
    const payload = {
      ...values,
      scheduledAt: values.scheduledAt ? values.scheduledAt.format('YYYY-MM-DD HH:mm:ss') : null,
    }
    if (editing) {
      await client.put(`/admin/content/push-notifications/${editing.id}`, payload)
      message.success('已保存')
    } else {
      await client.post('/admin/content/push-notifications', payload)
      message.success('已创建')
    }
    setModalOpen(false)
    fetchData()
  }

  const sendPush = async (record) => {
    const res = await client.post(`/admin/content/push-notifications/${record.id}/send`)
    message.success(`已发送,覆盖 ${res.data?.sentCount ?? '?'} 名用户`)
    fetchData()
  }

  const cancelPush = async (record) => {
    await client.post(`/admin/content/push-notifications/${record.id}/cancel`)
    message.success('已取消')
    fetchData()
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '标题', dataIndex: 'title', ellipsis: true },
    {
      title: '内容', dataIndex: 'content', ellipsis: true,
      render: (v) => <span style={{ color: '#64748b' }}>{v?.length > 60 ? v.slice(0, 60) + '...' : v}</span>,
    },
    {
      title: '目标', width: 130,
      render: (_, r) => {
        const label = TARGET_TYPES.find((t) => t.value === r.targetType)?.label || r.targetType
        return r.targetValue ? `${label}: ${r.targetValue}` : label
      },
    },
    {
      title: '状态', dataIndex: 'status', width: 90,
      render: (v) => {
        const s = STATUS_MAP[v] || { text: v, color: 'default' }
        return <Tag color={s.color}>{s.text}</Tag>
      },
    },
    {
      title: '发送', width: 140,
      render: (_, r) => {
        if (r.status === 2) return <span style={{ color: '#10b981', fontSize: 12 }}>{r.sentCount} 人 · {r.sentAt ? dayjs(r.sentAt).format('MM/DD HH:mm') : ''}</span>
        return '-'
      },
    },
    {
      title: '定时', dataIndex: 'scheduledAt', width: 140,
      render: (v) => v ? dayjs(v).format('MM/DD HH:mm') : '-',
    },
    {
      title: '操作', width: 220, fixed: 'right',
      render: (_, record) => (
        <Space size="small">
          <Button size="small" icon={<EyeOutlined />} onClick={() => { setDetailRecord(record); setDetailOpen(true) }}>
            详情
          </Button>
          {(record.status === 0 || record.status === 1) && (
            <>
              <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
              <Popconfirm title="确认立即发送该推送?" onConfirm={() => sendPush(record)}>
                <Button size="small" type="primary" icon={<SendOutlined />}>发送</Button>
              </Popconfirm>
              <Popconfirm title="确认取消该推送?" onConfirm={() => cancelPush(record)}>
                <Button size="small" danger icon={<StopOutlined />}>取消</Button>
              </Popconfirm>
            </>
          )}
        </Space>
      ),
    },
  ]

  return (
    <Card title="推送通知管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="搜索标题/内容" value={keyword} onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 200 }} allowClear />
        <Select placeholder="状态" allowClear style={{ width: 110 }} value={status} onChange={setStatus}
          options={Object.entries(STATUS_MAP).map(([k, v]) => ({ label: v.text, value: Number(k) }))} />
        <Button type="primary" icon={<SearchOutlined />} onClick={() => setPage(1)}>查询</Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>刷新</Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} ghost>新建推送</Button>
      </Space>
      <Table rowKey="id" columns={columns} dataSource={data.list} loading={loading}
        scroll={{ x: 1300 }}
        pagination={{
          current: page, pageSize: size, total: data.total, showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`, onChange: (p, s) => { setPage(p); setSize(s) },
        }} />

      <Modal title={editing ? '编辑推送' : '新建推送'} open={modalOpen} onOk={submitForm}
        onCancel={() => setModalOpen(false)} width={640} destroyOnClose>
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Form.Item name="title" label="推送标题" rules={[{ required: true, message: '请输入标题' }]}>
            <Input placeholder="推送标题" maxLength={100} showCount />
          </Form.Item>
          <Form.Item name="content" label="推送内容" rules={[{ required: true, message: '请输入内容' }]}>
            <Input.TextArea rows={4} placeholder="推送正文" maxLength={500} showCount />
          </Form.Item>
          <Space size="large">
            <Form.Item name="targetType" label="目标类型">
              <Select style={{ width: 160 }} options={TARGET_TYPES} />
            </Form.Item>
            <Form.Item name="targetValue" label="目标值" tooltip="按风险等级填 R1,R2 等;按用户ID填逗号分隔">
              <Input placeholder="可选" style={{ width: 240 }} />
            </Form.Item>
          </Space>
          <Form.Item name="scheduledAt" label="定时发送(留空则手动触发)">
            <DatePicker showTime format="YYYY-MM-DD HH:mm" />
          </Form.Item>
        </Form>
      </Modal>

      <Modal title="推送详情" open={detailOpen} onCancel={() => setDetailOpen(false)} footer={null} width={560}>
        {detailRecord && (
          <Descriptions column={1} bordered size="small">
            <Descriptions.Item label="ID">{detailRecord.id}</Descriptions.Item>
            <Descriptions.Item label="标题">{detailRecord.title}</Descriptions.Item>
            <Descriptions.Item label="内容">{detailRecord.content}</Descriptions.Item>
            <Descriptions.Item label="目标">
              {TARGET_TYPES.find((t) => t.value === detailRecord.targetType)?.label || detailRecord.targetType}
              {detailRecord.targetValue ? ` (${detailRecord.targetValue})` : ''}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={STATUS_MAP[detailRecord.status]?.color}>{STATUS_MAP[detailRecord.status]?.text}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="定时">{detailRecord.scheduledAt ? dayjs(detailRecord.scheduledAt).format('YYYY-MM-DD HH:mm') : '-'}</Descriptions.Item>
            <Descriptions.Item label="发送">{detailRecord.status === 2 ? `${detailRecord.sentCount} 人 @ ${dayjs(detailRecord.sentAt).format('YYYY-MM-DD HH:mm')}` : '-'}</Descriptions.Item>
            <Descriptions.Item label="创建人">{detailRecord.creator || '-'}</Descriptions.Item>
          </Descriptions>
        )}
      </Modal>
    </Card>
  )
}
