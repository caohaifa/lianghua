-- AI 量化 APP 数据库初始化脚本
-- 对应设计文档 13.1 数据库拆分

CREATE DATABASE IF NOT EXISTS ai_quant DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ai_quant;

-- ═══════════════════════════════════════════════════════════════
-- 用户域 (user_db)
-- ═══════════════════════════════════════════════════════════════

-- 用户表
CREATE TABLE IF NOT EXISTS t_user (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户唯一ID(UUID)',
    phone           VARCHAR(11)     NOT NULL                COMMENT '手机号',
    password_hash   VARCHAR(64)     NOT NULL                COMMENT 'MD5密码哈希',
    nickname        VARCHAR(50)     DEFAULT NULL            COMMENT '昵称',
    avatar          VARCHAR(255)    DEFAULT NULL            COMMENT '头像URL',
    risk_level      VARCHAR(2)      DEFAULT NULL            COMMENT '风险等级 R1~R5',
    agreement_signed TINYINT(1)     DEFAULT 0                COMMENT '协议签署 0=未签 1=已签',
    device_id       VARCHAR(128)   DEFAULT NULL            COMMENT '设备绑定ID',
    status          TINYINT         DEFAULT 0               COMMENT '状态 0=正常 1=冻结',
    created_at      DATETIME        NOT NULL                COMMENT '创建时间',
    updated_at      DATETIME        NOT NULL                COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_id (user_id),
    UNIQUE KEY uk_phone (phone)
) ENGINE=InnoDB COMMENT='用户表';

-- 用户设备表
CREATE TABLE IF NOT EXISTS t_user_device (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    device_id   VARCHAR(128)    NOT NULL                COMMENT '设备唯一标识',
    device_name VARCHAR(100)   DEFAULT NULL            COMMENT '设备名称',
    last_login  DATETIME        NOT NULL                COMMENT '最后登录时间',
    created_at  DATETIME        NOT NULL                COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id),
    KEY idx_device_id (device_id)
) ENGINE=InnoDB COMMENT='用户设备表';

-- 用户权限表
CREATE TABLE IF NOT EXISTS t_user_permission (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    permission_type VARCHAR(50)     NOT NULL                COMMENT '权限类型: tourist/subscribe/profit_share',
    plan_level      VARCHAR(20)     DEFAULT NULL            COMMENT '订阅等级: basic/advanced/professional',
    expired_at      DATETIME        DEFAULT NULL            COMMENT '到期时间',
    status          TINYINT         DEFAULT 1               COMMENT '状态 0=过期 1=有效',
    created_at      DATETIME        NOT NULL                COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='用户权限表';

-- 风险测评表
CREATE TABLE IF NOT EXISTS t_risk_assessment (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    risk_level      VARCHAR(2)      NOT NULL                COMMENT '风险等级 R1~R5',
    score           INT             NOT NULL                COMMENT '测评得分',
    answers_json    TEXT            DEFAULT NULL            COMMENT '答题明细JSON',
    assessed_at     DATETIME        NOT NULL                COMMENT '测评时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='风险测评表';

-- ═══════════════════════════════════════════════════════════════
-- 交易域 (trade_db)
-- ═══════════════════════════════════════════════════════════════

-- 券商账户表
CREATE TABLE IF NOT EXISTS t_broker_account (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    exchange        VARCHAR(20)     NOT NULL                COMMENT '交易所: okx/binance/htsc',
    api_key         VARCHAR(255)    NOT NULL                COMMENT 'API Key(加密存储)',
    secret_key      VARCHAR(255)    NOT NULL                COMMENT 'Secret Key(加密存储)',
    passphrase      VARCHAR(255)    DEFAULT NULL            COMMENT 'Passphrase(加密存储)',
    permissions     VARCHAR(100)    DEFAULT NULL            COMMENT '权限: trade,read',
    status          TINYINT         DEFAULT 0               COMMENT '状态 0=未验证 1=正常 2=失效',
    created_at      DATETIME        NOT NULL                COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='券商账户表';

-- 委托订单表
CREATE TABLE IF NOT EXISTS t_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    order_id        VARCHAR(64)     NOT NULL                COMMENT '订单号',
    symbol          VARCHAR(30)     NOT NULL                COMMENT '交易对',
    side            VARCHAR(10)     NOT NULL                COMMENT '方向: buy/sell',
    order_type      VARCHAR(10)     NOT NULL                COMMENT '类型: market/limit',
    price           DECIMAL(20,8)   DEFAULT NULL            COMMENT '委托价',
    amount          DECIMAL(20,8)   NOT NULL                COMMENT '委托量',
    filled_amount   DECIMAL(20,8)   DEFAULT 0               COMMENT '已成交',
    status          VARCHAR(20)     NOT NULL                COMMENT '状态: pending/filled/cancelled',
    strategy_name   VARCHAR(50)     DEFAULT NULL            COMMENT '策略名称',
    signal_id       VARCHAR(64)     DEFAULT NULL            COMMENT '触发信号ID',
    created_at      DATETIME        NOT NULL                COMMENT '创建时间',
    updated_at     DATETIME        NOT NULL                COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_id (order_id),
    KEY idx_user_id (user_id),
    KEY idx_symbol (symbol)
) ENGINE=InnoDB COMMENT='委托订单表';

-- 持仓表
CREATE TABLE IF NOT EXISTS t_position (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL                COMMENT '用户ID',
    symbol          VARCHAR(30)     NOT NULL                COMMENT '交易对',
    side            VARCHAR(10)     NOT NULL                COMMENT '方向: long/short',
    amount          DECIMAL(20,8)   NOT NULL                COMMENT '持仓量',
    entry_price     DECIMAL(20,8)   NOT NULL                COMMENT '开仓价',
    current_price   DECIMAL(20,8)   DEFAULT NULL            COMMENT '当前价',
    pnl             DECIMAL(20,8)   DEFAULT 0               COMMENT '盈亏',
    pnl_pct         DECIMAL(10,4)   DEFAULT 0               COMMENT '盈亏比例',
    strategy_name   VARCHAR(50)     DEFAULT NULL            COMMENT '策略名称',
    status          TINYINT         DEFAULT 0               COMMENT '状态 0=持仓 1=已平仓',
    opened_at       DATETIME        NOT NULL                COMMENT '开仓时间',
    closed_at       DATETIME        DEFAULT NULL            COMMENT '平仓时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id),
    KEY idx_symbol (symbol)
) ENGINE=InnoDB COMMENT='持仓表';

-- ═══════════════════════════════════════════════════════════════
-- 计费域 (billing_db)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS t_plan_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    plan_level      VARCHAR(20)     NOT NULL                COMMENT '订阅等级',
    amount          DECIMAL(10,2)   NOT NULL                COMMENT '金额',
    period          VARCHAR(10)     NOT NULL                COMMENT '周期: month/quarter/year',
    status          VARCHAR(20)     NOT NULL                COMMENT '状态: pending/paid/expired',
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='订阅订单表';

CREATE TABLE IF NOT EXISTS t_profit_settlement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    profit_amount   DECIMAL(12,2)   NOT NULL                COMMENT '净盈利金额',
    share_ratio     DECIMAL(5,2)    NOT NULL                COMMENT '分成比例',
    share_amount    DECIMAL(12,2)   NOT NULL                COMMENT '分成金额',
    settled_at      DATETIME        NOT NULL                COMMENT '结算时间',
    PRIMARY KEY (id),
    KEY idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='分成结算表';

-- ═══════════════════════════════════════════════════════════════
-- 初始化默认数据
-- ═══════════════════════════════════════════════════════════════

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
    username        VARCHAR(50)     NOT NULL                COMMENT '登录名',
    password_hash   VARCHAR(64)     NOT NULL                COMMENT 'MD5密码哈希',
    real_name       VARCHAR(50)     DEFAULT NULL            COMMENT '真实姓名',
    role            VARCHAR(20)     NOT NULL DEFAULT 'ops'  COMMENT '角色: super_admin/ops/compliance/finance',
    status          TINYINT         DEFAULT 0               COMMENT '状态 0=正常 1=停用',
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_username (username)
) ENGINE=InnoDB COMMENT='管理员表';

-- 系统公告表
CREATE TABLE IF NOT EXISTS t_announcement (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    title           VARCHAR(200)    NOT NULL                COMMENT '标题',
    content         TEXT            NOT NULL                COMMENT '正文',
    status          TINYINT         DEFAULT 0               COMMENT '0=草稿 1=已发布 2=已下线',
    publisher_id    VARCHAR(50)     DEFAULT NULL            COMMENT '发布人',
    published_at    DATETIME        DEFAULT NULL            COMMENT '发布时间',
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ann_status (status)
) ENGINE=InnoDB COMMENT='系统公告表';

-- 策略表
CREATE TABLE IF NOT EXISTS t_strategy (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    strategy_id     VARCHAR(32)     NOT NULL                COMMENT '策略唯一ID',
    name            VARCHAR(100)    NOT NULL                COMMENT '策略名称',
    description     TEXT            DEFAULT NULL            COMMENT '策略说明',
    exchange        VARCHAR(20)     DEFAULT NULL            COMMENT '交易所',
    symbols         VARCHAR(255)    DEFAULT NULL            COMMENT '适用标的(逗号分隔)',
    status          VARCHAR(20)     DEFAULT 'draft'         COMMENT 'draft/review/gray/online/offline',
    risk_level      VARCHAR(2)      DEFAULT NULL            COMMENT '适用风险等级',
    gray_percent    INT             DEFAULT 0               COMMENT '灰度放量比例 0~100',
    creator         VARCHAR(50)     DEFAULT NULL            COMMENT '创建人',
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_strategy_id (strategy_id)
) ENGINE=InnoDB COMMENT='策略表';

-- 审计日志表
CREATE TABLE IF NOT EXISTS t_audit_log (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    actor_id        VARCHAR(50)     NOT NULL                COMMENT '操作者ID',
    actor_type      TINYINT         DEFAULT 1               COMMENT '0用户 1运营 2系统',
    action          VARCHAR(64)     NOT NULL                COMMENT '操作动作',
    resource        VARCHAR(64)     DEFAULT NULL            COMMENT '操作资源',
    detail_json     TEXT            DEFAULT NULL            COMMENT '操作明细JSON',
    ip              VARCHAR(64)     DEFAULT NULL            COMMENT '操作IP',
    create_time     DATETIME        NOT NULL                COMMENT '操作时间',
    PRIMARY KEY (id),
    KEY idx_actor_time (actor_id, create_time)
) ENGINE=InnoDB COMMENT='审计日志表';

-- 默认管理员: admin / admin123 (MD5: 0192023a7bbd73250516f069df18b500)
INSERT INTO t_admin_user (username, password_hash, real_name, role, status, created_at, updated_at)
SELECT 'admin', '0192023a7bbd73250516f069df18b500', '超级管理员', 'super_admin', 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM t_admin_user WHERE username = 'admin');
