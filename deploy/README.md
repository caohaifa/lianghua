# AI 量化平台 · 生产部署指南

> 对应《上线前检查清单》C 类(配置与环境)、F 类(数据与迁移)交付物。
> 生产配置基线:`java_backend/src/main/resources/application-prod.yml`(敏感项全部环境变量注入,缺失即启动失败)。

## 一、四端组件与进程守护

| 组件 | 产物/入口 | 端口 | 守护方式 |
|------|-----------|------|----------|
| Java 后端 | `ai-quant-backend-1.0.0.jar`(prod profile) | 8080 | `deploy/systemd/ai-quant-backend.service` |
| Python AI | `python_ai`(FastAPI,uvicorn) | 8000 | `deploy/systemd/ai-quant-ai.service` |
| Flutter Web | `flutter_app/build/web` | 80/443 | Nginx 静态托管(`deploy/nginx.conf`) |
| Admin Web | `admin_web/dist`(npm run build) | 80/443 | Nginx 静态托管(同上) |
| MySQL 8.0 | `docker-compose.yml` 或云 RDS | 3306 | systemd / 云托管 |
| Redis 7 | `docker-compose.yml` 或云 Redis | 6379 | systemd / 云托管 |

> 禁止再用开发态 `Start-Process` 拉起进程;systemd 单元已带异常自动拉起(Restart=always)。

## 二、上线部署步骤(概要)

1. **数据库**:按 `schema-mysql.sql` 建库(见下文"三、H2→MySQL 迁移");配置每日备份(cron 跑 `deploy/mysql-backup.sh`)。
2. **中间件**:MySQL/Redis 就绪,生产密码与内网隔离。
3. **后端**:
   ```bash
   mvn -q package -DskipTests
   # /opt/ai-quant/backend/backend.env 至少注入:
   # JWT_SECRET / API_KEY_SECRET / MYSQL_HOST MYSQL_USERNAME MYSQL_PASSWORD /
   # REDIS_HOST REDIS_PASSWORD / CORS_ALLOWED_ORIGINS / BINANCE_LIVE_ENABLED=false
   systemctl enable --now ai-quant-backend
   # 探活: curl http://127.0.0.1:8080/api/v1/auth/health
   ```
4. **AI 服务**:`systemctl enable --now ai-quant-ai`;后端以 `AI_SERVICE_URL` 指向它。
5. **前端**:
   - Flutter:在 `flutter_app/` 执行 `.\build_release.ps1 -ApiBaseUrl "https://api.example.com/api/v1"`,上传 `build/web` 到 `/opt/ai-quant/flutter-web`;
   - Admin:`cd admin_web && npm run build`,上传 `dist` 到 `/opt/ai-quant/admin-web`;
   - Nginx 装载 `deploy/nginx.conf`(域名/证书替换后 reload)。
6. **监控**:
   - Prometheus 抓取 `http://backend:8080/api/v1/actuator/prometheus`(下单成功率 `aiquant_orders_total`、WS 在线 `aiquant_ws_online`、接口 P99 `http_server_requests_seconds`);
   - 健康检查 `GET /api/v1/auth/health`。
7. **回滚**:保留上一版 jar 与前端产物目录,`systemctl restart` + Nginx root 切软链,5 分钟内可回切。

## 三、H2 → MySQL 数据迁移(F 类)

**方案 A(推荐,测试期数据可弃)**:清库重新 seed
- 生产库直接执行 `schema-mysql.sql`(建库 + 全部表 + 测试账号/管理员 seed);
- 用户重新注册;测试账号 `13800138000/123456` 与 `admin/admin123` 自动可用(上线后立即改密)。

**方案 B(需保留 H2 数据)**:CSV 导出导入
```bash
# 1) 停后端,用 H2 Shell 导出每张表为 CSV(java -cp h2.jar org.h2.tools.Shell)
#    SELECT * FROM t_user INTO CSV 't_user.csv';
# 2) 生产库先执行 schema-mysql.sql 建表
# 3) LOAD DATA 导入(MySQL 侧逐表执行)
LOAD DATA LOCAL INFILE 't_user.csv' INTO TABLE t_user
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;
# 4) 完整性抽查:select count(*) 对比;交易/持仓表逐表核对金额合计
```
- 注意:两张库的 `t_order.status` 状态集已扩展(pending/filled/cancelled/rejected/partial_filled/expired/unknown),旧数据只有前三个值,天然兼容。

## 四、环境变量清单(prod profile)

| 变量 | 必须 | 说明 |
|------|------|------|
| `JWT_SECRET` | 是 | JWT 签名密钥(无默认值,缺失拒启) |
| `API_KEY_SECRET` | 是 | 用户交易所 Key 的 AES 密钥(同上) |
| `MYSQL_HOST/USERNAME/PASSWORD` | 是 | MySQL 连接 |
| `REDIS_HOST/PASSWORD` | 是 | 独立 Redis |
| `CORS_ALLOWED_ORIGINS` | 是 | 域名白名单,逗号分隔 |
| `INVITE_CODE` | 否 | 留空=注册不强制邀请码 |
| `TRADING_ALLOWED_MARKETS` | 否 | 交易市场白名单,默认 `crypto`(A 股待产品确认) |
| `BINANCE_LIVE_ENABLED` | 否 | 默认 false;testnet 联调通过后才置 true |
| `AI_SERVICE_URL` | 否 | 默认 http://localhost:8000 |
| `AI_AUTO_TRADE_ENABLED` | 否 | 默认 false(prod;AI 信号自动下单开关) |
| `SMS_MOCK_RETURN_CODE` | 否 | prod 固定 false;真实短信网关接入为上线前置 |
| `PAYMENT_MOCK_ENABLED` | 否 | prod 固定 false;支付网关接入为上线前置 |

## 五、与检查清单的对应

- C-33 生产配置 → `application-prod.yml`(本仓库)
- C-34/35 前端地址注入 → `flutter_app/build_release.ps1` + `--dart-define=API_BASE_URL`;AI 地址走后端代理(`AI_SERVICE_URL`)
- C-36/37 静态托管 + WS 反代 → `deploy/nginx.conf`
- C-38 进程守护 → `deploy/systemd/*.service`
- F-72 H2→MySQL → 本文件第三节
- F-73 备份策略 → `deploy/mysql-backup.sh`
