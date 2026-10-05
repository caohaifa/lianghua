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
  SendOutlined,
} from '@ant-design/icons'
import client from '../api/client'

const STATUS_FILTER = [
  { label: '草稿', value: 0 },
  { label: '已发布', value: 1 },
  { label: '已下线', value: 2 },
]

export default function Announcements() {
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
    client
      .get('/admin/content/announcements', { params })
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

  const submitForm = async (publish) => {
    const values = await form.validateFields()
    if (editing) {
      await client.put(`/admin/content/announcements/${editing.id}`, {
        ...values,
        status: publish ? 1 : values.status ?? 0,
      })
    } else {
      await client.post('/admin/content/announcements', {
        ...values,
        status: publish ? 1 : 0,
      })
    }
    message.success(publish ? '已发布(全量广播)' : '已保存草稿')
    setModalOpen(false)
    fetchData()
  }

  const offline = async (record) => {
    await client.put(`/admin/content/announcements/${record.id}`, {
      title: record.title,
      content: record.content,
      status: 2,
    })
    message.success('已下线')
    fetchData()
  }

  const publishRow = async (record) => {
    await client.put(`/admin/content/announcements/${record.id}`, {
      title: record.title,
      content: record.content,
      status: 1,
    })
    message.success('已发布(全量广播)')
    fetchData()
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '标题', dataIndex: 'title' },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (v) => {
        const map = { 0: ['草稿', 'default'], 1: ['已发布', 'green'], 2: ['已下线', 'red'] }
        const [text, color] = map[v] || [v]
        return <Tag color={color}>{text}</Tag>
      },
    },
    { title: '发布人', dataIndex: 'publisherId', width: 110, render: (v) => v || '-' },
    { title: '发布时间', dataIndex: 'publishedAt', width: 180, render: (v) => v || '-' },
    { title: '创建时间', dataIndex: 'createdAt', width: 180 },
    {
      title: '操作',
      width: 240,
      fixed: 'right',
      render: (_, record) => (
        <Space size="small">
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>
            编辑
          </Button>
          {record.status !== 1 ? (
            <Popconfirm title="确认发布?将全量广播" onConfirm={() => publishRow(record)}>
              <Button size="small" type="primary" icon={<SendOutlined />}>
                发布
              </Button>
            </Popconfirm>
          ) : (
            <Popconfirm title="确认下线该公告?" onConfirm={() => offline(record)}>
              <Button size="small" danger>
                下线
              </Button>
            </Popconfirm>
          )}
        </Space>
      ),
    },
  ]

  return (
    <Card title="系统公告">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="公告标题"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          style={{ width: 200 }}
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
          新建公告
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

      <Modal
        title={editing ? '编辑公告' : '新建公告'}
        open={modalOpen}
        width={640}
        onCancel={() => setModalOpen(false)}
        footer={[
          <Button key="cancel" onClick={() => setModalOpen(false)}>
            取消
          </Button>,
          <Button key="draft" onClick={() => submitForm(false)}>
            保存草稿
          </Button>,
          <Button key="publish" type="primary" onClick={() => submitForm(true)}>
            保存并发布
          </Button>,
        ]}
        destroyOnClose
      >
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Form.Item
            name="title"
            label="标题"
            rules={[
              { required: true, message: '请输入标题' },
              { max: 100, message: '标题不超过100字' },
            ]}
          >
            <Input placeholder="公告标题" maxLength={100} showCount />
          </Form.Item>
          <Form.Item
            name="content"
            label="正文"
            rules={[{ required: true, message: '请输入正文' }]}
          >
            <Input.TextArea rows={8} placeholder="公告内容(注意合规,不得出现必涨/荐股/稳赚等话术)" />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  )
}
