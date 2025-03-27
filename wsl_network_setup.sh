#!/bin/bash

# 定义颜色
BOLD="\e[1m"
NORMAL="\e[0m"
SUCCESS_COLOR='\e[1;32m'
WARNING_COLOR='\e[1;33m'
ERROR_COLOR='\e[1;31m'
INFO_COLOR='\e[1;36m'

# 显示函数
display_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${ERROR_COLOR}${BOLD}❌ 错误: ${message}${NORMAL}"
            ;;
        "warning")
            echo -e "${WARNING_COLOR}${BOLD}⚠️ 警告: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${SUCCESS_COLOR}${BOLD}✅ 成功: ${message}${NORMAL}"
            ;;
        "info")
            echo -e "${INFO_COLOR}${BOLD}ℹ️ 信息: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# 检查是否在WSL环境中
if ! grep -q "microsoft\|Microsoft" /proc/version 2>/dev/null; then
    display_status "此脚本只能在WSL环境中运行" "error"
    exit 1
fi

display_status "WSL网络配置工具" "info"
echo "此脚本将自动配置Windows主机上的端口转发，使外部网络能够访问WSL中的Dria节点。"
echo ""

# 检查是否有管理员权限
if [[ $EUID -ne 0 ]]; then
    display_status "请以root权限运行此脚本 (sudo $0)" "error"
    exit 1
fi

# 获取WSL的IP地址
WSL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$WSL_IP" ]; then
    display_status "无法获取WSL IP地址" "error"
    exit 1
fi

display_status "WSL IP地址: $WSL_IP" "info"

# 获取Windows主机IP
WIN_HOST_IP=$(ip route | grep default | awk '{print $3}')
if [ -z "$WIN_HOST_IP" ]; then
    display_status "无法获取Windows主机IP地址" "error"
    exit 1
fi

display_status "Windows主机IP: $WIN_HOST_IP" "info"

# 创建临时PowerShell脚本
TEMP_PS1="/tmp/wsl_network_setup_$(date +%s).ps1"

cat > "$TEMP_PS1" << EOF
# 设置端口转发
\$wslIP = "$WSL_IP"
Write-Host "配置端口转发: 外部 -> \$wslIP"

# 检查并删除已有的端口转发
Write-Host "正在检查并清除现有端口转发..."
netsh interface portproxy show v4tov4 | ForEach-Object {
    if (\$_ -match "4001|1337|11434") {
        \$parts = \$_ -split "\s+"
        if (\$parts.Count -ge 3) {
            \$listenPort = \$parts[1]
            netsh interface portproxy delete v4tov4 listenport=\$listenPort listenaddress=0.0.0.0
        }
    }
}

# 添加新的端口转发
Write-Host "添加新的端口转发规则..."
netsh interface portproxy add v4tov4 listenport=4001 listenaddress=0.0.0.0 connectport=4001 connectaddress=\$wslIP
netsh interface portproxy add v4tov4 listenport=1337 listenaddress=0.0.0.0 connectport=1337 connectaddress=\$wslIP
netsh interface portproxy add v4tov4 listenport=11434 listenaddress=0.0.0.0 connectport=11434 connectaddress=\$wslIP

# 添加Windows防火墙规则
Write-Host "添加Windows防火墙规则..."
New-NetFirewallRule -DisplayName "WSL-Dria-4001-TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4001 -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WSL-Dria-4001-UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 4001 -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WSL-Dria-1337-TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1337 -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WSL-Dria-11434-TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 11434 -ErrorAction SilentlyContinue

# 显示端口转发配置
Write-Host "当前端口转发配置:"
netsh interface portproxy show v4tov4
EOF

display_status "创建PowerShell脚本: $TEMP_PS1" "success"

# 检测可用的Windows PowerShell路径
POWERSHELL_EXE=""
if command -v powershell.exe &>/dev/null; then
    POWERSHELL_EXE="powershell.exe"
elif [ -f "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]; then
    POWERSHELL_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
elif [ -f "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]; then
    POWERSHELL_EXE="/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
else
    display_status "无法找到Windows PowerShell可执行文件" "error"
    echo "请手动复制以下脚本到Windows PowerShell(管理员)中运行:"
    echo "-----------------------------------------------------------"
    cat "$TEMP_PS1"
    echo "-----------------------------------------------------------"
    exit 1
fi

# 将路径转换为Windows格式
WIN_PS1_PATH=$(wslpath -w "$TEMP_PS1")

display_status "尝试自动执行PowerShell脚本..." "info"
echo "注意: 如果出现UAC提示，请点击'是'授予管理员权限"
echo ""

# 创建提升权限的批处理文件
TEMP_BAT="/tmp/run_as_admin_$(date +%s).bat"
cat > "$TEMP_BAT" << EOF
@echo off
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"$WIN_PS1_PATH\"' -Verb RunAs"
EOF

# 转换为Windows路径
WIN_BAT_PATH=$(wslpath -w "$TEMP_BAT")

# 使用cmd.exe运行批处理文件
cmd.exe /c "$WIN_BAT_PATH"

display_status "已请求以管理员身份运行PowerShell脚本" "info"
echo "如果您在Windows中看到了UAC提示，请确认以允许脚本运行。"
echo "请等待PowerShell窗口完成配置后关闭。"
echo ""

# 配置防火墙和服务
display_status "配置WSL内部防火墙和服务..." "info"

# 检查并安装防火墙
if ! command -v ufw &>/dev/null; then
    apt update
    apt install -y ufw
fi

# 配置防火墙规则
ufw allow 4001/tcp
ufw allow 4001/udp
ufw allow 1337/tcp
ufw allow 11434/tcp

# 如果防火墙未启用，提示用户
if ! ufw status | grep -q "Status: active"; then
    display_status "防火墙未启用，建议启用: sudo ufw enable" "warning"
fi

# 配置Dria网络
mkdir -p "$HOME/.dria" 2>/dev/null

# 创建优化的网络配置
cat > "$HOME/.dria/network_config.json" << EOF
{
  "libp2p": {
    "listen_addresses": [
      "/ip4/0.0.0.0/tcp/4001",
      "/ip4/0.0.0.0/udp/4001/quic-v1"
    ],
    "external_addresses": [],
    "bootstrap_peers": [
      "/dns4/node1.dria.co/tcp/4001/p2p/16Uiu2HAmCj9DuTQgzepxfKP1byDZoQbfkh4ZoQGihHEL1fuof3FJ",
      "/dns4/node2.dria.co/tcp/4001/p2p/16Uiu2HAm9fQCDYwmkDCNtb5XZC5p8dUcHpvN9JMPeA9wJMndRPMw",
      "/dns4/node3.dria.co/tcp/4001/p2p/16Uiu2HAmVg8DxJ2MwAwQwA6Fj8fgbYBRqsTu3KAaWhq7Z7eMAKBL",
      "/dns4/node4.dria.co/tcp/4001/p2p/16Uiu2HAmAkVoCpUHyZaXSddzByWMvYyR7ekCDJsM19mYHfMebYQQ",
      "/dns4/node5.dria.co/tcp/4001/p2p/16Uiu2HAm1xBHVUCGjyiz8iakVoDR1qjj3bJT2ZYbPLyVTHX1pxKF"
    ],
    "connection_idle_timeout": 120,
    "enable_relay": true,
    "relay_discovery": true,
    "direct_connection_timeout_ms": 10000,
    "relay_connection_timeout_ms": 30000
  }
}
EOF

# 创建优化的启动脚本
cat > "$HOME/.dria/start_with_optimized_network.sh" << 'EOF'
#!/bin/bash

# 配置WSL网络环境
WIN_HOST_IP=$(ip route | grep default | awk '{print $3}')
echo "Windows主机IP: $WIN_HOST_IP"

# 检查网络连接
echo "检查网络连接..."
if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    echo "网络连接异常，尝试修复..."
    # 重置DNS
    echo "nameserver $WIN_HOST_IP" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
fi

# 使用优化配置启动Dria节点
echo "使用优化配置启动Dria节点..."
dkn-compute-launcher start -c "$HOME/.dria/network_config.json" $@
EOF

chmod +x "$HOME/.dria/start_with_optimized_network.sh"

# 创建启动服务
cat > /etc/systemd/system/dria-node.service << EOF
[Unit]
Description=Dria Compute Node
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=$HOME/.dria/start_with_optimized_network.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用系统服务
systemctl daemon-reload
systemctl enable dria-node.service

# 添加快捷命令
if ! grep -q "dria-optimized" "$HOME/.bashrc"; then
    echo "alias dria-optimized='$HOME/.dria/start_with_optimized_network.sh'" >> "$HOME/.bashrc"
fi

# 创建一个自动重启脚本
cat > /usr/local/bin/dria-restart << 'EOF'
#!/bin/bash
systemctl restart dria-node.service
echo "Dria节点已重启"
EOF
chmod +x /usr/local/bin/dria-restart

display_status "WSL网络配置完成" "success"
echo ""
echo "您可以通过以下命令管理Dria节点:"
echo "1. 开始节点: systemctl start dria-node"
echo "2. 停止节点: systemctl stop dria-node"
echo "3. 重启节点: dria-restart"
echo "4. 检查状态: systemctl status dria-node"
echo "5. 手动启动: dria-optimized"
echo ""
display_status "每次重启Windows或WSL后，请重新运行此脚本以更新端口转发" "warning"
echo "Windows主机IP可能会在重启后发生变化" 