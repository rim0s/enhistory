#!/bin/bash
# SSH命令增强记录器 v1.7 - 证据链增强版
# 记录格式：时间戳 会话类型 [用户链] [PID] [进程链] 执行的命令

# 配置变量（由部署脚本设置）
# ENHANCED_HISTORY_ENABLED=1
# ENHANCED_HISTORY_LOG_FILE="${HOME}/.enhanced_history_log"
# ENHANCED_HISTORY_MAX_SIZE=10485760
# ENHANCED_HISTORY_ARCHIVE_DIR="${HOME}/.enhanced_history_archives"
# ENHANCED_HISTORY_DB_ENABLED=false
# ENHANCED_HISTORY_DB_MODULE=""

# 生成或获取会话ID
get_session_id() {
    if [ -z "$ENHANCED_SESSION_ID" ]; then
        export ENHANCED_SESSION_ID="SESS_$(hostname -s)_$$_$(date +%Y%m%d_%H%M%S)"
        export ENHANCED_SESSION_START_USER=$(whoami)
        # 记录会话开始
        local start_record="$(date '+%Y-%m-%d %H:%M:%S')|SESSION_START|$ENHANCED_SESSION_ID|$ENHANCED_SESSION_START_USER|$(pwd)"
        echo "$start_record" >> "$ENHANCED_HISTORY_LOG_FILE"
    fi
    echo "$ENHANCED_SESSION_ID"
}

# 获取用户切换链（最小逻辑）
get_user_chain() {
    local current_user=$(whoami)
    local session_start_user="${ENHANCED_SESSION_START_USER:-$current_user}"
    
    # 如果当前用户与会话开始用户不同，显示切换链
    if [ "$current_user" != "$session_start_user" ]; then
        echo "${session_start_user}→${current_user}"
    else
        echo "${current_user}"
    fi
}

# 获取简化进程链（性能优化）
get_simple_process_chain() {
    # 使用缓存避免频繁调用pstree
    if [ -z "$ENHANCED_PROCESS_CHAIN_CACHE" ] || [ "$ENHANCED_PROCESS_CHAIN_TS" != "$$" ]; then
        local chain="unknown"
        if command -v pstree >/dev/null 2>&1; then
            # 获取完整进程链，但过滤掉子进程分支
            chain=$(pstree -hp $$ 2>/dev/null | head -1)
            # 只保留主进程链，移除所有子进程分支（-+-开头的内容）
            chain=$(echo "$chain" | sed 's/-+-[^)]*//g')
            # 标准化格式：空格替换为箭头，保留进程号
            chain=$(echo "$chain" | sed 's/[[:space:]]\+/→/g')
            chain=$(echo "$chain" | cut -c1-100)
        fi
        export ENHANCED_PROCESS_CHAIN_CACHE="$chain"
        export ENHANCED_PROCESS_CHAIN_TS="$$"
    fi
    echo "$ENHANCED_PROCESS_CHAIN_CACHE"
}

# 获取当前会话标识（保持原有逻辑）
get_session_info() {
    if [ -n "$SSH_CONNECTION" ]; then
        IFS=' ' read -ra conn <<< "$SSH_CONNECTION"
        echo "[SSH] [${conn[0]}:${conn[1]}] TO [${conn[2]}:${conn[3]}] [$(tty | sed 's/\/dev\///')]"
    elif [ "$(get_session_start_user)" == "$(whoami)" ]; then
        echo "[LOCAL] [$(tty | sed 's/\/dev\///')]"
    elif pstree -hglptsu $$ 2> /dev/null | grep -q sshd ; then
        IFS=' ' read -ra preconn <<< "$PRE_SSH_INFO"
        echo "[SSH] [su] [${preconn[0]}:${conn[1]}] TO [${conn[2]}:${conn[3]}] [$(tty | sed 's/\/dev\///')] [$(get_session_start_user)] AS"
    else
        echo "[LOCAL] [su] [$(tty | sed 's/\/dev\///')] [$(get_session_start_user)] AS"
    fi
}

# 获取会话开始用户
get_session_start_user() {
    echo "${ENHANCED_SESSION_START_USER:-$(whoami)}"
}

# 日志轮转检查
rotate_log() {
    if [ -f "$ENHANCED_HISTORY_LOG_FILE" ] && [ $(stat -c%s "$ENHANCED_HISTORY_LOG_FILE") -gt $ENHANCED_HISTORY_MAX_SIZE ]; then
        mkdir -p "$ENHANCED_HISTORY_ARCHIVE_DIR"
        archive_file="${ENHANCED_HISTORY_ARCHIVE_DIR}/enhanced_history_$(date +%Y-%m-%d_%H-%M-%S).log"
        mv "$ENHANCED_HISTORY_LOG_FILE" "$archive_file"
        gzip "$archive_file" &
        # 清除进程链缓存（新文件需要重新收集）
        unset ENHANCED_PROCESS_CHAIN_CACHE
        unset ENHANCED_PROCESS_CHAIN_TS
    fi
}

# 数据库转录接口调用
_invoke_db_transcription() {
    local log_entry="$1"
    
    # 检查是否启用数据库功能
    if [[ "$ENHANCED_HISTORY_DB_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # 调用具体的转录模块
    if [[ -n "$ENHANCED_HISTORY_DB_MODULE" && -f "$ENHANCED_HISTORY_DB_MODULE" ]]; then
        source "$ENHANCED_HISTORY_DB_MODULE"
        if declare -f _transcribe_to_database > /dev/null; then
            _transcribe_to_database "$log_entry"
        fi
    fi
    
    return 0
}

# 增强的历史查看函数
enhistory() {
    local show_all=false
    local since_date=""
    local from_date=""
    local to_date=""
    local use_database=false
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
            --db|--database)
                use_database=true
                shift
                ;;
            --session)
                echo "当前会话ID: $(get_session_id)"
                echo "会话开始用户: $(get_session_start_user)"
                echo "当前用户: $(whoami)"
                return 0
                ;;
            *)
                echo "未知参数: $1"
                echo "用法: enhistory [--all] [--since YYYY-MM-DD] [--from \"YYYY-MM-DD HH:MM\"] [--to \"YYYY-MM-DD HH:MM\"] [--db] [--session]"
                return 1
                ;;
        esac
    done
    
    # 优先使用数据库查询（如果启用且请求）
    if [[ "$use_database" == "true" && "$ENHANCED_HISTORY_DB_ENABLED" == "true" && -f "$ENHANCED_HISTORY_DB_MODULE" ]]; then
        source "$ENHANCED_HISTORY_DB_MODULE"
        if declare -f _query_database > /dev/null; then
            _query_database "$@"
            return $?
        fi
    fi
    
    # 文件查询逻辑
    _query_via_files "$show_all" "$since_date" "$from_date" "$to_date"
}

# 文件查询实现
_query_via_files() {
    local show_all="$1"
    local since_date="$2"
    local from_date="$3"
    local to_date="$4"
    local filter_cmd="cat"
    
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
    
    # 收集所有历史文件
    local history_files=()
    
    if [ -f "$ENHANCED_HISTORY_LOG_FILE" ]; then
        history_files+=("$ENHANCED_HISTORY_LOG_FILE")
    fi
    
    if [[ "$show_all" == "true" && -d "$ENHANCED_HISTORY_ARCHIVE_DIR" ]]; then
        # 添加未压缩的归档文件
        for file in "$ENHANCED_HISTORY_ARCHIVE_DIR"/*.log; do
            [ -f "$file" ] && history_files+=("$file")
        done
        # 添加压缩的归档文件
        for file in "$ENHANCED_HISTORY_ARCHIVE_DIR"/*.log.gz; do
            if [ -f "$file" ]; then
                local temp_file=$(mktemp)
                gunzip -c "$file" > "$temp_file" 2>/dev/null && history_files+=("$temp_file")
            fi
        done
    fi
    
    if [ ${#history_files[@]} -eq 0 ]; then
        echo "No enhanced history found"
        return 1
    fi
    
    # 处理查询并清理临时文件
    local temp_files=()
    for file in "${history_files[@]}"; do
        if [[ "$file" =~ \.tmp\..* ]]; then
            temp_files+=("$file")
        fi
    done
    
    # 执行查询（过滤掉SESSION_START记录和enhistory命令自身）
    for file in "${history_files[@]}"; do
        if [[ "$show_all" == "true" || -n "$since_date" || -n "$from_date" || -n "$to_date" ]]; then
            eval "$filter_cmd" "$file" 2>/dev/null | grep -v "SESSION_START" | grep -v " enhistory$"
        else
            grep -v "SESSION_START" "$file" 2>/dev/null | grep -v " enhistory$"
        fi
    done | sort
    
    # 清理临时文件
    for temp_file in "${temp_files[@]}"; do
        [ -f "$temp_file" ] && rm -f "$temp_file"
    done
}

# 主记录逻辑（仅在交互式shell中启用）
if [[ $- == *i* && "$ENHANCED_HISTORY_ENABLED" == "1" ]]; then
    # 初始化会话
    get_session_id >/dev/null 2>&1
    
    PROMPT_COMMAND='
        # 捕获上一条命令的返回码
        RETURN_CODE=$?
        export LAST_RETURN_CODE=$RETURN_CODE
        
        last_cmd=$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")
        if [[ -n "$last_cmd" && "$last_cmd" != "$prev_cmd" ]]; then
            timestamp=$(date "+%Y-%m-%d %H:%M:%S")
            session=$(get_session_info)
            user_chain=$(get_user_chain)
            process_chain=$(get_simple_process_chain)
            log_entry="$timestamp $session [${user_chain}] [$$] [proc:${process_chain}] [ $last_cmd ]"
            rotate_log
            echo "$log_entry" >> "$ENHANCED_HISTORY_LOG_FILE"
            _invoke_db_transcription "$log_entry"
            prev_cmd="$last_cmd"
        fi
    '
    
    shopt -s histappend
fi