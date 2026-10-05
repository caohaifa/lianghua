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
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_id ON t_user(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_phone ON t_user(phone);

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

-- 订阅订单表
CREATE TABLE IF NOT EXISTS t_plan_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    plan_level      VARCHAR(20)     NOT NULL,
    amount          DECIMAL(10,2)   NOT NULL,
    period          VARCHAR(10)     NOT NULL,
    status          VARCHAR(20)     NOT NULL,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_po_user ON t_plan_order(user_id);

-- 分成结算表
CREATE TABLE IF NOT EXISTS t_profit_settlement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    profit_amount   DECIMAL(12,2)   NOT NULL,
    share_ratio     DECIMAL(5,2)    NOT NULL,
    share_amount    DECIMAL(12,2)   NOT NULL,
    settled_at      DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_ps_user ON t_profit_settlement(user_id);

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

-- 监控配置表(用户自建盯盘/策略监控)
CREATE TABLE IF NOT EXISTS t_monitor (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    strategy    VARCHAR(50)     NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'running',
    signal      VARCHAR(50)     DEFAULT '等待信号',
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_m_user ON t_monitor(user_id);

-- 用户交易模式: sim=模拟盘, live=实盘(需已绑定 API Key + 已签协议)
ALTER TABLE t_user ADD COLUMN IF NOT EXISTS trading_mode VARCHAR(10) DEFAULT 'sim';

-- 订单成交通道: sim / binance(沙盒阶段 binance 走模拟撮合并标注)
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS channel VARCHAR(30) DEFAULT NULL;

-- A股 T+1:可卖份额(旧库补列);加密符号带 '/',存量加密持仓全部可卖,A股持仓维持冻结待次日解冻
ALTER TABLE t_position ADD COLUMN IF NOT EXISTS available_amount DECIMAL(20,8) DEFAULT 0;
UPDATE t_position SET available_amount = amount WHERE symbol LIKE '%/%' AND available_amount = 0;

-- 测试用户: 手机号 13800138000, 密码 123456 (MD5: e10adc3949ba59abbe56e057f20f883e)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser001', '13800138000', 'e10adc3949ba59abbe56e057f20f883e', '量化测试用户', 'R3', 1, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138000');

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
