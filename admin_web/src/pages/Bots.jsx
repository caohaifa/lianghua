import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Card, Table, Button, Space, Tag, Switch, Modal, Drawer,
  Descriptions, Input, InputNumber, Statistic, Row, Col, Timeline, Alert, message,
} from 'antd'
import { ReloadOutlined, EditOutlined, SearchOutlined, EyeOutlined } from '@ant-design/icons'
import client from '../api/client'

const pnlColor = (v) => (v > 0 ? '#cf1322' : v < 0 ? '#3f8600' : '#8c8c8c')

/** 解析 config_json(容错),缺失键回退到模式默认值,得到表单初始值。 */
function initialValues(defs, configJson) {
  let parsed = {}
  try {
    parsed = configJson ? JSON.parse(configJson) : {}
  } catch {
    parsed = {}
  }
  const vals = {}
  for (const d of defs) {
    const raw = parsed[d.key]
    vals[d.key] = raw === undefined || raw === null || raw === '' ? d.def : Number(raw)
  }
  return vals
}

/**
 * 机器人管理:列表(关联监控状态/信号)、启停、按策略手工调整参数、绩效透视详情。
 * 参数以结构化表单录入(字段/范围/默认值来自后端 param-schema),序列化为 config_json 保存,
 * 下一轮扫描由引擎读取生效(缺失项自动回退默认值)。
 */
export default function Bots() {
  const [list, setList] = useState([])
  const [loading, setLoading] = useState(false)
  const [editing, setEditing] = useState(null)
  const [formVals, setFormVals] = useState({})
  const [saving, setSaving] = useState(false)
  const [keyword, setKeyword] = useState('')
  const [schema, setSchema] = useState({})

  const [detail, setDetail] = useState(null)
  const [detailLoading, setDetailLoading] = useState(false)

  const fetchData = useCallback(() => {
    setLoading(true)
    client
      .get('/admin/bots')
      .then((res) => setList(res.data.list || []))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    fetchData()
    client
      .get('/admin/bots/param-schema')
      .then((res) => setSchema(res.data || {}))
      .catch(() => message.warning('参数模式加载失败,仍可保存但表单字段可能不全'))
  }, [fetchData])

  const filtered = useMemo(() => {
    const kw = keyword.trim().toLowerCase()
    if (!kw) return list
    return list.filter(
      (r) =>
        String(r.botUserId || '').toLowerCase().includes(kw) ||
        String(r.symbol || '').toLowerCase().includes(kw) ||
        String(r.strategyKey || '').toLowerCase().includes(kw)
    )
  }, [list, keyword])

  const toggle = (record, checked) => {
    const status = checked ? 'running' : 'paused'
    client
      .put(`/admin/bots/${record.id}/status`, { status })
      .then((res) => {
        message.success(res.data || '已更新')
        fetchData()
      })
      .catch((e) => message.error(e?.response?.data?.message || '操作失败'))
  }

  const editDefs = editing ? schema[editing.strategyKey] || [] : []

  const openEdit = (record) => {
    setEditing(record)
    const defs = schema[record.strategyKey] || []
    setFormVals(initialValues(defs, record.configJson))
  }

  const resetDefaults = () => {
    if (!editing) return
    setFormVals(initialValues(editDefs, '{}'))
  }

  const saveConfig = () => {
    if (!editing) return
    const out = {}
    for (const d of editDefs) {
      const v = formVals[d.key]
      if (v === undefined || v === null || v === '') {
        message.error(`${d.label} 不能为空`)
        return
      }
      const num = Number(v)
      if (Number.isNaN(num)) {
        message.error(`${d.label} 必须是数字`)
        return
      }
      if (num < d.min || num > d.max) {
        message.error(`${d.label} 需在 ${d.min} ~ ${d.max} 之间`)
        return
      }
      out[d.key] = d.integer ? Math.round(num) : num
    }
    setSaving(true)
    client
      .put(`/admin/bots/${editing.id}/config`, { config_json: JSON.stringify(out) })
      .then((res) => {
        message.success(res.data || '已保存')
        setEditing(null)
        fetchData()
      })
      .catch((e) => message.error(e?.response?.data?.message || '保存失败'))
      .finally(() => setSaving(false))
  }

  const openDetail = (record) => {
    setDetail({ id: record.id, data: null })
    setDetailLoading(true)
    client
      .get(`/admin/bots/${record.id}/stats`)
      .then((res) => setDetail({ id: record.id, data: res.data }))
      .catch((e) => {
        message.error(e?.response?.data?.message || '加载详情失败')
        setDetail(null)
      })
      .finally(() => setDetailLoading(false))
  }

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '机器人账号', dataIndex: 'botUserId', width: 150 },
    {
      title: '策略',
      dataIndex: 'strategyKey',
      width: 120,
      render: (v) => <Tag color="cyan">{v}</Tag>,
    },
    { title: '标的', dataIndex: 'symbol', width: 110 },
    {
      title: '运行状态',
      dataIndex: 'monitorStatus',
      width: 100,
      render: (v) => (v === 'running' ? <Tag color="green">运行中</Tag> : <Tag>已暂停</Tag>),
    },
    { title: '当前信号', dataIndex: 'monitorSignal', width: 140, render: (v) => v || '-' },
    {
      title: '启停',
      key: 'toggle',
      width: 80,
      render: (_, r) => (
        <Switch
          checked={r.monitorStatus === 'running'}
          onChange={(checked) => toggle(r, checked)}
          size="small"
        />
      ),
    },
    {
      title: '操作',
      key: 'actions',
      width: 150,
      render: (_, r) => (
        <Space size="small">
          <Button size="small" icon={<EyeOutlined />} onClick={() => openDetail(r)}>详情</Button>
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(r)}>参数</Button>
        </Space>
      ),
    },
    { title: '创建时间', dataIndex: 'createdAt', width: 170 },
  ]

  const posColumns = [
    { title: '标的', dataIndex: 'symbol' },
    { title: '方向', dataIndex: 'side', width: 80, render: (v) => (v === 'buy' ? '多' : v === 'sell' ? '空' : v) },
    { title: '数量', dataIndex: 'amount', width: 100 },
    { title: '开仓均价', dataIndex: 'entryPrice', width: 110 },
    { title: '现价', dataIndex: 'currentPrice', width: 100 },
    {
      title: '浮盈',
      dataIndex: 'pnl',
      width: 100,
      render: (v) => <span style={{ color: pnlColor(v) }}>{v ?? 0}</span>,
    },
  ]

  const orderColumns = [
    { title: '标的', dataIndex: 'symbol', width: 110 },
    { title: '方向', dataIndex: 'side', width: 70 },
    { title: '价格', dataIndex: 'price', width: 90 },
    { title: '数量', dataIndex: 'filledAmount', width: 90 },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (v) => <Tag color={v === 'filled' ? 'green' : v === 'failed' ? 'red' : 'default'}>{v}</Tag>,
    },
    { title: '时间', dataIndex: 'createdAt', width: 160 },
  ]

  const d = detail?.data

  return (
    <>
      <Card
        title="机器人管理"
        extra={
          <Space>
            <Input
              placeholder="按 账号/标的/策略 搜索"
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              allowClear
              style={{ width: 220 }}
              prefix={<SearchOutlined />}
            />
            <Button icon={<ReloadOutlined />} onClick={fetchData}>刷新</Button>
          </Space>
        }
      >
        <Table
          rowKey="id"
          columns={columns}
          dataSource={filtered}
          loading={loading}
          pagination={{ pageSize: 15, showSizeChanger: true, showTotal: (t) => `共 ${t} 条` }}
        />
      </Card>

      <Modal
        title={`调整参数 · 机器人 #${editing?.id} (${editing?.strategyKey})`}
        open={!!editing}
        onCancel={() => setEditing(null)}
        footer={[
          <Button key="reset" onClick={resetDefaults}>恢复默认</Button>,
          <Button key="cancel" onClick={() => setEditing(null)}>取消</Button>,
          <Button key="ok" type="primary" loading={saving} onClick={saveConfig}>保存</Button>,
        ]}
        width={560}
      >
        {editDefs.length === 0 ? (
          <Alert
            type="warning"
            showIcon
            message="该策略暂无可调参数"
            description="策略键未在参数模式中定义,或参数模式仍在加载,请刷新后重试。"
          />
        ) : (
          <>
            <p style={{ color: '#8c8c8c', fontSize: 12, marginTop: 0 }}>
              按策略「{editing?.strategyKey}」手工调整参数,留空项保存时按默认值处理;保存后下一轮扫描生效。
            </p>
            <div style={{ maxHeight: 360, overflowY: 'auto' }}>
              {editDefs.map((def) => (
                <Row key={def.key} align="middle" gutter={12} style={{ marginBottom: 12 }}>
                  <Col span={11}>
                    <div style={{ fontWeight: 500 }}>{def.label}</div>
                    <div style={{ color: '#8c8c8c', fontSize: 12 }}>
                      {def.unit ? `${def.unit} · ` : ''}默认 {def.def} · 范围 {def.min}~{def.max}
                    </div>
                  </Col>
                  <Col span={13}>
                    <InputNumber
                      style={{ width: '100%' }}
                      min={def.min}
                      max={def.max}
                      step={def.step}
                      precision={def.integer ? 0 : undefined}
                      value={formVals[def.key]}
                      onChange={(v) => setFormVals((s) => ({ ...s, [def.key]: v }))}
                      addonAfter={def.key}
                    />
                  </Col>
                </Row>
              ))}
            </div>
          </>
        )}
      </Modal>

      <Drawer
        title={`机器人详情 #${detail?.id ?? ''}`}
        open={!!detail}
        onClose={() => setDetail(null)}
        width={720}
        loading={detailLoading}
      >
        {d && (
          <>
            <Descriptions column={2} bordered size="small" style={{ marginBottom: 16 }}>
              <Descriptions.Item label="机器人账号">{d.botUserId}</Descriptions.Item>
              <Descriptions.Item label="策略">
                <Tag color="cyan">{d.strategyKey}</Tag>
              </Descriptions.Item>
              <Descriptions.Item label="标的">{d.symbol}</Descriptions.Item>
              <Descriptions.Item label="运行状态">
                {d.monitorStatus === 'running' ? <Tag color="green">运行中</Tag> : <Tag>已暂停</Tag>}
              </Descriptions.Item>
              <Descriptions.Item label="最新信号" span={2}>{d.latestSignal || '-'}</Descriptions.Item>
            </Descriptions>

            <div style={{ fontWeight: 600, margin: '8px 0' }}>信号时间线(最近 30 条)</div>
            {d.signalHistory?.length ? (
              <Timeline
                style={{ marginBottom: 16 }}
                items={d.signalHistory.map((s) => ({
                  color: /买入|open_long/.test(s.signal || '') ? 'red'
                       : /平仓|做空|open_short/.test(s.signal || '') ? 'green' : 'gray',
                  children: (
                    <>
                      <div>{s.signal}</div>
                      <div style={{ color: '#8c8c8c', fontSize: 12 }}>
                        {s.action} · {s.createdAt}
                      </div>
                    </>
                  ),
                }))}
              />
            ) : (
              <div style={{ color: '#8c8c8c', marginBottom: 16 }}>暂无信号记录</div>
            )}

            <Row gutter={16} style={{ marginBottom: 16 }}>
              <Col span={6}>
                <Statistic title="总盈亏" value={d.totalPnl} valueStyle={{ color: pnlColor(d.totalPnl) }} />
              </Col>
              <Col span={6}>
                <Statistic title="已实现" value={d.realizedPnl} valueStyle={{ color: pnlColor(d.realizedPnl) }} />
              </Col>
              <Col span={6}>
                <Statistic title="未实现" value={d.unrealizedPnl} valueStyle={{ color: pnlColor(d.unrealizedPnl) }} />
              </Col>
              <Col span={6}>
                <Statistic title="成交额" value={d.turnover} />
              </Col>
            </Row>

            <Row gutter={16} style={{ marginBottom: 16 }}>
              <Col span={8}><Statistic title="总订单" value={d.totalOrders} /></Col>
              <Col span={8}><Statistic title="成交" value={d.filledOrders} /></Col>
              <Col span={8}><Statistic title="失败" value={d.failedOrders} valueStyle={{ color: d.failedOrders > 0 ? '#cf1322' : undefined }} /></Col>
            </Row>

            <div style={{ fontWeight: 600, margin: '8px 0' }}>当前持仓({d.positions?.length || 0})</div>
            <Table rowKey={(r) => `${r.symbol}-${r.side}`} size="small" columns={posColumns}
                   dataSource={d.positions || []} pagination={false} style={{ marginBottom: 16 }} />

            <div style={{ fontWeight: 600, margin: '8px 0' }}>近期订单</div>
            <Table rowKey="orderId" size="small" columns={orderColumns}
                   dataSource={d.recentOrders || []} pagination={{ pageSize: 8 }} />
          </>
        )}
      </Drawer>
    </>
  )
}
