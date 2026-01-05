#!/bin/bash
# History Enhancer Installer v2.2

CONFIG_FILE="/etc/profile.d/history_enhancer.sh"
MAIN_SCRIPT="history_enhancer.sh"

echo "▶ 正在部署SSH历史记录增强系统..."

# 检查主脚本是否存在
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "❌ 错误: 找不到主脚本 $MAIN_SCRIPT"
    exit 1
fi

# 创建配置文件，包含初始化设置
sudo tee "$CONFIG_FILE" > /dev/null << 'EOF'
#!/bin/bash
# SSH命令增强记录器 - 配置初始化

# 配置变量
export ENHANCED_HISTORY_ENABLED=1
export ENHANCED_HISTORY_LOG_FILE="${HOME}/.enhanced_history"
export ENHANCED_HISTORY_MAX_SIZE=10485760  # 10MB
export ENHANCED_HISTORY_ARCHIVE_DIR="${HOME}/.enhanced_history_archives"

# 创建必要的目录和文件
mkdir -p "$ENHANCED_HISTORY_ARCHIVE_DIR"
touch "$ENHANCED_HISTORY_LOG_FILE"
chmod 600 "$ENHANCED_HISTORY_LOG_FILE"

# 设置主脚本使用的变量
LOG_FILE="$ENHANCED_HISTORY_LOG_FILE"
MAX_LOG_SIZE="$ENHANCED_HISTORY_MAX_SIZE"
LOG_DIR="$ENHANCED_HISTORY_ARCHIVE_DIR"

# 加载主功能
if [ -f "/etc/profile.d/history_enhancer_main.sh" ]; then
    source "/etc/profile.d/history_enhancer_main.sh"
fi
EOF

# 复制主功能脚本
sudo cp "$MAIN_SCRIPT" "/etc/profile.d/history_enhancer_main.sh"
sudo chmod +x "$CONFIG_FILE" "/etc/profile.d/history_enhancer_main.sh"

# 配置用户环境
if ! grep -q "source $CONFIG_FILE" ~/.bashrc; then
    echo "source $CONFIG_FILE" >> ~/.bashrc
fi

# 创建用户目录结构
mkdir -p ~/.enhanced_history_archives
touch ~/.enhanced_history
chmod 600 ~/.enhanced_history

echo "✓ 安装完成！"
echo "✓ 增强历史记录系统已部署"
echo "✓ 重新登录后生效"
echo ""
echo "使用示例:"
echo "  enhistory                    # 查看当前会话历史"
echo "  enhistory --all              # 查看所有历史记录"
echo "  enhistory --since 2025-11-13 # 查看指定日期之后的记录"
echo "  enhistory --from \"2025-11-01 13:35\" --to \"2025-11-13 21:00\" # 查看时间范围记录"