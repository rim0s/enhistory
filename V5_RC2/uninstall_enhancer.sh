#!/bin/bash
# History Enhancer Uninstaller v1.1 - 修复日志文件清理

set -e

# 配置路径
CONFIG_FILE="/etc/profile.d/history_enhancer.sh"
MAIN_SCRIPT="/etc/profile.d/history_enhancer_main.sh"
INTERFACE_MODULE="/etc/profile.d/db_transcriber_interface.sh"
USER_BASHRC="${HOME}/.bashrc"
BACKUP_DIR="${HOME}/.enhanced_history_backup"
LOG_FILE="${HOME}/.enhanced_history_log"  # 添加日志文件路径

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示用法
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

卸载增强历史记录系统

OPTIONS:
    --keepdata      保留所有数据文件（日志、归档、数据库）
    --clean-all     删除所有数据文件和配置（不可恢复）
    --help          显示此帮助信息

默认行为（无参数）：
    - 移除系统配置和启动项
    - 保留用户数据文件
    - 显示数据文件位置信息

示例:
    $0                  # 安全卸载，保留数据
    $0 --keepdata       # 明确保留数据
    $0 --clean-all      # 完全清除所有痕迹
EOF
}

# 输出彩色信息
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "请不要使用root权限运行卸载脚本"
        exit 1
    fi
}

# 备份数据（如果需要）
backup_data() {
    local backup_name="enhanced_history_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    mkdir -p "$backup_path"
    info "创建数据备份到: $backup_path"
    
    # 备份日志文件
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$backup_path/" 2>/dev/null || true
        info "已备份: $LOG_FILE"
    fi
    
    # 备份归档目录
    if [ -d "${HOME}/.enhanced_history_archives" ]; then
        cp -r "${HOME}/.enhanced_history_archives" "$backup_path/" 2>/dev/null || true
        info "已备份: ${HOME}/.enhanced_history_archives/"
    fi
    
    # 备份数据库配置和数据
    if [ -d "${HOME}/.enhanced_history" ]; then
        cp -r "${HOME}/.enhanced_history" "$backup_path/config_backup" 2>/dev/null || true
        info "已备份: ${HOME}/.enhanced_history/"
    fi
}

# 移除系统配置
remove_system_config() {
    info "移除系统配置..."
    
    # 移除主配置文件
    if [ -f "$CONFIG_FILE" ]; then
        sudo rm -f "$CONFIG_FILE"
        info "已移除: $CONFIG_FILE"
    fi
    
    # 移除主脚本
    if [ -f "$MAIN_SCRIPT" ]; then
        sudo rm -f "$MAIN_SCRIPT"
        info "已移除: $MAIN_SCRIPT"
    fi
    
    # 移除接口模块
    if [ -f "$INTERFACE_MODULE" ]; then
        sudo rm -f "$INTERFACE_MODULE"
        info "已移除: $INTERFACE_MODULE"
    fi
    
    # 从.bashrc中移除source行
    if [ -f "$USER_BASHRC" ]; then
        if grep -q "source $CONFIG_FILE" "$USER_BASHRC"; then
            sed -i "\|source $CONFIG_FILE|d" "$USER_BASHRC"
            info "已从 ~/.bashrc 中移除启动项"
        fi
    fi
}

# 保留数据文件
keep_data_files() {
    info "保留数据文件..."
    cat << EOF

以下数据文件被保留：
  - 主日志文件: $LOG_FILE
  - 归档目录: ${HOME}/.enhanced_history_archives/
  - 配置和数据: ${HOME}/.enhanced_history/

您可以在以后手动删除这些文件，或使用 --clean-all 选项立即删除。
EOF
}

# 完全清理数据文件
clean_all_data() {
    info "清理所有数据文件..."
    
    # 确认操作
    echo
    warn "这将永久删除所有增强历史记录数据！"
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "操作已取消"
        exit 0
    fi
    
    # 备份后再删除
    backup_data
    
    # 删除主日志文件
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        info "已删除: $LOG_FILE"
    fi
    
    # 删除归档目录
    if [ -d "${HOME}/.enhanced_history_archives" ]; then
        rm -rf "${HOME}/.enhanced_history_archives"
        info "已删除: ${HOME}/.enhanced_history_archives/"
    fi
    
    # 删除配置和数据目录
    if [ -d "${HOME}/.enhanced_history" ]; then
        rm -rf "${HOME}/.enhanced_history"
        info "已删除: ${HOME}/.enhanced_history/"
    fi
    
    # 清理备份目录（如果为空）
    if [ -d "$BACKUP_DIR" ] && [ -z "$(ls -A "$BACKUP_DIR")" ]; then
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    fi
}

# 显示数据文件信息
show_data_info() {
    cat << EOF

增强历史记录数据文件位置：
  📝 主日志文件: $LOG_FILE
  📦 归档文件: ${HOME}/.enhanced_history_archives/
  ⚙️  配置数据: ${HOME}/.enhanced_history/
  💾 卸载备份: ${BACKUP_DIR}/

如需重新安装，可以运行安装脚本。
EOF
}

# 主卸载流程
main() {
    check_root
    
    local action="default"
    
    # 解析参数
    case "${1:-}" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --keepdata)
            action="keepdata"
            ;;
        --clean-all)
            action="cleanall"
            ;;
        "")
            action="default"
            ;;
        *)
            error "未知参数: $1"
            show_usage
            exit 1
            ;;
    esac
    
    echo "=== 增强历史记录系统卸载程序 ==="
    echo
    
    # 检查是否已安装
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$MAIN_SCRIPT" ]; then
        warn "未检测到已安装的增强历史记录系统"
    fi
    
    # 执行卸载操作
    case "$action" in
        "default")
            info "执行安全卸载（保留数据）..."
            remove_system_config
            show_data_info
            ;;
        "keepdata")
            info "执行卸载并保留数据..."
            remove_system_config
            keep_data_files
            ;;
        "cleanall")
            info "执行完全卸载..."
            remove_system_config
            clean_all_data
            ;;
    esac
    
    echo
    info "卸载完成！"
    
    # 提示用户
    if [[ "$action" != "cleanall" ]]; then
        echo
        info "请注意：当前shell会话中可能仍有历史记录功能在运行。"
        info "请重新登录或开启新的shell会话以使更改生效。"
    fi
}

# 运行主函数
main "$@"
