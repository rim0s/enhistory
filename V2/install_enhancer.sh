bin/bash
# History Enhancer Installer v2.1

CONFIG_FILE="/etc/profile.d/history_enhancer.sh"

echo "▶ 正在部署SSH历史记录增强系统..."
sudo cp history_enhancer.sh "$CONFIG_FILE"
sudo chmod +x "$CONFIG_FILE"

if ! grep -q "source $CONFIG_FILE" ~/.bashrc; then
    echo "source $CONFIG_FILE" >> ~/.bashrc
fi

echo "✓ 安装完成！重新登录后生效"
echo "使用命令查看增强历史记录: enhistory"

