@echo off
echo 正在执行WSL网络修复...

REM 检查是否在WSL环境中
wsl -e grep -q "microsoft" /proc/version 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo 错误：此脚本需要在WSL环境中运行
    pause
    exit /b 1
)

REM 停止现有服务
wsl -e sudo systemctl stop dria-node 2>nul
wsl -e sudo pkill -f dkn-compute-launcher
timeout /t 2 /nobreak >nul

REM 修复DNS配置
echo 修复DNS配置...
wsl -e sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
wsl -e sudo bash -c "echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"

REM 添加hosts映射
wsl -e sudo bash -c "if ! grep -q 'node1.dria.co' /etc/hosts; then echo '# Dria节点IP映射' >> /etc/hosts && echo '34.145.16.76 node1.dria.co' >> /etc/hosts && echo '34.42.109.93 node2.dria.co' >> /etc/hosts && echo '34.42.43.172 node3.dria.co' >> /etc/hosts && echo '35.200.247.78 node4.dria.co' >> /etc/hosts && echo '34.92.171.75 node5.dria.co' >> /etc/hosts; fi"

REM 获取WSL IP
for /f "tokens=*" %%i in ('wsl -e hostname -I ^| awk "{print \$1}"') do set WSL_IP=%%i

REM 创建优化的网络配置
echo 创建优化的网络配置...
wsl -e sudo mkdir -p /root/.dria
wsl -e sudo bash -c "cat > /root/.dria/settings.json << 'EOL'
{
    \"network\": {
        \"connection_timeout\": 300,
        \"direct_connection_timeout\": 20000,
        \"relay_connection_timeout\": 60000,
        \"bootstrap_nodes\": [
            \"/ip4/34.145.16.76/tcp/4001/p2p/QmXZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV\",
            \"/ip4/34.42.109.93/tcp/4001/p2p/QmYZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV\",
            \"/ip4/34.42.43.172/tcp/4001/p2p/QmZZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV\",
            \"/ip4/35.200.247.78/tcp/4001/p2p/QmWZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV\",
            \"/ip4/34.92.171.75/tcp/4001/p2p/QmVZXGXXXNo1Xmgq2BxeSveaWfcytVD1Y9z5L2iSrHqGdV\"
        ],
        \"listen_addresses\": [
            \"/ip4/0.0.0.0/tcp/4001\",
            \"/ip4/0.0.0.0/udp/4001/quic-v1\"
        ],
        \"external_addresses\": [
            \"/ip4/%WSL_IP%/tcp/4001\",
            \"/ip4/%WSL_IP%/udp/4001/quic-v1\"
        ],
        \"enable_relay\": true,
        \"relay_discovery\": true,
        \"relay_connection_timeout_ms\": 60000,
        \"direct_connection_timeout_ms\": 20000
    }
}
EOL"

REM 配置Windows端口转发
echo 配置Windows端口转发...
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -Command \"netsh interface portproxy delete v4tov4 listenport=4001 listenaddress=0.0.0.0; netsh interface portproxy delete v4tov4 listenport=1337 listenaddress=0.0.0.0; netsh interface portproxy delete v4tov4 listenport=11434 listenaddress=0.0.0.0; netsh interface portproxy add v4tov4 listenport=4001 listenaddress=0.0.0.0 connectport=4001 connectaddress=%WSL_IP%; netsh interface portproxy add v4tov4 listenport=1337 listenaddress=0.0.0.0 connectport=1337 connectaddress=%WSL_IP%; netsh interface portproxy add v4tov4 listenport=11434 listenaddress=0.0.0.0 connectport=11434 connectaddress=%WSL_IP%\"'"

REM 配置Windows防火墙
echo 配置Windows防火墙...
powershell -Command "Start-Process powershell -Verb RunAs -Command \"New-NetFirewallRule -DisplayName 'WSL-Dria-4001' -Direction Inbound -Action Allow -Protocol TCP,UDP -LocalPort 4001; New-NetFirewallRule -DisplayName 'WSL-Dria-1337' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1337; New-NetFirewallRule -DisplayName 'WSL-Dria-11434' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 11434\""

REM 启动节点
echo 启动Dria节点...
wsl -e sudo bash -c "export DKN_LOG=debug && dkn-compute-launcher start"

echo WSL网络修复完成
pause 