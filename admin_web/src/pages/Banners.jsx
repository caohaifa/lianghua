import { useEffect, useState, useCallback } from 'react'
import {
  Card, Table, Input, Select, Button, Space, Tag, Modal, Form,
  message, Popconfirm, InputNumber, DatePicker, Switch, Tooltip, Image,
} from 'antd'
import {
  ReloadOutlined, SearchOutlined, PlusOutlined, EditOutlined,
  EyeInvisibleOutlined, EyeOutlined, ArrowUpOutlined, ArrowDownOutlined,
} from '@ant-design/icons'
import client from '../api/client'
import dayjs from 'dayjs'

const LINK_TYPES = [
  { label: '无跳转', value: 'none' },
  { label: '外部链接', value: 'url' },
  { label: '策略详情', value: 'strategy' },
  { label: '公告详情', value: 'announcement' },
]

export default function Banners() {
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
    if (keyword) params.title = keyword
    if (status !== undefined) params.status = status
    client.get('/admin/content/banners', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, status])

  useEffect(() => { fetchData() }, [fetchData])

  const openCreate = () => {
    setEditing(null)
    form.resetFields()
    form.setFieldsValue({ linkType: 'none', position: 0, status: 1 })
    setModalOpen(true)
  }

  const openEdit = (record) => {
    setEditing(record)
    form.setFieldsValue({
      ...record,
      startTime: record.startTime ? dayjs(record.startTime) : null,
      endTime: record.endTime ? dayjs(record.endTime) : null,
    })
    setModalOpen(true)
  }

  const submitForm = async () => {
    const values = await form.validateFields()
    const payload = {
      ...values,
      startTime: values.startTime ? values.startTime.format('YYYY-MM-DD HH:mm:ss') : null,
      endTime: values.endTime ? values.endTime.format('YYYY-MM-DD HH:mm:ss') : null,
    }
    if (editing) {
      await client.put(`/admin/content/banners/${editing.id}`, payload)
      message.success('已保存')
    } else {
      await client.post('/admin/content/banners', payload)
      message.success('已创建')
    }
    setModalOpen(false)
    fetchData()
  }

  const toggleStatus = async (record) => {
    const newStatus = record.status === 1 ? 0 : 1
    await client.put(`/admin/content/banners/${record.id}/status`, { status: newStatus })
    message.success(newStatus === 1 ? '已启用' : '已禁用')
    fetchData()
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    {
      title: '图片', dataIndex: 'imageUrl', width: 100,
      render: (v) => v ? <Image src={v} width={60} height={34} style={{ objectFit: 'cover', borderRadius: 4 }} /> : '-',
    },
    { title: '标题', dataIndex: 'title', ellipsis: true },
    {
      title: '跳转', dataIndex: 'linkType', width: 100,
      render: (v) => <Tag>{LINK_TYPES.find((t) => t.value === v)?.label || v}</Tag>,
    },
    { title: '排序', dataIndex: 'position', width: 70, sorter: (a, b) => a.position - b.position },
    {
      title: '状态', dataIndex: 'status', width: 80,
      render: (v) => <Tag color={v === 1 ? 'green' : 'default'}>{v === 1 ? '启用' : '禁用'}</Tag>,
    },
    {
      title: '展示时段', width: 200,
      render: (_, r) => {
        if (!r.startTime && !r.endTime) return <span style={{ color: '#94a3b8' }}>永久</span>
        return (
          <span style={{ fontSize: 12 }}>
            {r.startTime ? dayjs(r.startTime).format('MM/DD HH:mm') : '∞'}
            {' ~ '}
            {r.endTime ? dayjs(r.endTime).format('MM/DD HH:mm') : '∞'}
          </span>
        )
      },
    },
    { title: '创建人', dataIndex: 'creator', width: 90 },
    {
      title: '操作', width: 180, fixed: 'right',
      render: (_, record) => (
        <Space size="small">
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
          <Tooltip title={record.status === 1 ? '禁用' : '启用'}>
            <Button size="small"
              icon={record.status === 1 ? <EyeInvisibleOutlined /> : <EyeOutlined />}
              onClick={() => toggleStatus(record)}
              danger={record.status === 1}
            />
          </Tooltip>
        </Space>
      ),
    },
  ]

  return (
    <Card title="轮播图管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="标题" value={keyword} onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 180 }} allowClear />
        <Select placeholder="状态" allowClear style={{ width: 100 }} value={status} onChange={setStatus}
          options={[{ label: '启用', value: 1 }, { label: '禁用', value: 0 }]} />
        <Button type="primary" icon={<SearchOutlined />} onClick={() => setPage(1)}>查询</Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>刷新</Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} ghost>新建轮播</Button>
      </Space>
      <Table rowKey="id" columns={columns} dataSource={data.list} loading={loading}
        scroll={{ x: 1200 }}
        pagination={{
          current: page, pageSize: size, total: data.total, showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`, onChange: (p, s) => { setPage(p); setSize(s) },
        }} />

      <Modal title={editing ? '编辑轮播' : '新建轮播'} open={modalOpen} onOk={submitForm}
        onCancel={() => setModalOpen(false)} width={640} destroyOnClose>
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Form.Item name="title" label="标题" rules={[{ required: true, message: '请输入标题' }]}>
            <Input placeholder="轮播标题" maxLength={100} showCount />
          </Form.Item>
          <Form.Item name="imageUrl" label="图片 URL" rules={[{ required: true, message: '请输入图片地址' }]}>
            <Input placeholder="https://... 或 OSS 路径" />
          </Form.Item>
          <Space size="large">
            <Form.Item name="linkType" label="跳转类型">
              <Select style={{ width: 140 }} options={LINK_TYPES} />
            </Form.Item>
            <Form.Item name="linkUrl" label="跳转链接/ID">
              <Input placeholder="URL 或资源 ID" style={{ width: 240 }} />
            </Form.Item>
          </Space>
          <Space size="large">
            <Form.Item name="position" label="排序权重">
              <InputNumber min={0} max={9999} />
            </Form.Item>
            <Form.Item name="startTime" label="开始时间">
              <DatePicker showTime format="YYYY-MM-DD HH:mm" />
            </Form.Item>
            <Form.Item name="endTime" label="结束时间">
              <DatePicker showTime format="YYYY-MM-DD HH:mm" />
            </Form.Item>
          </Space>
        </Form>
      </Modal>
    </Card>
  )
}
