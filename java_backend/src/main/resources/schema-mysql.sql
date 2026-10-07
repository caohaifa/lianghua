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
    device_id       VARCHAR(128)     DEFAULT NULL,
    trading_mode    VARCHAR(10)     DEFAULT 'sim' COMMENT 'sim=模拟盘, live=实盘',
    invited_by      VARCHAR(32)     DEFAULT NULL COMMENT '邀请人 user_id',
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
    PRIMARY KEY (id),
    KEY idx_as_user (user_id)
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
    status          VARCHAR(20)     NOT NULL COMMENT 'pending/filled/cancelled/rejected/partial_filled/expired/unknown',
    fail_reason     VARCHAR(255)    DEFAULT NULL COMMENT 'rejected/unknown 时的失败或对账说明',
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
    available_amount DECIMAL(20,8)  DEFAULT 0 COMMENT 'T+1 可卖份额:加密=amount;A股当日买入=0,次日解冻',
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

-- 钱包流水(充值/提现记录,模拟环境)
CREATE TABLE IF NOT EXISTS t_wallet_transaction (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    currency    VARCHAR(10)     NOT NULL DEFAULT 'USDT',
    type        VARCHAR(20)     NOT NULL,
    amount      DECIMAL(20,8)   NOT NULL,
    channel     VARCHAR(30),
    address     VARCHAR(128),
    status      VARCHAR(20)     NOT NULL DEFAULT 'completed',
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_wt_user (user_id, currency)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 监控配置表(用户自建盯盘/策略监控)
CREATE TABLE IF NOT EXISTS t_monitor (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    strategy    VARCHAR(50)     NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'running',
    signal      VARCHAR(50)     DEFAULT '等待信号',
    source      VARCHAR(10)     NOT NULL DEFAULT 'user',
    params      TEXT,
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_m_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 信号历史流水:AI/机器人每轮信号追加一条,供后台绩效时间线
CREATE TABLE IF NOT EXISTS t_signal_log (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id  BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,
    action      VARCHAR(20)     DEFAULT '',
    signal      VARCHAR(100)    NOT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sl_monitor (monitor_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 高频查询索引(原误置于 MonitorExecutionService.java,现归位;MySQL 不支持 ADD INDEX IF NOT EXISTS,仅首次执行)
ALTER TABLE t_order            ADD INDEX idx_order_status   (status);
ALTER TABLE t_order            ADD INDEX idx_order_user      (user_id, id);
ALTER TABLE t_position         ADD INDEX idx_pos_user_status (user_id, status);
ALTER TABLE t_futures_position ADD INDEX idx_fpos_status     (status);

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
    status      VARCHAR(20)     NOT NULL DEFAULT 'pending',
    is_bot      TINYINT(1)      NOT NULL DEFAULT 0,
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sp_leader (leader_id),
    KEY idx_sp_monitor (monitor_id),
    KEY idx_sp_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 跟单关系表:follower 按比例跟随 leader 某条监控的交易
CREATE TABLE IF NOT EXISTS t_strategy_follow (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    publish_id  BIGINT          NOT NULL,
    leader_id   VARCHAR(32)     NOT NULL,
    monitor_id  BIGINT          NOT NULL,
    ratio       INT             NOT NULL DEFAULT 10,
    mode        VARCHAR(10)     NOT NULL DEFAULT 'ratio' COMMENT 'ratio=固定比例 balance=本金比例 fixed=固定倍数',
    fixed_multiplier DECIMAL(20,4) NOT NULL DEFAULT 1 COMMENT '固定倍数模式的倍数',
    status      VARCHAR(20)     NOT NULL DEFAULT 'active',
    created_at  DATETIME        NOT NULL,
    updated_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sf_user (user_id),
    KEY idx_sf_monitor (monitor_id),
    KEY idx_sf_publish (publish_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 跟单复制流水表:每次复制成交记一行,卖出行记已实现盈亏 pnl
CREATE TABLE IF NOT EXISTS t_copy_trade (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    follow_id   BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,
    publish_id  BIGINT          NOT NULL,
    monitor_id  BIGINT          NOT NULL,
    symbol      VARCHAR(30)     NOT NULL,
    side        VARCHAR(10)     NOT NULL,
    amount      DECIMAL(20,8)   NOT NULL,
    price       DECIMAL(20,8)   NOT NULL,
    pnl         DECIMAL(20,8)   DEFAULT NULL,
    order_id    VARCHAR(64)     DEFAULT NULL,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ct_user (user_id),
    KEY idx_ct_follow (follow_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════ 个人策略(人工配置、人工触发信号) ═══════════════
-- 信号流水:主交易员在信号台人工下发,机器人按跟单模式分发执行
CREATE TABLE IF NOT EXISTS t_personal_signal (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id  BIGINT          NOT NULL,
    user_id     VARCHAR(32)     NOT NULL,
    action      VARCHAR(20)     NOT NULL COMMENT 'open_long/add_long/partial_close/close_all/open_short',
    amount      DECIMAL(20,8)   DEFAULT NULL,
    ratio_pct   INT             DEFAULT NULL COMMENT '部分平仓百分比 1-99',
    leverage    INT             DEFAULT 5,
    ok_count    INT             DEFAULT 0,
    skip_count  INT             DEFAULT 0,
    detail      VARCHAR(500)    DEFAULT '',
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ps_monitor (monitor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 站内告警:跟单跳过/风控事件/系统消息
CREATE TABLE IF NOT EXISTS t_alert (
    id          BIGINT          NOT NULL AUTO_INCREMENT,
    user_id     VARCHAR(32)     NOT NULL,
    type        VARCHAR(20)     NOT NULL COMMENT 'copy_skip/risk/system',
    title       VARCHAR(100)    NOT NULL,
    content     VARCHAR(300)    DEFAULT '',
    read_flag   TINYINT         DEFAULT 0,
    created_at  DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_alert_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 系统配置(全局风控开关等)
CREATE TABLE IF NOT EXISTS t_system_config (
    config_key   VARCHAR(50)    NOT NULL,
    config_value VARCHAR(100)   DEFAULT '',
    updated_at   DATETIME       NOT NULL,
    PRIMARY KEY (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════ 开源策略量化机器人(自动带单) ═══════════════
CREATE TABLE IF NOT EXISTS t_quant_bot (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    bot_user_id     VARCHAR(32)     NOT NULL,
    monitor_id      BIGINT          NOT NULL,
    strategy_key    VARCHAR(30)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    config_json     VARCHAR(500)    DEFAULT '{}',
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_qb_monitor (monitor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_bot_grid_level (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    monitor_id      BIGINT          NOT NULL,
    grid_idx        INT             NOT NULL,
    trigger_price   DECIMAL(20,8)   NOT NULL,
    side            VARCHAR(10)     NOT NULL,
    amount          DECIMAL(20,8)   DEFAULT 0,
    status          VARCHAR(10)     NOT NULL,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    KEY idx_bgl_monitor (monitor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════ 合约交易域(USDT 本位永续合约模拟) ═══════════════
-- 合约账户(每用户一个,懒初始化 1 万 USDT 模拟金;钱包余额含占用保证金)
CREATE TABLE IF NOT EXISTS t_futures_account (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    wallet_balance  DECIMAL(20,8)   NOT NULL DEFAULT 10000,
    created_at      DATETIME        NOT NULL,
    updated_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_fa_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 合约持仓(单向模式:同标的只允许同向持仓,反向需先平仓)
CREATE TABLE IF NOT EXISTS t_futures_position (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    direction       VARCHAR(10)     NOT NULL,
    amount          DECIMAL(20,8)   NOT NULL,
    entry_price     DECIMAL(20,8)   NOT NULL,
    leverage        INT             NOT NULL DEFAULT 10,
    margin          DECIMAL(20,8)   NOT NULL,
    status          TINYINT         DEFAULT 0,
    opened_at       DATETIME        NOT NULL,
    closed_at       DATETIME        DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_fp_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 合约成交记录(市价开/平仓流水)
CREATE TABLE IF NOT EXISTS t_futures_order (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    user_id         VARCHAR(32)     NOT NULL,
    order_id        VARCHAR(40)     NOT NULL,
    symbol          VARCHAR(30)     NOT NULL,
    direction       VARCHAR(10)     NOT NULL,
    action          VARCHAR(10)     NOT NULL,
    amount          DECIMAL(20,8)   NOT NULL,
    price           DECIMAL(20,8)   NOT NULL,
    leverage        INT             NOT NULL DEFAULT 0,
    margin          DECIMAL(20,8)   NOT NULL DEFAULT 0,
    fee             DECIMAL(20,8)   NOT NULL DEFAULT 0,
    pnl             DECIMAL(20,8)   NOT NULL DEFAULT 0,
    created_at      DATETIME        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_fo_id (order_id),
    KEY idx_fo_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 测试用户: 手机号 13800138000, 密码 123456 (MD5, 首次登录自动升级 BCrypt)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser001', '13800138000', 'e10adc3949ba59abbe56e057f20f883e', '量化测试用户', 'R3', 1, 0, NOW(), NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138000');

-- 测试账号 B: 手机号 13800138001, 密码 123456 (多用户场景: 跟单/邀请/团队)
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser002', '13800138001', 'e10adc3949ba59abbe56e057f20f883e', '测试账号B', 'R3', 1, 0, NOW(), NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138001');

-- 测试账号 C: 手机号 13800138002, 密码 123456
INSERT INTO t_user (user_id, phone, password_hash, nickname, risk_level, agreement_signed, status, created_at, updated_at)
SELECT 'testuser003', '13800138002', 'e10adc3949ba59abbe56e057f20f883e', '测试账号C', 'R3', 1, 0, NOW(), NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM t_user WHERE phone = '13800138002');

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

-- ═══════════════════════════════════════════════════════════
-- 存量库升级(从旧版 schema-mysql 建的库执行;全新建库已含上述列,可跳过)
-- ═══════════════════════════════════════════════════════════
ALTER TABLE t_position ADD COLUMN IF NOT EXISTS available_amount DECIMAL(20,8) DEFAULT 0;
UPDATE t_position SET available_amount = amount WHERE symbol LIKE '%/%' AND available_amount = 0;
ALTER TABLE t_order ADD COLUMN IF NOT EXISTS fail_reason VARCHAR(255) DEFAULT NULL;
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS ip VARCHAR(45) DEFAULT NULL;
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS user_agent VARCHAR(255) DEFAULT NULL;
ALTER TABLE t_agreement_signature ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64) DEFAULT NULL;

-- ═══════════════════════════════════════════════════════════
-- 邀请奖励表(推荐人获被推荐人交易流水 1% 返佣;存量库由 DBA 手工执行)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS t_referral_reward (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    referrer_id VARCHAR(50)   NOT NULL COMMENT '推荐人(获奖励方)',
    trader_id   VARCHAR(50)   NOT NULL COMMENT '被推荐人(成交方)',
    order_id    VARCHAR(64)   NOT NULL COMMENT '触发返佣的订单',
    symbol      VARCHAR(32)   NOT NULL COMMENT '成交标的',
    currency    VARCHAR(8)    NOT NULL COMMENT '返佣币种(USDT/CNY)',
    volume      DOUBLE        NOT NULL COMMENT '成交额',
    reward      DOUBLE        NOT NULL COMMENT '返佣金额 = volume × 1%',
    created_at  DATETIME      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_referral_reward_referrer (referrer_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════════════════════════════════════
-- 内容管理域
-- ═══════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS t_banner (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    title       VARCHAR(100)  NOT NULL                COMMENT '标题',
    image_url   VARCHAR(500)  NOT NULL                COMMENT '图片URL',
    link_type   VARCHAR(20)   DEFAULT 'none'          COMMENT '跳转类型: none/url/strategy/announcement',
    link_url    VARCHAR(500)  DEFAULT NULL            COMMENT '跳转链接/ID',
    position    INT           DEFAULT 0               COMMENT '排序权重(越大越靠前)',
    status      TINYINT       DEFAULT 1               COMMENT '0=禁用 1=启用',
    start_time  DATETIME      DEFAULT NULL            COMMENT '展示开始时间',
    end_time    DATETIME      DEFAULT NULL            COMMENT '展示结束时间',
    creator     VARCHAR(50)   DEFAULT NULL            COMMENT '创建人',
    created_at  DATETIME      NOT NULL,
    updated_at  DATETIME      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_banner_status_pos (status, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='轮播图/Banner';

CREATE TABLE IF NOT EXISTS t_faq (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    category    VARCHAR(30)   NOT NULL                COMMENT '分类: account/trading/futures/ai/copy/other',
    question    VARCHAR(200)  NOT NULL                COMMENT '问题',
    answer      TEXT          NOT NULL                COMMENT '回答',
    sort_order  INT           DEFAULT 0               COMMENT '排序(越小越靠前)',
    status      TINYINT       DEFAULT 1               COMMENT '0=隐藏 1=显示',
    creator     VARCHAR(50)   DEFAULT NULL            COMMENT '创建人',
    created_at  DATETIME      NOT NULL,
    updated_at  DATETIME      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_faq_category (category, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='FAQ/帮助中心';

CREATE TABLE IF NOT EXISTS t_push_notification (
    id              BIGINT        NOT NULL AUTO_INCREMENT,
    title           VARCHAR(100)  NOT NULL                COMMENT '推送标题',
    content         VARCHAR(500)  NOT NULL                COMMENT '推送内容',
    target_type     VARCHAR(20)   DEFAULT 'all'           COMMENT '目标: all/risk_level/user_ids',
    target_value    VARCHAR(500)  DEFAULT NULL            COMMENT '目标值(如R3,R4或用户ID列表)',
    status          TINYINT       DEFAULT 0               COMMENT '0=草稿 1=待发送 2=已发送 3=已取消',
    scheduled_at    DATETIME      DEFAULT NULL            COMMENT '定时发送时间',
    sent_at         DATETIME      DEFAULT NULL            COMMENT '实际发送时间',
    sent_count      INT           DEFAULT 0               COMMENT '发送人数',
    creator         VARCHAR(50)   DEFAULT NULL            COMMENT '创建人',
    created_at      DATETIME      NOT NULL,
    updated_at      DATETIME      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_push_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='推送通知';
