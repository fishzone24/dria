#!/bin/bash

# 检查是否在WSL环境中
if ! grep -q "microsoft" /proc/version 2>/dev/null && ! grep -q "Microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "此脚本仅适用于WSL环境"
    exit 1
fi

echo "开始WSL网络修复..."

# 停止现有服务
systemctl stop dria-node 2>/dev/null
pkill -f dkn-compute-launcher
sleep 2

# 获取Windows主机IP
WIN_HOST_IP=$(ip route | grep default | awk '{print $3}')
if [ -z "$WIN_HOST_IP" ]; then
    echo "无法获取Windows主机IP"
    exit 1
fi

# 修复DNS配置
echo "修复DNS配置..."
echo "nameserver $WIN_HOST_IP" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 添加hosts映射
if ! grep -q "node1.dria.co" /etc/hosts; then
    echo "添加节点IP映射..."
    cat >> /etc/hosts << 'HOSTS'
# Dria节点IP映射
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
HOSTS
fi

# 获取WSL IP
WSL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$WSL_IP" ]; then
    echo "无法获取WSL IP"
    exit 1
fi

# 创建优化的网络配置
echo "创建优化的网络配置..."
mkdir -p /root/.dria
cat > /root/.dria/settings.json << EOL
{
    "network": {
        "connection_timeout": 300,
        "direct_connection_timeout": 20000,
        "relay_connection_timeout": 60000,
        "bootstrap_nodes": [
            "/ip4/34.145.16.76/tcp/4001/p2p/QmXZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV",
            "/ip4/34.42.109.93/tcp/4001/p2p/QmYZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV",
            "/ip4/34.42.43.172/tcp/4001/p2p/QmZZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV",
            "/ip4/35.200.247.78/tcp/4001/p2p/QmWZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV",
            "/ip4/34.92.171.75/tcp/4001/p2p/QmVZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV"
        ],
        "listen_addresses": [
            "/ip4/0.0.0.0/tcp/4001",
            "/ip4/0.0.0.0/udp/4001/quic-v1"
        ],
        "external_addresses": [
            "/ip4/$WSL_IP/tcp/4001",
            "/ip4/$WSL_IP/udp/4001/quic-v1"
        ],
        "enable_relay": true,
        "relay_discovery": true,
        "relay_connection_timeout_ms": 60000,
        "direct_connection_timeout_ms": 20000
    }
}
EOL

# 创建Windows端口转发脚本
echo "创建Windows端口转发脚本..."
cat > /tmp/setup_port_forward.ps1 << EOL
# 删除现有的端口转发规则
netsh interface portproxy delete v4tov4 listenport=4001 listenaddress=0.0.0.0
netsh interface portproxy delete v4tov4 listenport=1337 listenaddress=0.0.0.0
netsh interface portproxy delete v4tov4 listenport=11434 listenaddress=0.0.0.0

# 添加新的端口转发规则
netsh interface portproxy add v4tov4 listenport=4001 listenaddress=0.0.0.0 connectport=4001 connectaddress=$WSL_IP
netsh interface portproxy add v4tov4 listenport=1337 listenaddress=0.0.0.0 connectport=1337 connectaddress=$WSL_IP
netsh interface portproxy add v4tov4 listenport=11434 listenaddress=0.0.0.0 connectport=11434 connectaddress=$WSL_IP

# 添加Windows防火墙规则
New-NetFirewallRule -DisplayName "WSL-Dria-4001" -Direction Inbound -Action Allow -Protocol TCP,UDP -LocalPort 4001
New-NetFirewallRule -DisplayName "WSL-Dria-1337" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1337
New-NetFirewallRule -DisplayName "WSL-Dria-11434" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 11434
EOL

# 尝试在Windows中执行PowerShell脚本
if command -v powershell.exe &> /dev/null; then
    echo "正在配置Windows端口转发..."
    powershell.exe -ExecutionPolicy Bypass -File /tmp/setup_port_forward.ps1
else
    echo "无法自动执行Windows配置，请手动运行以下PowerShell命令："
    cat /tmp/setup_port_forward.ps1
fi

# 启动节点
echo "启动Dria节点..."
export DKN_LOG=debug
dkn-compute-launcher start

echo "WSL网络修复完成" 