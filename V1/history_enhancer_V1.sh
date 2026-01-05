
#!/bin/bash
# SSH命令增强记录器 v1.2
# 记录格式：时间戳 会话类型 [PID] 用户名 执行的命令

LOG_FILE="${HOME}/.enhanced_history"
MAX_LOG_SIZE=10485760  # 10MB日志轮转阈值

# 获取当前会话标识
get_session_id() {
    if [ -n "$SSH_CONNECTION" ]; then
        IFS=' ' read -ra conn <<< "$SSH_CONNECTION"
        echo "[SSH] [${conn[0]}:${conn[1]}] TO [${conn[2]}:${conn[3]}]"
    else
        echo "LOCAL[$(tty | sed 's/\/dev\///')]"
    fi
}

# 日志轮转检查
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d%H%M%S)"
        gzip "${LOG_FILE}.$(date +%Y%m%d%H%M%S)" &
    fi
}

# 主记录逻辑
PROMPT_COMMAND='
    last_cmd=$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")
    if [[ -n "$last_cmd" && "$last_cmd" != "$prev_cmd" ]]; then
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        session=$(get_session_id)
        log_entry="$timestamp $session [$$] [$(whoami)] [ $last_cmd ]"
        rotate_log
        echo "$log_entry" >> "$LOG_FILE"
        prev_cmd="$last_cmd"
    fi
'

# 查看命令（过滤自身调用）
alias enhistory='grep -v " enhistory$" "$LOG_FILE" 2>/dev/null || echo "No enhanced history found"'

# 初始化日志文件
[ ! -f "$LOG_FILE" ] && touch "$LOG_FILE" && chmod 600 "$LOG_FILE"

