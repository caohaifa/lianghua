# AI 页跟单系统（简化版）：发布需审核 + 比例跟单复制

## Context

现状：AI 页「策略广场」是 3 张写死静态卡（假数据），点「跟单」只是打开新建监控弹层，无真实跟单关系。目标：
1. 注册会员可把自己的监控（策略）**申请发布**到策略广场；
2. **后台管理员审核通过后**才在前端广场展示；
3. 其他用户选比例跟单，leader 监控每次真实买入/卖出时按比例复制到 follower 现货账户。

## 简化决定（按用户反馈）

- 不建复制流水表（复制失败仅打日志）；不显示 leader 收益/胜率统计；广场卡片只显示 标题/策略/标的/发布者/跟单人数。
- 发布状态机：`pending(申请中) → published(通过) / rejected(驳回)`；leader 可 `offline` 下架。只有 `published` 在广场可见、可被跟单。

## 跟单复制语义

- 比例 {10,25,50,100}%，默认 10。
- 买入：follower 量 = leader 实际成交量 × ratio/100；A 股向下取整手、加密取 1e-6；按 follower 可用余额截断(×0.995)；名义额 <5 或校验失败则跳过（日志）。
- 卖出：follower 卖自己在该标的多仓（加密全平；A 股只卖 availableAmount，天然满足 T+1）。
- 复用 `TradingService.placeOrder(userId, symbol, side, "market", null, qty, "跟单:"+strategy)`；单 follower 异常隔离（try/catch），不影响他人与 leader。

## 后端（java_backend）

### 表（schema-h2.sql + schema-mysql.sql；sql.init mode=always 重启自动建表）

```sql
t_strategy_publish(id PK AI, leader_id, monitor_id, title(50), description(200),
  strategy(50), symbol(30), status pending|published|rejected|offline, created_at, updated_at)
  KEY idx_sp_leader, idx_sp_monitor
t_strategy_follow(id PK AI, user_id, publish_id, leader_id, monitor_id, ratio INT,
  status active|stopped, created_at, updated_at)  KEY idx_sf_user, idx_sf_monitor
```

### 新文件

- `model/StrategyPublish.java`、`model/StrategyFollow.java`
- `mapper/StrategyPublishMapper.java`、`mapper/StrategyFollowMapper.java`（注解 SQL，风格对齐 MonitorMapper）
- `service/CopyTradingService.java`：publish/myPublishes/listPublished/follow/stopFollow/myFollows + `replicate(Monitor, side, Order leaderOrder)`
  - listPublished：status=published，join 用户昵称（空则手机号脱敏 138****8000），followers 数 `GROUP BY publish_id` 一次查全
- `controller/CopyTradingController.java`（`/copy`，uid(request) 模式同 MonitorController）：
  - `POST /copy/publish` {monitor_id,title,description} — 校验监控属本人；(leader,monitor) 已有记录则更新并重置 pending
  - `GET /copy/my-publish` — 我的发布（含状态，供卡片显示 审核中/已发布/驳回）
  - `GET /copy/published` — 广场列表（仅 published）
  - `DELETE /copy/publish/{id}` — 本人下架（offline，同时相关跟单置 stopped）
  - `PUT /copy/follow` {publish_id,ratio} — 仅 published 可跟；不能跟自己；重复跟单=更新比例并激活
  - `GET /copy/follows` — 我的跟单列表（含发布信息）
  - `DELETE /copy/follow/{id}` — 停止跟单
- `controller/AdminCopyController.java`（`/admin/copy`，风格对齐 AdminContentController：ApiResponse + auditLogService.record + AdminUserController.pageResult）：
  - `GET /admin/copy/publishes?status=&page=&size=` — 分页（含 leader 手机号/昵称）
  - `PUT /admin/copy/publishes/{id}/status` {status: published|rejected} — 审核动作 + 审计日志（拒绝时同步停止相关跟单？不：pending/rejected 本就不可跟，无需处理）

### 既有文件小改

- `MonitorExecutionService.java` L108 buy / L128 sell 下单受理后调 `copyTradingService.replicate(m, side, order)`（注入）
- `MonitorController.delete`：删监控前若有发布 → 下架 + 跟单置 stopped

## 管理后台（admin_web，React + antd）

- 新页面 `src/pages/CopyApprovals.jsx`（对齐 Strategies.jsx/Announcements.jsx 模式）：Table 列=标题/申请人/策略/标的/申请时间/状态，行操作 通过/驳回（pending 才显示），顶部状态筛选
- `src/App.jsx` 加路由 `/copy-approvals`；`src/layout/MainLayout.jsx` 菜单加「跟单审核」

## Flutter（flutter_app）

- 新文件 `lib/features/monitor/providers/copy_provider.dart`：PublishedStrategy/MyPublish/FollowItem 模型 + loadPublished/loadMyPublishes/loadFollows/publish/unpublish/follow/stopFollow（_errMsg 模式同 MonitorProvider）
- `lib/features/ai/pages/ai_page.dart`：
  - 策略广场：删 `_catalog` 静态卡 → 真实发布列表 `_PublishedCard`（标题/策略 chip/标的/发布者/N 人跟单/「跟单」按钮）；空态引导
  - 我的策略 tile：未发布→「发布」开 PublishSheet；pending→「审核中」灰标；published→「已发布」可下架
  - 新增「我的跟单」分区：tile + 取消跟单二次确认
  - PublishSheet（标题预填「策略名·标的」/描述选填/提交审核）、FollowSheet（比例 chips + 确认）；样式对齐 _CreateSheet（SafeArea+SingleChildScrollView+底部 math.max(96,…) 避让）
- Widget 测试：`test/features/ai/pages/ai_page_test.dart` 增加发布列表渲染、跟单弹层用例（_MockAdapter 模式）

## 验证

1. `mvn test` 全绿（先停 java → `mvn clean package` → run_in_background 重启 jar）
2. `test_e2e.py` 新增「跟单审核」段：leader 发布(pending) → 广场不可见 → admin 登录审核通过 → 广场可见 → follower 跟单/改比例/停止 → 跟自己被拒
3. `flutter analyze` 零错误 + `flutter test` 全绿
4. dart.exe + flutter_tools.snapshot build web --release → serve_nocache.py 8090（先杀占用进程）
5. 浏览器抽查：广场真实卡片 → 跟单弹层 → 我的跟单出现；admin 后台（5173）跟单审核页通过/驳回
6. API 发布 2 条演示策略并审核通过，保证广场非空
7. 更新项目记忆
