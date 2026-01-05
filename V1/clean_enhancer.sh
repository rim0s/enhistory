bin/bash
# 历史日志维护工具

LOG_DIR="${HOME}"
RETENTION_DAYS=30

find "$LOG_DIR" -name ".audit_history*" -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "已清理超过${RETENTION_DAYS}天的历史日志文件"

