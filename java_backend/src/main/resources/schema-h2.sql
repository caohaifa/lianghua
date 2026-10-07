-- AI 量化 APP 数据库初始化脚本(H2 MySQL 模式)
-- 去掉 ENGINE/COMMENT/索引 COMMENT 等 MySQL 专有语法,兼容 H2

-- 用户表
CREATE TABLE IF NOT EXISTS t_user (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    phone           VARCHAR(11)     NOT NULL,
    password_hash   VARCHAR(64)     NOT NULL,
    nickname        VARCHAR(50)     DEFAULT NULL,
    avatar          VARCHAR(255)    DEFAULT NULL,
    risk_level      VARCHAR(2)      DEFAULT NULL,
    agreement_signed TINYINT(1)     DEFAULT 0,
    device_id       VARCHAR(128)    DEFAULT NULL,
    invited_by      VARCHAR(32)     DEFAULT NULL COMMENT '邀请人 user_id',
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_id ON t_user(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_phone ON t_user(phone);
ALTER TABLE t_user ADD COLUMN IF NOT EXISTS invited_by VARCHAR(32) DEFAULT NULL;

-- 用户设备表
CREATE TABLE IF NOT EXISTS t_user_device (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    device_id   VARCHAR(128)    NOT NULL,
    device_name VARCHAR(100)    DEFAULT NULL,
    last_login  DATETIME        NOT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ud_user ON t_user_device(user_id);
CREATE INDEX IF NOT EXISTS idx_ud_device ON t_user_device(device_id);

-- 用户权限表
CREATE TABLE IF NOT EXISTS t_user_permission (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    permission_type VARCHAR(50)     NOT NULL,
    plan_level      VARCHAR(20)     DEFAULT NULL,
    expired_at      DATETIME        DEFAULT NULL,
    status          TINYINT         DEFAULT 1,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_up_user ON t_user_permission(user_id);

-- 风险测评表
CREATE TABLE IF NOT EXISTS t_risk_assessment (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    risk_level      VARCHAR(2)      NOT NULL,
    score           INT             NOT NULL,
    answers_json    TEXT            DEFAULT NULL,
    assessed_at     DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ra_user ON t_risk_assessment(user_id);

-- 协议签署存证表
CREATE TABLE IF NOT EXISTS t_agreement_signature (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    agreements      VARCHAR(255)    NOT NULL COMMENT '已签协议ID列表,逗号分隔',
    signature_img   TEXT            DEFAULT NULL COMMENT '手写签名 PNG Base64',
    seal_time       VARCHAR(40)     NOT NULL COMMENT '存证时间戳(ISO)',
    ip              VARCHAR(45)     DEFAULT NULL COMMENT '签署时 IP(存证)',
    user_agent      VARCHAR(255)    DEFAULT NULL COMMENT '签署时 User-Agent(存证)',
    content_hash    VARCHAR(64)     DEFAULT NULL COMMENT 'SHA-256(userId|agreements|signature|sealTime|ip) 完整性校验',
    signed_at       DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_as_user ON t_agreement_signature(user_id);

-- 券商账户表
CREATE TABLE IF NOT EXISTS t_broker_account (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    exchange        VARCHAR(20)     NOT NULL,
    api_key         VARCHAR(255)    NOT NULL,
    secret_key      VARCHAR(255)    NOT NULL,
    passphrase      VARCHAR(255)    DEFAULT NULL,
    permissions     VARCHAR(100)    DEFAULT NULL,
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ba_user ON t_broker_account(user_id);

-- 委托订单表
CREATE TABLE IF NOT EXISTS t_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    order_id        VARCHAR(64)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    side            VARCHAR(10)     NOT NULL,
    order_type      VARCHAR(10)     NOT NULL,
    price           DECIMAL(20,8)   DEFAULT NULL,
    amount          DECIMAL(20,8)   NOT NULL,
    filled_amount   DECIMAL(20,8)   DEFAULT 0,
    status          VARCHAR(20)     NOT NULL,
    fail_reason     VARCHAR(255)    DEFAULT NULL COMMENT 'rejected/unknown 时的失败或对账说明',
    strategy_name   VARCHAR(50)     DEFAULT NULL,
    signal_id       VARCHAR(64)     DEFAULT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_order_id ON t_order(order_id);
CREATE INDEX IF NOT EXISTS idx_o_user ON t_order(user_id);
CREATE INDEX IF NOT EXISTS idx_o_symbol ON t_order(symbol);

-- 持仓表
CREATE TABLE IF NOT EXISTS t_position (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    side            VARCHAR(10)     NOT NULL,
    amount          DECIMAL(20,8)   NOT NULL,
    available_amount DECIMAL(20,8)  DEFAULT 0,  -- T+1 可卖份额:加密=amount;A股当日买入=0,次日解冻
    entry_price     DECIMAL(20,8)   NOT NULL,
    current_price   DECIMAL(20,8)   DEFAULT NULL,
    pnl             DECIMAL(20,8)   DEFAULT 0,
    pnl_pct         DECIMAL(10,4)   DEFAULT 0,
    strategy_name   VARCHAR(50)     DEFAULT NULL,
    status          TINYINT         DEFAULT 0,
    opened_at       DATETIME        NOT NULL,
    closed_at       DATETIME        DEFAULT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_p_user ON t_position(user_id);
CREATE INDEX IF NOT EXISTS idx_p_symbol ON t_position(symbol);

-- 模拟账户表(懒初始化双币种:USDT 10 万 + CNY 100 万模拟金)
CREATE TABLE IF NOT EXISTS t_account (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    currency    VARCHAR(10)     NOT NULL DEFAULT 'USDT',
    balance     DECIMAL(20,8)   NOT NULL DEFAULT 100000,
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
-- 旧库单列唯一索引 uk_acc_user 会阻止同一用户再建 CNY 账户,先删除再升级为 (user_id,currency) 复合唯一
DROP INDEX IF EXISTS uk_acc_user;
CREATE UNIQUE INDEX IF NOT EXISTS uk_acc_user_currency ON t_account(user_id, currency);

-- 钱包流水(充值/提现记录,模拟环境)
CREATE TABLE IF NOT EXISTS t_wallet_transaction (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    currency    VARCHAR(10)     NOT NULL DEFAULT 'USDT',
    type        VARCHAR(20)     NOT NULL,              -- deposit / withdraw
    amount      DECIMAL(20,8)   NOT NULL,
    channel     VARCHAR(30),                          -- 充值渠道/提现网络
    address     VARCHAR(128),                         -- 提现地址
    status      VARCHAR(20)     NOT NULL DEFAULT 'completed',
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_wt_user ON t_wallet_transaction(user_id, currency);

-- 监控配置表(用户自建盯盘/策略监控)
CREATE TABLE IF NOT EXISTS t_monitor (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    strategy    VARCHAR(50)     NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'running',
    signal      VARCHAR(50)     DEFAULT '等待信号',
    source      VARCHAR(10)     NOT NULL DEFAULT 'user',  -- user=用户监控 bot=量化机器人
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_m_user ON t_monitor(user_id);
ALTER TABLE t_monitor ADD COLUMN IF NOT EXISTS source VARCHAR(10) NOT NULL DEFAULT 'user';
ALTER TABLE t_monitor ADD COLUMN IF NOT EXISTS params TEXT;

-- 信号历史流水:AI/机器人每轮信号追加一条,供后台绩效时间线(区别于 t_monitor.signal 仅存最新)
CREATE TABLE IF NOT EXISTS t_signal_log (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id  BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,
    action      VARCHAR(20)     DEFAULT '',
    signal      VARCHAR(100)    NOT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_sl_monitor ON t_signal_log(monitor_id, id);

-- 高频查询索引(原误置于 MonitorExecutionService.java,现归位;均为幂等 CREATE INDEX IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_order_status    ON t_order(status);
CREATE INDEX IF NOT EXISTS idx_order_user       ON t_order(user_id, id);
CREATE INDEX IF NOT EXISTS idx_pos_user_status  ON t_position(user_id, status);
CREATE INDEX IF NOT EXISTS idx_fpos_status      ON t_futures_position(status);

-- ═══════════════ 跟单系统(策略发布 + 跟单关系) ═══════════════
-- 策略发布表:会员把自己的监控申请发布,后台审核通过(published)才在广场展示
CREATE TABLE IF NOT EXISTS t_strategy_publish (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    leader_id   VARCHAR(32)     NOT NULL,
    monitor_id  BIGINT          NOT NULL,
    title       VARCHAR(50)     NOT NULL,
    description VARCHAR(200)    DEFAULT '',
    strategy    VARCHAR(50)     NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'pending',  -- pending/published/rejected/offline
    is_bot      TINYINT(1)      NOT NULL DEFAULT 0,  -- 1=系统量化机器人发布
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_sp_leader ON t_strategy_publish(leader_id);
CREATE INDEX IF NOT EXISTS idx_sp_monitor ON t_strategy_publish(monitor_id);
CREATE INDEX IF NOT EXISTS idx_sp_status ON t_strategy_publish(status);
ALTER TABLE t_strategy_publish ADD COLUMN IF NOT EXISTS is_bot TINYINT(1) NOT NULL DEFAULT 0;

-- 跟单关系表:follower 按比例跟随 leader 某条监控的交易
CREATE TABLE IF NOT EXISTS t_strategy_follow (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,   -- follower
    publish_id  BIGINT          NOT NULL,
    leader_id   VARCHAR(32)     NOT NULL,
    monitor_id  BIGINT          NOT NULL,
    ratio       INT             NOT NULL DEFAULT 10,  -- 跟单比例 %(10/25/50/100)
    status      VARCHAR(20)     NOT NULL DEFAULT 'active',  -- active/stopped
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_sf_user ON t_strategy_follow(user_id);
CREATE INDEX IF NOT EXISTS idx_sf_monitor ON t_strategy_follow(monitor_id);
CREATE INDEX IF NOT EXISTS idx_sf_publish ON t_strategy_follow(publish_id);
-- 跟单模式:ratio=固定比例 balance=本金比例 fixed=固定倍数;固定倍数的倍数值
ALTER TABLE t_strategy_follow ADD COLUMN IF NOT EXISTS mode VARCHAR(10) DEFAULT 'ratio';
ALTER TABLE t_strategy_follow ADD COLUMN IF NOT EXISTS fixed_multiplier DECIMAL(20,4) DEFAULT 1;

-- 跟单复制流水表:每次复制成交记一行,卖出行记已实现盈亏 pnl
CREATE TABLE IF NOT EXISTS t_copy_trade (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    follow_id   BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,   -- follower
    publish_id  BIGINT          NOT NULL,
    monitor_id  BIGINT          NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    side        VARCHAR(10)     NOT NULL,   -- buy/sell
    amount      DECIMAL(20,8)   NOT NULL,
    price       DECIMAL(20,8)   NOT NULL,
    pnl         DECIMAL(20,8)   DEFAULT NULL,  -- 仅 sell 行有值
    order_id    VARCHAR(64)     DEFAULT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ct_user ON t_copy_trade(user_id);
CREATE INDEX IF NOT EXISTS idx_ct_follow ON t_copy_trade(follow_id);

-- ═══════════════ 个人策略(人工配置、人工触发信号) ═══════════════
-- 信号流水:主交易员在信号台人工下发,机器人按跟单模式分发执行
CREATE TABLE IF NOT EXISTS t_personal_signal (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id  BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,
    action      VARCHAR(20)     NOT NULL,  -- open_long/add_long/partial_close/close_all/open_short
    amount      DECIMAL(20,8)   DEFAULT NULL,   -- 数量(开仓/加仓/平空量)
    ratio_pct   INT             DEFAULT NULL,   -- 部分平仓百分比 1-99
    leverage    INT             DEFAULT 5,      -- 开空杠杆
    ok_count    INT             DEFAULT 0,      -- follower 执行成功数
    skip_count  INT             DEFAULT 0,      -- 跳过/失败数
    detail      VARCHAR(500)    DEFAULT '',     -- 分发明细摘要
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ps_monitor ON t_personal_signal(monitor_id);

-- 站内告警:跟单跳过/风控事件/系统消息
CREATE TABLE IF NOT EXISTS t_alert (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    type        VARCHAR(20)     NOT NULL,  -- copy_skip/risk/system
    title       VARCHAR(100)    NOT NULL,
    content     VARCHAR(300)    DEFAULT '',
    read_flag   TINYINT         DEFAULT 0,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_alert_user ON t_alert(user_id);

-- 系统配置(全局风控开关等)
CREATE TABLE IF NOT EXISTS t_system_config (
    config_key   VARCHAR(50)    NOT NULL,
    config_value VARCHAR(100)   DEFAULT '',
    updated_at   DATETIME       NOT NULL,
    PRIMARY KEY (config_key)
);

-- ═══════════════ 开源策略量化机器人(自动带单) ═══════════════
-- 机器人注册表:一个机器人 = 一个系统用户 + 一条 bot 监控 + 一条自动通过的发布
CREATE TABLE IF NOT EXISTS t_quant_bot (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    bot_user_id     VARCHAR(32)     NOT NULL,
    monitor_id      BIGINT          NOT NULL,
    strategy_key    VARCHAR(30)     NOT NULL,  -- ema_cross/rsi_rev/grid/boll_break
    symbol          VARCHAR(30)     NOT NULL,
    config_json     VARCHAR(500)    DEFAULT '{}',
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_qb_monitor ON t_quant_bot(monitor_id);

-- 网格机器人档位状态:价格触及触发价 → 买/卖,成交后生成对手档
CREATE TABLE IF NOT EXISTS t_bot_grid_level (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id      BIGINT          NOT NULL,
    grid_idx        INT             NOT NULL,  -- 档位序号(同级买卖档复用)
    trigger_price   DECIMAL(20,8)   NOT NULL,
    side            VARCHAR(10)     NOT NULL,  -- buy/sell
    amount          DECIMAL(20,8)   DEFAULT 0,
    status          VARCHAR(10)     NOT NULL,  -- open/filled/closed
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_bgl_monitor ON t_bot_grid_level(monitor_id);

-- ═══════════════ 合约交易域(USDT 本位永续合约模拟) ═══════════════
-- 合约账户(每用户一个,懒初始化 1 万 USDT 模拟金;钱包余额含占用保证金)
CREATE TABLE IF NOT EXISTS t_futures_account (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    wallet_balance  DECIMAL(20,8)   NOT NULL DEFAULT 10000,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_fa_user ON t_futures_account(user_id);

-- 合约持仓(单向模式:同标的只允许同向持仓,反向需先平仓)
CREATE TABLE IF NOT EXISTS t_futures_position (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    direction       VARCHAR(10)     NOT NULL,   -- long/short
    amount          DECIMAL(20,8)   NOT NULL,
    entry_price     DECIMAL(20,8)   NOT NULL,
    leverage        INT             NOT NULL DEFAULT 10,
    margin          DECIMAL(20,8)   NOT NULL,   -- 占用保证金(开仓保证金累加)
    status          TINYINT         DEFAULT 0,  -- 0持仓中 1已平仓
    opened_at       DATETIME        NOT NULL,
    closed_at       DATETIME        DEFAULT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_fp_user ON t_futures_position(user_id);

-- 合约成交记录(市价开/平仓流水)
CREATE TABLE IF NOT EXISTS t_futures_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    order_id        VARCHAR(40)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    direction       VARCHAR(10)     NOT NULL,
    action          VARCHAR(10)     NOT NULL,   -- open/close
    amount          DECIMAL(20,8)   NOT NULL,
    price           DECIMAL(20,8)   NOT NULL,
    leverage        INT             NOT NULL DEFAULT 0,
    margin          DECIMAL(20,8)   NOT NULL DEFAULT 0,
    fee             DECIMAL(20,8)   NOT NULL DEFAULT 0,
    pnl             DECIMAL(20,8)   NOT NULL DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_fo_id ON t_futures_order(order_id);
CREATE INDEX IF NOT EXISTS idx_fo_user ON t_futures_order(user_id);

-- 用户交易模式: sim=模拟盘, live=实盘(需已绑定 API Key + 已签协议)
ALTER TABLE t_user ADD COLUMN IF NOT EXISTS trading_mode VARCHAR(10) DEFAULT 'sim';

-- 订单成交通道: sim / binance(沙盒阶段 binance 走模拟撮合并标注)
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS channel VARCHAR(30) DEFAULT NULL;

-- 订单异常状态原因(rejected/unknown);旧库补列
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS fail_reason VARCHAR(255) DEFAULT NULL;

-- 协议签署存证增强:签署环境 + 内容哈希(旧库补列)
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS ip VARCHAR(45) DEFAULT NULL;
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS user_agent VARCHAR(255) DEFAULT NULL;
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64) DEFAULT NULL;

-- A股 T+1:可卖份额(旧库补列);加密符号带 '/',存量加密持仓全部可卖,A股持仓维持冻结待次日解冻
ALTER TABLE t_position ADD COLUMN IF NOT EXISTS available_amount DECIMAL(20,8) DEFAULT 0;
UPDATE t_position SET available_amount = amount WHERE symbol LIKE '%/%' AND available_amount = 0;

-- 测试用户: 手机号 13800138000, 密码 123456 (MD5: e10adc3949ba59abbe56e057f20f883e)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser001', '13800138000', 'e10adc3949ba59abbe56e057f20f883e', '量化测试用户', 'R3', 1, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138000');

-- 测试账号 B: 手机号 13800138001, 密码 123456 (多用户场景: 跟单/邀请/团队)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser002', '13800138001', 'e10adc3949ba59abbe56e057f20f883e', '测试账号B', 'R3', 1, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138001');

-- 测试账号 C: 手机号 13800138002, 密码 123456
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser003', '13800138002', 'e10adc3949ba59abbe56e057f20f883e', '测试账号C', 'R3', 1, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138002');

-- ═══════════════════════════════════════════════════════════════
-- 运营后台域 (admin)
-- ═══════════════════════════════════════════════════════════════

-- 管理员表 (RBAC: super_admin/ops/compliance/finance)
CREATE TABLE IF NOT EXISTS t_admin_user (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    username        VARCHAR(50)     NOT NULL,
    password_hash   VARCHAR(64)     NOT NULL,
    real_name       VARCHAR(50)     DEFAULT NULL,
    role            VARCHAR(20)     NOT NULL DEFAULT 'ops',
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_username ON t_admin_user(username);

-- 系统公告表
CREATE TABLE IF NOT EXISTS t_announcement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    title           VARCHAR(200)    NOT NULL,
    content         CLOB            NOT NULL,
    status          TINYINT         DEFAULT 0,
    publisher_id    VARCHAR(50)     DEFAULT NULL,
    published_at    DATETIME        DEFAULT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ann_status ON t_announcement(status);

-- 策略表 (策略上下架/灰度)
CREATE TABLE IF NOT EXISTS t_strategy (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    strategy_id     VARCHAR(32)     NOT NULL,
    name            VARCHAR(100)    NOT NULL,
    description     CLOB            DEFAULT NULL,
    exchange        VARCHAR(20)     DEFAULT NULL,
    symbols         VARCHAR(255)    DEFAULT NULL,
    status          VARCHAR(20)     DEFAULT 'draft',
    risk_level      VARCHAR(2)      DEFAULT NULL,
    gray_percent    INT             DEFAULT 0,
    creator         VARCHAR(50)     DEFAULT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_strategy_id ON t_strategy(strategy_id);

-- 审计日志表 (后台操作留痕,保留≥5年)
CREATE TABLE IF NOT EXISTS t_audit_log (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    actor_id        VARCHAR(50)     NOT NULL,
    actor_type      TINYINT         DEFAULT 1,
    action          VARCHAR(64)     NOT NULL,
    resource        VARCHAR(64)     DEFAULT NULL,
    detail_json     CLOB            DEFAULT NULL,
    ip              VARCHAR(64)     DEFAULT NULL,
    create_time     DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_audit_actor_time ON t_audit_log(actor_id, create_time);

-- 默认管理员: admin / admin123 (MD5: 0192023a7bbd73250516f069df18b500)
INSERT INTO t_admin_user (username, password_hash, real_name, role, status, created_at, updated_at)
SELECT 'admin', '0192023a7bbd73250516f069df18b500', '超级管理员', 'super_admin', 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_admin_user WHERE username = 'admin');

-- 邀请奖励表(推荐人获被推荐人交易流水 1% 返佣)
CREATE TABLE IF NOT EXISTS t_referral_reward (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    referrer_id VARCHAR(50)  NOT NULL,
    trader_id   VARCHAR(50)  NOT NULL,
    order_id    VARCHAR(64)  NOT NULL,
    symbol      VARCHAR(32)  NOT NULL,
    currency    VARCHAR(8)   NOT NULL,
    volume      DOUBLE       NOT NULL,
    reward      DOUBLE       NOT NULL,
    created_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_referral_reward_referrer ON t_referral_reward(referrer_id, id);

-- ═══════════════════════════════════════════════════════════════
-- 内容管理域
-- ═══════════════════════════════════════════════════════════════

-- 轮播图/Banner
CREATE TABLE IF NOT EXISTS t_banner (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    title       VARCHAR(100) NOT NULL,
    image_url   VARCHAR(500) NOT NULL,
    link_type   VARCHAR(20)  DEFAULT 'none',
    link_url    VARCHAR(500) DEFAULT NULL,
    position    INT          DEFAULT 0,
    status      TINYINT      DEFAULT 1,
    start_time  DATETIME     DEFAULT NULL,
    end_time    DATETIME     DEFAULT NULL,
    creator     VARCHAR(50)  DEFAULT NULL,
    created_at  DATETIME     NOT NULL,
    updated_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_banner_status_pos ON t_banner(status, position);

-- FAQ/帮助中心
CREATE TABLE IF NOT EXISTS t_faq (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    category    VARCHAR(30)  NOT NULL,
    question    VARCHAR(200) NOT NULL,
    answer      CLOB         NOT NULL,
    sort_order  INT          DEFAULT 0,
    status      TINYINT      DEFAULT 1,
    creator     VARCHAR(50)  DEFAULT NULL,
    created_at  DATETIME     NOT NULL,
    updated_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_faq_category ON t_faq(category, status);

-- 推送通知
CREATE TABLE IF NOT EXISTS t_push_notification (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    title           VARCHAR(100) NOT NULL,
    content         VARCHAR(500) NOT NULL,
    target_type     VARCHAR(20)  DEFAULT 'all',
    target_value    VARCHAR(500) DEFAULT NULL,
    status          TINYINT      DEFAULT 0,
    scheduled_at    DATETIME     DEFAULT NULL,
    sent_at         DATETIME     DEFAULT NULL,
    sent_count      INT          DEFAULT 0,
    creator         VARCHAR(50)  DEFAULT NULL,
    created_at      DATETIME     NOT NULL,
    updated_at      DATETIME     NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_push_status ON t_push_notification(status);

-- 公告表增强:分类+置顶
ALTER TABLE t_announcement ADD COLUMN IF NOT EXISTS category VARCHAR(30) DEFAULT 'general';
ALTER TABLE t_announcement ADD COLUMN IF NOT EXISTS pinned TINYINT DEFAULT 0;
