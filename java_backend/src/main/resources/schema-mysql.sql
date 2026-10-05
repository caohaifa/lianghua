-- AI 量化 APP 数据库初始化脚本(MySQL 8.0 生产版)
-- 与 schema-h2.sql 对齐;MySQL 8.0.16+ 支持 CREATE INDEX IF NOT EXISTS(8.0 不支持,改用显式 DROP/CREATE 由 DBA 控制)
-- 注意:MySQL 不支持 CREATE INDEX IF NOT EXISTS,首次建库直接执行;重复执行前请先 DROP 或手工跳过索引段

CREATE DATABASE IF NOT EXISTS ai_quant DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ai_quant;

-- 用户表
CREATE TABLE IF NOT EXISTS t_user (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    phone           VARCHAR(11)     NOT NULL,
    password_hash   VARCHAR(64)     NOT NULL COMMENT 'BCrypt(60字符),存量MD5登录后自动升级',
    nickname        VARCHAR(50)     DEFAULT NULL,
    avatar          VARCHAR(255)    DEFAULT NULL,
    risk_level      VARCHAR(2)      DEFAULT NULL,
    agreement_signed TINYINT(1)     DEFAULT 0,
    device_id       VARCHAR(128)    DEFAULT NULL,
    trading_mode    VARCHAR(10)     DEFAULT 'sim' COMMENT 'sim=模拟盘, live=实盘',
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_id (user_id),
    UNIQUE KEY uk_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户设备表
CREATE TABLE IF NOT EXISTS t_user_device (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    device_id   VARCHAR(128)    NOT NULL,
    device_name VARCHAR(100)    DEFAULT NULL,
    last_login  DATETIME        NOT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ud_user (user_id),
    KEY idx_ud_device (device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户权限表
CREATE TABLE IF NOT EXISTS t_user_permission (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    permission_type VARCHAR(50)     NOT NULL,
    plan_level      VARCHAR(20)     DEFAULT NULL,
    expired_at      DATETIME        DEFAULT NULL,
    status          TINYINT         DEFAULT 1,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_up_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 风险测评表
CREATE TABLE IF NOT EXISTS t_risk_assessment (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    risk_level      VARCHAR(2)      NOT NULL,
    score           INT             NOT NULL,
    answers_json    TEXT            DEFAULT NULL,
    assessed_at     DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ra_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 券商账户表
CREATE TABLE IF NOT EXISTS t_broker_account (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    exchange        VARCHAR(20)     NOT NULL,
    api_key         VARCHAR(255)    NOT NULL,
    secret_key      VARCHAR(255)    NOT NULL COMMENT 'AES/CBC+随机IV 密文',
    passphrase      VARCHAR(255)    DEFAULT NULL,
    permissions     VARCHAR(100)    DEFAULT NULL,
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ba_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    channel         VARCHAR(30)     DEFAULT NULL COMMENT 'sim / binance',
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_id (order_id),
    KEY idx_o_user (user_id),
    KEY idx_o_symbol (symbol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 持仓表
CREATE TABLE IF NOT EXISTS t_position (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    side            VARCHAR(10)     NOT NULL,
    amount          DECIMAL(20,8)   NOT NULL,
    entry_price     DECIMAL(20,8)   NOT NULL,
    current_price   DECIMAL(20,8)   DEFAULT NULL,
    pnl             DECIMAL(20,8)   DEFAULT 0,
    pnl_pct         DECIMAL(10,4)   DEFAULT 0,
    strategy_name   VARCHAR(50)     DEFAULT NULL,
    status          TINYINT         DEFAULT 0,
    opened_at       DATETIME        NOT NULL,
    closed_at       DATETIME        DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_p_user (user_id),
    KEY idx_p_symbol (symbol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 订阅订单表
CREATE TABLE IF NOT EXISTS t_plan_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    plan_level      VARCHAR(20)     NOT NULL,
    amount          DECIMAL(10,2)   NOT NULL,
    period          VARCHAR(10)     NOT NULL,
    status          VARCHAR(20)     NOT NULL COMMENT 'pending/paid/refunded',
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_po_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 分成结算表
CREATE TABLE IF NOT EXISTS t_profit_settlement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    profit_amount   DECIMAL(12,2)   NOT NULL,
    share_ratio     DECIMAL(5,2)    NOT NULL,
    share_amount    DECIMAL(12,2)   NOT NULL,
    settled_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ps_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 模拟账户表(首次访问懒初始化 10 万 USDT 模拟金)
CREATE TABLE IF NOT EXISTS t_account (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    currency    VARCHAR(10)     NOT NULL DEFAULT 'USDT',
    balance     DECIMAL(20,8)   NOT NULL DEFAULT 100000,
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_acc_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    PRIMARY KEY (id),
    KEY idx_m_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 测试用户: 手机号 13800138000, 密码 123456 (MD5, 首次登录自动升级 BCrypt)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser001', '13800138000', 'e10adc3949ba59abbe56e057f20f883e', '量化测试用户', 'R3', 1, 0, NOW(), NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138000');

-- ═══════════════════════════════════════════════════════════════
-- 运营后台域 (admin)
-- ═══════════════════════════════════════════════════════════════

-- 管理员表 (RBAC: super_admin/ops/compliance/finance)
CREATE TABLE IF NOT EXISTS t_admin_user (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    username        VARCHAR(50)     NOT NULL,
    password_hash   VARCHAR(64)     NOT NULL COMMENT 'BCrypt(60字符),存量MD5登录后自动升级',
    real_name       VARCHAR(50)     DEFAULT NULL,
    role            VARCHAR(20)     NOT NULL DEFAULT 'ops',
    status          TINYINT         DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY idx_admin_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 系统公告表
CREATE TABLE IF NOT EXISTS t_announcement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    title           VARCHAR(200)    NOT NULL,
    content         TEXT            NOT NULL,
    status          TINYINT         DEFAULT 0,
    publisher_id    VARCHAR(50)     DEFAULT NULL,
    published_at    DATETIME        DEFAULT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ann_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 策略表 (策略上下架/灰度)
CREATE TABLE IF NOT EXISTS t_strategy (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    strategy_id     VARCHAR(32)     NOT NULL,
    name            VARCHAR(100)    NOT NULL,
    description     TEXT            DEFAULT NULL,
    exchange        VARCHAR(20)     DEFAULT NULL,
    symbols         VARCHAR(255)    DEFAULT NULL,
    status          VARCHAR(20)     DEFAULT 'draft',
    risk_level      VARCHAR(2)      DEFAULT NULL,
    gray_percent    INT             DEFAULT 0,
    creator         VARCHAR(50)     DEFAULT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY idx_strategy_id (strategy_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 审计日志表 (后台操作留痕,保留≥5年)
CREATE TABLE IF NOT EXISTS t_audit_log (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    actor_id        VARCHAR(50)     NOT NULL,
    actor_type      TINYINT         DEFAULT 1,
    action          VARCHAR(64)     NOT NULL,
    resource        VARCHAR(64)     DEFAULT NULL,
    detail_json     TEXT            DEFAULT NULL,
    ip              VARCHAR(64)     DEFAULT NULL,
    create_time     DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_audit_actor_time (actor_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 默认管理员: admin / admin123 (MD5, 首次登录自动升级 BCrypt;生产环境请立即改密)
INSERT INTO t_admin_user (username, password_hash, real_name, role, status, created_at, updated_at)
SELECT 'admin', '0192023a7bbd73250516f069df18b500', '超级管理员', 'super_admin', 0, NOW(), NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM t_admin_user WHERE username = 'admin');
