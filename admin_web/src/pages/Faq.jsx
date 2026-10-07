import { useEffect, useState, useCallback } from 'react'
import {
  Card, Table, Input, Select, Button, Space, Tag, Modal, Form,
  message, Popconfirm, InputNumber, Collapse,
} from 'antd'
import {
  ReloadOutlined, SearchOutlined, PlusOutlined, EditOutlined, DeleteOutlined,
} from '@ant-design/icons'
import client from '../api/client'

const CATEGORIES = [
  { label: '账户相关', value: 'account' },
  { label: '现货交易', value: 'trading' },
  { label: '合约交易', value: 'futures' },
  { label: 'AI 策略', value: 'ai' },
  { label: '跟单系统', value: 'copy' },
  { label: '其他', value: 'other' },
]
const CAT_MAP = Object.fromEntries(CATEGORIES.map((c) => [c.value, c.label]))

export default function Faq() {
  const [data, setData] = useState({ list: [], total: 0 })
  const [loading, setLoading] = useState(false)
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [category, setCategory] = useState()
  const [statusFilter, setStatusFilter] = useState()
  const [modalOpen, setModalOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form] = Form.useForm()

  const fetchData = useCallback(() => {
    setLoading(true)
    const params = { page, size }
    if (keyword) params.keyword = keyword
    if (category) params.category = category
    if (statusFilter !== undefined) params.status = statusFilter
    client.get('/admin/content/faqs', { params })
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [page, size, keyword, category, statusFilter])

  useEffect(() => { fetchData() }, [fetchData])

  const openCreate = () => {
    setEditing(null)
    form.resetFields()
    form.setFieldsValue({ category: 'other', sortOrder: 0, status: 1 })
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
      await client.put(`/admin/content/faqs/${editing.id}`, values)
      message.success('已保存')
    } else {
      await client.post('/admin/content/faqs', values)
      message.success('已创建')
    }
    setModalOpen(false)
    fetchData()
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    {
      title: '分类', dataIndex: 'category', width: 100,
      render: (v) => <Tag color="blue">{CAT_MAP[v] || v}</Tag>,
    },
    { title: '问题', dataIndex: 'question', ellipsis: true },
    {
      title: '回答', dataIndex: 'answer', ellipsis: true,
      render: (v) => <span style={{ color: '#64748b' }}>{v?.length > 80 ? v.slice(0, 80) + '...' : v}</span>,
    },
    { title: '排序', dataIndex: 'sortOrder', width: 70, sorter: (a, b) => a.sortOrder - b.sortOrder },
    {
      title: '状态', dataIndex: 'status', width: 80,
      render: (v) => <Tag color={v === 1 ? 'green' : 'default'}>{v === 1 ? '显示' : '隐藏'}</Tag>,
    },
    { title: '创建人', dataIndex: 'creator', width: 90 },
    {
      title: '操作', width: 120, fixed: 'right',
      render: (_, record) => (
        <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
      ),
    },
  ]

  return (
    <Card title="帮助中心 / FAQ 管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="搜索问题/回答" value={keyword} onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 200 }} allowClear />
        <Select placeholder="分类" allowClear style={{ width: 120 }} value={category}
          onChange={setCategory} options={CATEGORIES} />
        <Select placeholder="状态" allowClear style={{ width: 100 }} value={statusFilter}
          onChange={setStatusFilter}
          options={[{ label: '显示', value: 1 }, { label: '隐藏', value: 0 }]} />
        <Button type="primary" icon={<SearchOutlined />} onClick={() => setPage(1)}>查询</Button>
        <Button icon={<ReloadOutlined />} onClick={fetchData}>刷新</Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} ghost>新建 FAQ</Button>
      </Space>
      <Table rowKey="id" columns={columns} dataSource={data.list} loading={loading}
        scroll={{ x: 1100 }}
        pagination={{
          current: page, pageSize: size, total: data.total, showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`, onChange: (p, s) => { setPage(p); setSize(s) },
        }} />

      <Modal title={editing ? '编辑 FAQ' : '新建 FAQ'} open={modalOpen} onOk={submitForm}
        onCancel={() => setModalOpen(false)} width={640} destroyOnClose>
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Space size="large">
            <Form.Item name="category" label="分类" rules={[{ required: true }]}>
              <Select style={{ width: 160 }} options={CATEGORIES} />
            </Form.Item>
            <Form.Item name="sortOrder" label="排序(越小越前)">
              <InputNumber min={0} max={9999} />
            </Form.Item>
            <Form.Item name="status" label="状态">
              <Select style={{ width: 100 }} options={[{ label: '显示', value: 1 }, { label: '隐藏', value: 0 }]} />
            </Form.Item>
          </Space>
          <Form.Item name="question" label="问题" rules={[{ required: true, message: '请输入问题' }]}>
            <Input placeholder="用户常见问题" maxLength={200} showCount />
          </Form.Item>
          <Form.Item name="answer" label="回答" rules={[{ required: true, message: '请输入回答' }]}>
            <Input.TextArea rows={6} placeholder="详细解答(支持纯文本)" />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  )
}
