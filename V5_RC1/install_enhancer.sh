#!/bin/bash
# History Enhancer Installer v2.3 - 支持数据库功能扩展

set -e

CONFIG_FILE="/etc/profile.d/history_enhancer.sh"
MAIN_SCRIPT="history_enhancer.sh"
INTERFACE_MODULE="db_transcriber_interface.sh"
BASE_DIR="${HOME}/.enhanced_history"
DB_MODULES_DIR="${BASE_DIR}/db_modules"
CONFIG_DIR="${BASE_DIR}/config"

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

# 创建目录结构
mkdir -p "$DB_MODULES_DIR" "$CONFIG_DIR"

# 复制主脚本
sudo cp "$MAIN_SCRIPT" "/etc/profile.d/history_enhancer_main.sh"
sudo chmod +x "/etc/profile.d/history_enhancer_main.sh"

# 复制接口模块
if [ -f "$INTERFACE_MODULE" ]; then
    sudo cp "$INTERFACE_MODULE" "/etc/profile.d/db_transcriber_interface.sh"
    sudo chmod +x "/etc/profile.d/db_transcriber_interface.sh"
else
    echo "⚠️  警告: 未找到数据库接口模块，数据库功能将不可用"
fi

# 创建配置文件
sudo tee "$CONFIG_FILE" > /dev/null << EOF
#!/bin/bash
# SSH命令增强记录器 - 配置初始化

# 基础配置
export ENHANCED_HISTORY_ENABLED=1
export ENHANCED_HISTORY_LOG_FILE="\${HOME}/.enhanced_history"
export ENHANCED_HISTORY_MAX_SIZE=10485760  # 10MB
export ENHANCED_HISTORY_ARCHIVE_DIR="\${HOME}/.enhanced_history_archives"

# 数据库配置
export ENHANCED_HISTORY_DB_ENABLED=false
export ENHANCED_HISTORY_DB_MODULE=""

# 创建必要的目录和文件
mkdir -p "\$ENHANCED_HISTORY_ARCHIVE_DIR" "\${HOME}/.enhanced_history/db_modules" "\${HOME}/.enhanced_history/config"
touch "\$ENHANCED_HISTORY_LOG_FILE"
chmod 600 "\$ENHANCED_HISTORY_LOG_FILE"

# 加载数据库接口
if [ -f "/etc/profile.d/db_transcriber_interface.sh" ]; then
    source "/etc/profile.d/db_transcriber_interface.sh"
fi

# 根据数据库类型配置模块
case "$DB_TYPE" in
    "none")
        export ENHANCED_HISTORY_DB_ENABLED=false
        export ENHANCED_HISTORY_DB_MODULE="\${HOME}/.enhanced_history/db_modules/none_transcriber.sh"
        ;;
    "sqlite")
        export ENHANCED_HISTORY_DB_ENABLED=true
        export ENHANCED_HISTORY_DB_MODULE="\${HOME}/.enhanced_history/db_modules/sqlite_transcriber.sh"
        ;;
    "postgresql")
        export ENHANCED_HISTORY_DB_ENABLED=true
        export ENHANCED_HISTORY_DB_MODULE="\${HOME}/.enhanced_history/db_modules/postgresql_transcriber.sh"
        ;;
    *)
        export ENHANCED_HISTORY_DB_ENABLED=false
        export ENHANCED_HISTORY_DB_MODULE=""
        ;;
esac

# 加载外部数据库配置
if [ -n "$DB_CONFIG_FILE" -a -f "$DB_CONFIG_FILE" ]; then
    source "$DB_CONFIG_FILE"
elif [ -f "\${HOME}/.enhanced_history/config/database.conf" ]; then
    source "\${HOME}/.enhanced_history/config/database.conf"
fi

# 加载主功能
if [ -f "/etc/profile.d/history_enhancer_main.sh" ]; then
    source "/etc/profile.d/history_enhancer_main.sh"
fi
EOF

sudo chmod +x "$CONFIG_FILE"

# 安装空数据库模块
sudo tee "${HOME}/.enhanced_history/db_modules/none_transcriber.sh" > /dev/null << 'EOF'
#!/bin/bash
# 空数据库转录模块 - 用于禁用数据库功能

_transcribe_to_database() {
    # 空实现 - 什么都不做
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

sudo chmod +x "${HOME}/.enhanced_history/db_modules/none_transcriber.sh"

# 创建默认数据库配置文件
sudo tee "${HOME}/.enhanced_history/config/database.conf" > /dev/null << 'EOF'
# 增强历史记录数据库配置
# 当前数据库类型: none

# 通用配置
# ENHANCED_HISTORY_DB_ENABLED=false
# DB_TYPE="none"

# SQLite 配置示例
# SQLITE_DB_PATH="${HOME}/.enhanced_history/command_history.db"

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

# 配置用户环境
if ! grep -q "source $CONFIG_FILE" ~/.bashrc; then
    echo "source $CONFIG_FILE" >> ~/.bashrc
fi

# 初始化历史文件（如果不存在且要求保留数据）
if [ "$KEEPDATA" = true ] && [ ! -f "${HOME}/.enhanced_history" ]; then
    touch "${HOME}/.enhanced_history"
    chmod 600 "${HOME}/.enhanced_history"
fi

echo "✓ 安装完成！"
echo "✓ 增强历史记录系统已部署"
echo "✓ 数据库功能: $DB_TYPE"
echo "✓ 数据保留: $KEEPDATA"
echo ""
echo "使用示例:"
echo "  enhistory                    # 查看当前会话历史"
echo "  enhistory --all              # 查看所有历史记录"
echo "  enhistory --since 2025-11-13 # 查看指定日期之后的记录"
echo "  enhistory --db               # 尝试使用数据库查询（如果启用）"
echo ""
echo "重新登录后生效，或运行: source ~/.bashrc"
