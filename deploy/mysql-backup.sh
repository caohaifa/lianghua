#!/usr/bin/env bash
# MySQL 每日全量备份(F 类:备份策略)
#
# crontab 示例(每日 02:30 全量):
#   30 2 * * * /opt/ai-quant/deploy/mysql-backup.sh >> /var/log/ai-quant-backup.log 2>&1
#
# 恢复: gunzip < ai_quant_YYYY-MM-DD_HHMM.sql.gz | mysql -u root -p
set -euo pipefail

BACKUP_DIR=/opt/ai-quant/backups/mysql
RETAIN_DAYS=30
DB=ai_quant
MYSQL_USER=root
MYSQL_PASSWORD="${MYSQL_PASSWORD:?需要 MYSQL_PASSWORD 环境变量}"

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%F_%H%M)
OUT="$BACKUP_DIR/${DB}_${STAMP}.sql.gz"

# 全量(单事务保证一致性;含存储过程/事件/触发器/建库语句)
mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --single-transaction --routines --events --triggers \
  --databases "$DB" | gzip > "$OUT"

# 清理过期备份
find "$BACKUP_DIR" -name "${DB}_*.sql.gz" -mtime +"${RETAIN_DAYS}" -delete

echo "[$(date '+%F %T')] 备份完成: $OUT ($(du -h "$OUT" | cut -f1))"

# ── binlog 增量说明(配合每日全量可恢复到任意时间点)──────────
# my.cnf 开启:
#   server-id = 1
#   log_bin   = /var/log/mysql/mysql-bin.log
#   binlog_expire_logs_seconds = 2592000   # 30 天自动过期
