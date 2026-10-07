import { useEffect, useState, useCallback } from 'react'
import { Card, Table, Button, Space, Modal, Input, message, Popconfirm } from 'antd'
import { ReloadOutlined, PlusOutlined, EditOutlined } from '@ant-design/icons'
import client from '../api/client'

/**
 * 系统配置 KV 管理(t_system_config):全局开关/费率/限额在线调整。
 */
export default function SystemConfig() {
  const [list, setList] = useState([])
  const [loading, setLoading] = useState(false)
  const [editing, setEditing] = useState(null) // {key, value} 或 {isNew:true}
  const [keyText, setKeyText] = useState('')
  const [valueText, setValueText] = useState('')
  const [saving, setSaving] = useState(false)

  const fetchData = useCallback(() => {
    setLoading(true)
    client
      .get('/admin/system/configs')
      .then((res) => setList(res.data))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const openEdit = (record) => {
    setEditing(record || { isNew: true })
    setKeyText(record ? record.configkey : '')
    setValueText(record ? record.configvalue : '')
  }

  const save = () => {
    if (!keyText.trim()) {
      message.warning('key 必填')
      return
    }
    setSaving(true)
    client
      .put('/admin/system/configs', { key: keyText.trim(), value: valueText })
      .then((res) => {
        message.success(res.data || '已保存')
        setEditing(null)
        fetchData()
      })
      .finally(() => setSaving(false))
  }

  const columns = [
    {
      title: '配置键',
      dataIndex: 'configkey',
      width: 240,
      render: (v) => <code style={{ color: '#0891b2' }}>{v}</code>,
    },
    {
      title: '配置值',
      dataIndex: 'configvalue',
      ellipsis: true,
      render: (v) => <span style={{ fontFamily: 'monospace' }}>{v}</span>,
    },
    { title: '更新时间', dataIndex: 'updatedat', width: 180 },
    {
      title: '操作',
      key: 'op',
      width: 100,
      render: (_, r) => (
        <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(r)}>
          编辑
        </Button>
      ),
    },
  ]

  return (
    <Card
      title="系统配置"
      extra={
        <Space>
          <Button type="primary" icon={<PlusOutlined />} onClick={() => openEdit(null)}>
            新增配置
          </Button>
          <Button icon={<ReloadOutlined />} onClick={fetchData}>
            刷新
          </Button>
        </Space>
      }
    >
      <Table rowKey="configkey" columns={columns} dataSource={list} loading={loading} pagination={false} />
      <Modal
        title={editing?.isNew ? '新增配置' : `编辑配置 · ${editing?.configkey}`}
        open={!!editing}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        okText="保存"
        cancelText="取消"
      >
        <div style={{ marginBottom: 12 }}>
          <div style={{ marginBottom: 4, fontSize: 12, color: '#8c8c8c' }}>配置键(保存后不可改)</div>
          <Input
            value={keyText}
            onChange={(e) => setKeyText(e.target.value)}
            disabled={!editing?.isNew}
            placeholder="如 copy_trading_paused / fee_rate"
          />
        </div>
        <div>
          <div style={{ marginBottom: 4, fontSize: 12, color: '#8c8c8c' }}>配置值</div>
          <Input.TextArea
            rows={4}
            value={valueText}
            onChange={(e) => setValueText(e.target.value)}
            style={{ fontFamily: 'monospace' }}
          />
        </div>
      </Modal>
    </Card>
  )
}
