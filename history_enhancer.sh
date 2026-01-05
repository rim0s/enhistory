#!/bin/bash
# SSH命令增强记录器 v1.4
# 记录格式：时间戳 会话类型 [PID] 用户名 执行的命令

# 配置变量（由部署脚本设置）
# LOG_FILE="${HOME}/.enhanced_history"
# MAX_LOG_SIZE=10485760
# LOG_DIR="${HOME}/.enhanced_history_archives"

# 获取当前会话标识
get_session_info() {
    if [ -n "$SSH_CONNECTION" ]; then
        IFS=' ' read -ra conn <<< "$SSH_CONNECTION"
        echo "[SSH] [${conn[0]}:${conn[1]}] TO [${conn[2]}:${conn[3]}] [$(tty | sed 's/\/dev\///')]"
    elif [ "$(logname)" == "$(whoami)" ]; then
        echo "[LOCAL] [$(tty | sed 's/\/dev\///')]"
    elif pstree -hglptsu $$ 2> /dev/null | grep -q sshd ; then
        IFS=' ' read -ra preconn <<< "$PRE_SSH_INFO"
        echo "[SSH] [su] [${preconn[0]}:${preconn[1]}] TO [${conn[2]}:${conn[3]}] [$(tty | sed 's/\/dev\///')] [$(logname)] AS"
    else
        echo "[LOCAL] [su] [$(tty | sed 's/\/dev\///')] [$(logname)] AS"
    fi
}

# 日志轮转检查
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        mkdir -p "$LOG_DIR"
        archive_file="${LOG_DIR}/enhanced_history_$(date +%Y-%m-%d_%H-%M-%S).log"
        mv "$LOG_FILE" "$archive_file"
        gzip "$archive_file" &
    fi
}

# 增强的历史查看函数
enhistory() {
    local show_all=false
    local since_date=""
    local from_date=""
    local to_date=""
    local filter_cmd="cat"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                show_all=true
                shift
                ;;
            --since)
                since_date="$2"
                shift 2
                ;;
            --from)
                from_date="$2"
                shift 2
                ;;
            --to)
                to_date="$2"
                shift 2
                ;;
            *)
                echo "未知参数: $1"
                echo "用法: enhistory [--all] [--since YYYY-MM-DD] [--from \"YYYY-MM-DD HH:MM\"] [--to \"YYYY-MM-DD HH:MM\"]"
                return 1
                ;;
        esac
    done
    
    # 构建时间筛选条件
    if [[ -n "$since_date" ]]; then
        filter_cmd="awk -v since=\"$since_date\" '\$1 >= since'"
    fi
    
    if [[ -n "$from_date" && -n "$to_date" ]]; then
        filter_cmd="awk -v from=\"$from_date\" -v to=\"$to_date\" '\$1 \" \" \$2 >= from && \$1 \" \" \$2 <= to'"
    elif [[ -n "$from_date" ]]; then
        filter_cmd="awk -v from=\"$from_date\" '\$1 \" \" \$2 >= from'"
    elif [[ -n "$to_date" ]]; then
        filter_cmd="awk -v to=\"$to_date\" '\$1 \" \" \$2 <= to'"
    fi
    
    # 收集所有历史文件（当前文件 + 归档文件）
    local history_files=()
    
    if [ -f "$LOG_FILE" ]; then
        history_files+=("$LOG_FILE")
    fi
    
    if [ -d "$LOG_DIR" ]; then
        # 添加未压缩的归档文件
        for file in "$LOG_DIR"/*.log; do
            [ -f "$file" ] && history_files+=("$file")
        done
        # 添加压缩的归档文件，临时解压处理
        for file in "$LOG_DIR"/*.log.gz; do
            if [ -f "$file" ]; then
                local temp_file=$(mktemp)
                gunzip -c "$file" > "$temp_file"
                history_files+=("$temp_file")
            fi
        done
    fi
    
    if [ ${#history_files[@]} -eq 0 ]; then
        echo "No enhanced history found"
        return 1
    fi
    
    # 处理查询
    local temp_files=()
    for file in "${history_files[@]}"; do
        if [[ "$file" == *.gz ]]; then
            local temp_file=$(mktemp)
            gunzip -c "$file" > "$temp_file"
            temp_files+=("$temp_file")
            if $show_all || [[ -n "$since_date" || -n "$from_date" || -n "$to_date" ]]; then
                eval "$filter_cmd" "$temp_file" 2>/dev/null | grep -v " enhistory$"
            else
                grep -v " enhistory$" "$temp_file" 2>/dev/null
            fi
        else
            if $show_all || [[ -n "$since_date" || -n "$from_date" || -n "$to_date" ]]; then
                eval "$filter_cmd" "$file" 2>/dev/null | grep -v " enhistory$"
            else
                grep -v " enhistory$" "$file" 2>/dev/null
            fi
        fi
    done | sort
    
    # 清理临时文件
    for temp_file in "${temp_files[@]}"; do
        [ -f "$temp_file" ] && rm -f "$temp_file"
    done
}

# 主记录逻辑（仅在交互式shell中启用）
if [[ $- == *i* ]]; then
    PROMPT_COMMAND='
        last_cmd=$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")
        if [[ -n "$last_cmd" && "$last_cmd" != "$prev_cmd" ]]; then
            timestamp=$(date "+%Y-%m-%d %H:%M:%S")
            session=$(get_session_info)
            log_entry="$timestamp $session [$(whoami)] [$$] [ $last_cmd ]"
            rotate_log
            echo "$log_entry" >> "$LOG_FILE"
            prev_cmd="$last_cmd"
        fi
    '
    
    shopt -s histappend
    # PRE_SSH_INFO="$SSH_CONNECTION"
    # export PRE_SSH_INFO
fi