# AI 量化 APP 项目

> 多智能体协同 AI 驱动量化交易系统

## 项目结构

```
lianghua/
├── AI量化APP详细设计文档.md          # 详细设计文档
├── 用户操作流程与界面设计文档.md       # UI/UX 文档
├── flutter_app/                     # Flutter 客户端
│   ├── lib/
│   │   ├── app.dart                 # App 入口
│   │   ├── main.dart                # main 函数
│   │   ├── core/                    # 核心层
│   │   │   ├── theme/               # 深色金融主题
│   │   │   ├── router/              # GoRouter 路由
│   │   │   ├── network/             # Dio HTTP 客户端
│   │   │   ├── providers/           # 状态管理
│   │   │   └── ui/                  # 通用组件
│   │   └── features/                # 功能模块
│   │       ├── auth/                # 认证(登录/注册/测评/协议)
│   │       ├── home/                # 主导航
│   │       ├── market/              # 行情
│   │       ├── monitor/             # 监控
│   │       ├── position/            # 持仓
│   │       └── profile/             # 我的
│   └── pubspec.yaml
├── java_backend/                    # Java Spring Boot 后端
│   ├── src/main/java/com/aiquant/
│   │   ├── AiQuantApplication.java
│   │   ├── config/                  # Web + WebSocket 配置
│   │   ├── controller/              # REST Controller
│   │   ├── service/                 # 业务 Service
│   │   ├── mapper/                  # MyBatis Mapper
│   │   ├── model/                   # 数据模型
│   │   ├── interceptor/            # JWT 拦截器
│   │   ├── util/                    # JWT 工具
│   │   └── ws/                      # WebSocket Handler
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   └── schema.sql              # 数据库初始化
│   └── pom.xml
├── python_ai/                       # Python AI 多 Agent 框架
│   ├── aiquant/
│   │   ├── agents/                  # 四 Agent
│   │   │   ├── decision_agent.py   # 决策 Agent + 五因子门控
│   │   │   ├── execution_agent.py   # 执行 Agent
│   │   │   ├── monitoring_agent.py  # 监控 Agent
│   │   │   ├── backtesting_agent.py # 回测 Agent
│   │   │   └── orchestrator.py      # 编排器
│   │   ├── factors/                 # 五维决策因子
│   │   │   ├── news_sentiment.py    # 新闻情绪
│   │   │   ├── quant_indicator.py   # 量化指标
│   │   │   ├── on_chain.py          # 链上信号
│   │   │   ├── technical_pattern.py # 技术形态
│   │   │   └── risk_reward.py       # 风险收益比
│   │   ├── models/                  # 数据模型
│   │   ├── config.py                # 配置
│   │   └── api.py                   # FastAPI 服务
│   ├── main.py
│   ├── requirements.txt
│   └── .env.example
└── admin_web/                      # 管理后台(待开发)
```

## 快速启动

### 1. 基础设施 (MySQL + Redis)

```bash
cd java_backend
docker-compose up -d
```

### 2. Java 后端

```bash
cd java_backend
mvn spring-boot:run
# 服务: http://localhost:8080/api/v1
```

### 3. Python AI 服务

```bash
cd python_ai
pip install -r requirements.txt
cp .env.example .env  # 编辑配置
python main.py
# 服务: http://localhost:8000
```

### 4. Flutter 客户端

```bash
cd flutter_app
flutter pub get
flutter run
```

## API 列表

### 后端 API (Java, 端口 8080)

| 接口 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 发送验证码 | POST | /auth/sms-code | 短信验证码 |
| 注册 | POST | /auth/register | 注册并返回 Token |
| 登录 | POST | /auth/login | 登录返回 Token |
| 风险测评 | POST | /auth/risk/assessment | 提交测评 |
| 协议签署 | POST | /auth/agreement/sign | 电子签署 |
| 行情列表 | GET | /market/quotes | 获取行情快照 |
| 单标的行情 | GET | /market/quote/{symbol} | 单个标的 |
| 风控状态 | GET | /risk/status | 查询风控状态 |
| 下单检查 | POST | /risk/check | 下单前风控检查 |
| WebSocket | WS | /ws/market | 实时行情推送 |

### AI 服务 API (Python, 端口 8000)

| 接口 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 健康检查 | GET | /health | 含 Agent 状态 |
| Agent 状态 | GET | /agents/status | 四 Agent 状态 |
| AI 决策 | POST | /decision | 五因子门控决策 |
| 提交回测 | POST | /backtest | 提交回测任务 |

## 测试账号

| 字段 | 值 |
|---|---|
| 手机号 | 13800138000 |
| 密码 | 123456 |
