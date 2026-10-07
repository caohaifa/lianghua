import { useEffect, useState } from 'react'
import { Row, Col, Card, Spin } from 'antd'
import {
  UserOutlined,
  RiseOutlined,
  FundOutlined,
  DollarOutlined,
} from '@ant-design/icons'
import client from '../api/client'

export default function Dashboard() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    client
      .get('/admin/system/dashboard')
      .then((res) => setData(res.data))
      .finally(() => setLoading(false))
  }, [])

  if (loading || !data) {
    return (
      <div style={{ textAlign: 'center', padding: 80 }}>
        <Spin size="large" />
      </div>
    )
  }

  const s = data.stats

  const cards = [
    {
      title: '总用户数',
      value: s.totalUsers,
      icon: <UserOutlined />,
      color: '#3b82f6',
      sub: `今日新增 ${s.todayNewUsers}`,
    },
    {
      title: '今日活跃 (DAU)',
      value: s.dau,
      icon: <RiseOutlined />,
      color: '#10b981',
      sub: `冻结 ${s.frozenUsers}`,
    },
    {
      title: '累计交易额',
      value: Number(s.tradeVolume).toFixed(2),
      icon: <FundOutlined />,
      color: '#f59e0b',
      sub: `订单 ${s.orderCount} 笔`,
    },
    {
      title: '在线策略',
      value: s.onlineStrategies,
      icon: <DollarOutlined />,
      color: '#8b5cf6',
      sub: `持仓 ${s.openPositions} 个`,
    },
  ]

  return (
    <div>
      <Row gutter={[16, 16]}>
        {cards.map((c) => (
          <Col xs={24} sm={12} lg={6} key={c.title}>
            <Card>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <div>
                  <div style={{ color: '#64748b', fontSize: 14 }}>{c.title}</div>
                  <div
                    style={{
                      fontSize: 28,
                      fontWeight: 700,
                      margin: '8px 0',
                    }}
                  >
                    {c.value}
                  </div>
                  <div style={{ color: '#94a3b8', fontSize: 12 }}>{c.sub}</div>
                </div>
                <div
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: 12,
                    background: `${c.color}1a`,
                    color: c.color,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 22,
                  }}
                >
                  {c.icon}
                </div>
              </div>
            </Card>
          </Col>
        ))}
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={14}>
          <Card title="近 7 天新增用户">
            <LineChart data={data.userGrowth || []} />
          </Card>
        </Col>
        <Col xs={24} lg={10}>
          <Card title="用户风险等级分布">
            <BarChart data={data.riskDistribution || []} />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={24}>
          <Card title="近 7 天成交额趋势">
            <VolumeChart data={data.tradeVolume || []} color="#f59e0b" label="成交额" />
          </Card>
        </Col>
      </Row>
    </div>
  )
}

/** 极简 SVG 折线图 */
function LineChart({ data }) {
  const width = 460
  const height = 240
  const pad = 32
  if (!data.length) {
    return <Empty />
  }
  const counts = data.map((d) => Number(d.count))
  const max = Math.max(...counts, 1)
  const stepX = (width - pad * 2) / Math.max(data.length - 1, 1)
  const points = data.map((d, i) => {
    const x = pad + i * stepX
    const y = height - pad - (Number(d.count) / max) * (height - pad * 2)
    return [x, y]
  })
  const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0]},${p[1]}`).join(' ')
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%' }}>
      <line x1={pad} y1={height - pad} x2={width - pad} y2={height - pad} stroke="#e2e8f0" />
      <path d={path} fill="none" stroke="#3b82f6" strokeWidth={2} />
      {points.map((p, i) => (
        <g key={i}>
          <circle cx={p[0]} cy={p[1]} r={3.5} fill="#3b82f6" />
          <text x={p[0]} y={height - pad + 16} fontSize={10} textAnchor="middle" fill="#94a3b8">
            {String(data[i].date).slice(5)}
          </text>
          <text x={p[0]} y={p[1] - 8} fontSize={10} textAnchor="middle" fill="#475569">
            {counts[i]}
          </text>
        </g>
      ))}
    </svg>
  )
}

/** 水平条形图 */
function BarChart({ data }) {
  if (!data.length) {
    return <Empty />
  }
  const max = Math.max(...data.map((d) => Number(d.count)), 1)
  const colorMap = {
    R1: '#10b981',
    R2: '#84cc16',
    R3: '#f59e0b',
    R4: '#f97316',
    R5: '#ef4444',
    未测评: '#94a3b8',
  }
  return (
    <div>
      {data.map((d) => (
        <div key={d.level} style={{ marginBottom: 14 }}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: 13,
              marginBottom: 4,
            }}
          >
            <span>{d.level}</span>
            <span style={{ color: '#64748b' }}>{d.count}</span>
          </div>
          <div style={{ height: 10, background: '#f1f5f9', borderRadius: 5, overflow: 'hidden' }}>
            <div
              style={{
                width: `${(Number(d.count) / max) * 100}%`,
                height: '100%',
                background: colorMap[d.level] || '#3b82f6',
                borderRadius: 5,
              }}
            />
          </div>
        </div>
      ))}
    </div>
  )
}

function Empty() {
  return (
    <div style={{ textAlign: 'center', color: '#94a3b8', padding: 40 }}>暂无数据</div>
  )
}

/** 金额趋势柱状图(成交额/分成收入) */
function VolumeChart({ data, color, label }) {
  if (!data.length) return <Empty />
  const values = data.map((d) => Number(d.volume ?? d.income ?? 0))
  const max = Math.max(...values, 1)
  return (
    <div>
      {data.map((d, i) => {
        const v = Number(d.volume ?? d.income ?? 0)
        return (
          <div key={i} style={{ marginBottom: 12 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
              <span style={{ color: '#64748b' }}>{String(d.date).slice(5)}</span>
              <span style={{ fontWeight: 600 }}>¥{v.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
            </div>
            <div style={{ height: 8, background: '#f1f5f9', borderRadius: 4, overflow: 'hidden' }}>
              <div style={{ width: `${(v / max) * 100}%`, height: '100%', background: color, borderRadius: 4 }} />
            </div>
          </div>
        )
      })}
    </div>
  )
}
