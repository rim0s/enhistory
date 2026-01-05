#!/bin/bash
# History Enhancer Installer v3.0 - 修复权限和路径问题

set -e

CONFIG_FILE="/etc/profile.d/history_enhancer.sh"
MAIN_SCRIPT="history_enhancer.sh"
INTERFACE_MODULE="db_transcriber_interface.sh"
LOG_FILE="${HOME}/.enhanced_history_log"  # 明确指定日志文件
BASE_DIR="${HOME}/.enhanced_history"
DB_MODULES_DIR="${BASE_DIR}/db_modules"
CONFIG_DIR="${BASE_DIR}/config"
ARCHIVE_DIR="${HOME}/.enhanced_history_archives"

# 默认配置
DB_TYPE="none"
KEEPDATA=false
DB_CONFIG_FILE=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --database-type)
            DB_TYPE="$2"
            shift 2
            ;;
        --db-config)
            DB_CONFIG_FILE="$2"
            shift 2
            ;;
        --keepdata)
            KEEPDATA=true
            shift
            ;;
        --enable-encryption)
            echo "⚠️  加密功能暂未实现，将在未来版本中提供"
            shift
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [--database-type none|sqlite|postgresql] [--db-config file] [--keepdata] [--enable-encryption]"
            exit 1
            ;;
    esac
done

echo "▶ 正在部署SSH历史记录增强系统..."

# 检查主脚本是否存在
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "❌ 错误: 找不到主脚本 $MAIN_SCRIPT"
    exit 1
fi

# 清理可能存在的权限问题
echo "🔄 清理旧安装..."
sudo rm -f "/etc/profile.d/history_enhancer.sh" 2>/dev/null || true
sudo rm -f "/etc/profile.d/history_enhancer_main.sh" 2>/dev/null || true
sudo rm -f "/etc/profile.d/db_transcriber_interface.sh" 2>/dev/null || true

# 只有在不保留数据时才清理用户文件
if [ "$KEEPDATA" != "true" ]; then
    sudo rm -rf "$BASE_DIR" 2>/dev/null || true
    sudo rm -rf "$ARCHIVE_DIR" 2>/dev/null || true
    sudo rm -f "$LOG_FILE" 2>/dev/null || true
fi

# 创建用户目录结构（确保正确权限）
echo "📁 创建目录结构..."
mkdir -p "$DB_MODULES_DIR" "$CONFIG_DIR" "$ARCHIVE_DIR"
chmod 755 "$BASE_DIR" "$DB_MODULES_DIR" "$CONFIG_DIR" "$ARCHIVE_DIR"

# 创建主日志文件（如果是新安装）
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

# 复制系统文件
echo "📄 安装系统文件..."
sudo cp "$MAIN_SCRIPT" "/etc/profile.d/history_enhancer_main.sh"
sudo chmod 644 "/etc/profile.d/history_enhancer_main.sh"

if [ -f "$INTERFACE_MODULE" ]; then
    sudo cp "$INTERFACE_MODULE" "/etc/profile.d/db_transcriber_interface.sh"
    sudo chmod 644 "/etc/profile.d/db_transcriber_interface.sh"
else
    echo "⚠️  警告: 未找到数据库接口模块"
fi

# 创建数据库模块
echo "🔧 配置数据库模块..."
cat > "$DB_MODULES_DIR/none_transcriber.sh" << 'EOF'
#!/bin/bash
# 空数据库转录模块

_transcribe_to_database() {
    return 0
}

_query_database() {
    echo "数据库功能已禁用"
    return 1
}

_initialize_database() {
    echo "数据库功能已禁用"
    return 0
}

_validate_database_connection() {
    return 1
}

_backup_database() {
    echo "数据库功能已禁用"
    return 0
}
EOF

chmod +x "$DB_MODULES_DIR/none_transcriber.sh"

# 创建数据库配置
cat > "$CONFIG_DIR/database.conf" << EOF
# 增强历史记录数据库配置
# 当前数据库类型: $DB_TYPE

# 通用配置
# ENHANCED_HISTORY_DB_ENABLED=false
# DB_TYPE="$DB_TYPE"

# SQLite 配置示例
# SQLITE_DB_PATH="\${HOME}/.enhanced_history/command_history.db"

# PostgreSQL 配置示例  
# POSTGRES_HOST="localhost"
# POSTGRES_PORT="5432"
# POSTGRES_DB="command_history"
# POSTGRES_USER="history_user"
# POSTGRES_PASSWORD=""

# 加密配置（预留）
# ENABLE_STORAGE_ENCRYPTION=false
# ENCRYPTION_KEY=""
EOF

# 创建主配置文件 - 使用明确的文件路径
echo "⚙️ 创建主配置文件..."
sudo tee "$CONFIG_FILE" > /dev/null << EOF
#!/bin/bash
# SSH命令增强记录器 - 配置初始化

# 基础配置
export ENHANCED_HISTORY_ENABLED=1
export ENHANCED_HISTORY_LOG_FILE="$LOG_FILE"  # 使用明确变量
export ENHANCED_HISTORY_MAX_SIZE=10485760
export ENHANCED_HISTORY_ARCHIVE_DIR="$ARCHIVE_DIR"

# 数据库配置
export ENHANCED_HISTORY_DB_ENABLED=false
export ENHANCED_HISTORY_DB_MODULE="$DB_MODULES_DIR/none_transcriber.sh"

# 根据数据库类型配置
case "$DB_TYPE" in
    "sqlite"|"postgresql")
        export ENHANCED_HISTORY_DB_ENABLED=true
        ;;
    *)
        export ENHANCED_HISTORY_DB_ENABLED=false
        ;;
esac

# 确保目录存在
mkdir -p "$ARCHIVE_DIR" "$DB_MODULES_DIR" "$CONFIG_DIR" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true
chmod 600 "$LOG_FILE" 2>/dev/null || true

# 加载接口
[ -f "/etc/profile.d/db_transcriber_interface.sh" ] && source "/etc/profile.d/db_transcriber_interface.sh"

# 加载外部配置
[ -f "$CONFIG_DIR/database.conf" ] && source "$CONFIG_DIR/database.conf"

# 加载主功能
source "/etc/profile.d/history_enhancer_main.sh"
EOF

sudo chmod 644 "$CONFIG_FILE"

# 配置用户环境
echo "🔗 配置用户环境..."
if ! grep -q "source $CONFIG_FILE" ~/.bashrc; then
    echo "source $CONFIG_FILE" >> ~/.bashrc
fi

# 设置正确权限
chown -R $(whoami) "$BASE_DIR" "$ARCHIVE_DIR" 2>/dev/null || true
chmod -R 755 "$BASE_DIR" 2>/dev/null || true
chmod 600 "$LOG_FILE" 2>/dev/null || true

echo "✅ 安装完成！"
echo "📊 部署信息:"
echo "   - 数据库功能: $DB_TYPE"
echo "   - 数据保留: $KEEPDATA"
echo "   - 日志文件: $LOG_FILE"
echo "   - 配置目录: $BASE_DIR/"
echo "   - 归档目录: $ARCHIVE_DIR/"
echo ""
echo "🚀 立即生效命令:"
echo "   source $CONFIG_FILE"
echo ""
echo "📖 使用示例:"
echo "   enhistory                    # 查看当前历史"
echo "   enhistory --all              # 查看所有历史"
echo "   enhistory --since 2025-11-13 # 按日期筛选"
echo "   enhistory --db               # 尝试数据库查询"
