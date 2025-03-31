#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# 加粗样式
BOLD='\033[1m'

# 菜单颜色
MENU_COLOR="${CYAN}${BOLD}"
NORMAL="${RESET}"

# 署名和说明
cat << "EOF"

   __   _         _                                    ___    _  _   
  / _| (_)       | |                                  |__ \  | || |  
 | |_   _   ___  | |__    ____   ___    _ __     ___     ) | | || |_ 
 |  _| | | / __| | '_ \  |_  /  / _ \  | '_ \   / _ \   / /  |__   _|
 | |   | | \__ \ | | | |  / /  | (_) | | | | | |  __/  / /_     | |  
 |_|   |_| |___/ |_| |_| /___|  \___/  |_| |_|  \___| |____|    |_|  
                                                                     
                                                                     

                                                                                                                                  

EOF
echo -e "${BLUE}==================================================================${RESET}"
echo -e "${GREEN}Dria 节点一键管理脚本${RESET}"
echo -e "${YELLOW}脚本作者: fishzone24 - 推特: https://x.com/fishzone24${RESET}"
echo -e "${YELLOW}此脚本为免费开源脚本，如有问题请提交 issue${RESET}"
echo -e "${BLUE}==================================================================${RESET}"

# 初始化设置和变量

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
WARNING_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'
MENU_COLOR='\033[1;34m'

# 检测是否在WSL环境中运行
check_wsl() {
    if grep -q "microsoft" /proc/version 2>/dev/null || grep -q "Microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
        echo "wsl"
    else
        echo "native"
    fi
}

# 运行环境
ENV_TYPE=$(check_wsl)

# 自定义状态显示函数
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

# 确保脚本以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
    display_status "请以 root 用户权限运行此脚本 (sudo -i)" "error"
    exit 1
fi

# 确保脚本有执行权限
chmod +x "$0"

# Ollama Docker修复函数
fix_ollama_docker() {
    display_status "Ollama Docker环境修复工具" "info"
    
    # 检查Docker是否运行
    if ! docker ps &>/dev/null; then
        display_status "Docker服务未运行" "error"
        return 1
    fi
    
    # 检查Ollama容器是否运行
    if ! docker ps | grep -q "ollama"; then
        display_status "未检测到运行中的Ollama容器" "error"
        return 1
    fi
    
    # 创建必要的目录结构
    display_status "创建Ollama必要目录..." "info"
    mkdir -p /root/.ollama/models
    chmod -R 755 /root/.ollama
    chown -R root:root /root/.ollama
    
    # 获取Ollama容器ID
    OLLAMA_CONTAINER=$(docker ps | grep ollama | awk '{print $1}')
    
    if [ -z "$OLLAMA_CONTAINER" ]; then
        display_status "无法获取Ollama容器ID" "error"
        return 1
    fi
    
    display_status "检测到Ollama容器: $OLLAMA_CONTAINER" "info"
    
    # 创建临时脚本
    cat > /tmp/fix_ollama.sh << 'EOF'
#!/bin/bash
mkdir -p /root/.ollama/models
chmod -R 755 /root/.ollama
chown -R root:root /root/.ollama
EOF
    chmod +x /tmp/fix_ollama.sh
    
    # 将脚本复制到容器内并执行
    display_status "在Ollama容器内执行修复..." "info"
    docker cp /tmp/fix_ollama.sh $OLLAMA_CONTAINER:/tmp/
    docker exec $OLLAMA_CONTAINER /bin/bash /tmp/fix_ollama.sh
    
    # 重启Ollama容器
    display_status "重启Ollama容器..." "info"
    docker restart $OLLAMA_CONTAINER
    
    # 等待Ollama服务重新启动
    sleep 5
    
    # 检查Ollama服务是否正常
    if curl -s http://localhost:11434/api/tags >/dev/null; then
        display_status "Ollama服务已恢复正常" "success"
    else
        display_status "Ollama服务可能仍有问题，请检查Docker日志" "warning"
        echo "可以使用以下命令查看日志："
        echo "docker logs $OLLAMA_CONTAINER"
    fi
    
    # 清理临时文件
    rm -f /tmp/fix_ollama.sh
    
    return 0
}

# 更新系统并安装依赖项
setup_prerequisites() {
    display_status "检查并安装所需的系统依赖项..." "info"
    export DEBIAN_FRONTEND=noninteractive
    apt update -y && apt upgrade -y
    
    # 在WSL中可能不需要做完整的dist-upgrade，可能会导致问题
    if [ "$ENV_TYPE" = "native" ]; then
        apt-get dist-upgrade -y
    else
        display_status "WSL环境检测到，跳过dist-upgrade以避免潜在问题" "info"
    fi
    
    apt autoremove -y

    local dependencies=("curl" "ca-certificates" "gnupg" "wget" "unzip")
    for package in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii\s\+$package"; then
            display_status "正在安装 $package..." "info"
            apt install -y $package
        else
            display_status "$package 已经安装，跳过。" "success"
        fi
    done
}

# 安装 Docker 环境
install_docker() {
    if command -v docker &> /dev/null; then
        # 检查Docker是否正常运行
        if ! docker info &>/dev/null; then
            if [ "$ENV_TYPE" = "wsl" ]; then
                display_status "WSL环境中Docker服务未启动，正在尝试启动..." "warning"
                sudo service docker start || sudo /etc/init.d/docker start || {
                    display_status "无法启动Docker服务，请检查WSL配置，可能需要手动执行以下命令:" "error"
                    echo "sudo service docker start"
                    echo "如果问题持续，可能需要在Windows PowerShell中执行: wsl --shutdown 后重新启动WSL"
                    read -n 1 -s -r -p "按任意键继续..."
                    return 1
                }
                # 等待Docker服务启动
                sleep 3
                # 再次检查Docker状态
                if ! docker info &>/dev/null; then
                    display_status "Docker服务启动失败，请尝试重启WSL或检查Docker安装" "error"
                    return 1
                fi
            else
                display_status "Docker服务未启动，正在尝试启动..." "warning"
                systemctl start docker || {
                    display_status "无法启动Docker服务，请检查系统日志" "error"
                    return 1
                }
            fi
        fi
        display_status "检测到 Docker 已安装，跳过安装步骤。" "success"
        docker --version
        return
    fi

    display_status "正在安装 Docker..." "info"
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        apt-get remove -y $pkg 2>/dev/null
    done

    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 获取Ubuntu版本
    . /etc/os-release
    
    # 在某些WSL环境中，VERSION_CODENAME可能不存在或不正确
    if [ -z "$VERSION_CODENAME" ] || [ "$ENV_TYPE" = "wsl" ]; then
        VERSION_CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")
        display_status "使用版本代号: $VERSION_CODENAME" "info"
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update -y && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 在WSL中启动Docker服务
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "WSL环境检测到，正在启动Docker服务..." "info"
        
        # 添加当前用户到docker组（如果不是root用户）
        if [[ $EUID -ne 0 ]] && id -u "$USER" &>/dev/null; then
            usermod -aG docker "$USER"
            display_status "添加用户 $USER 到docker组" "info"
        fi
        
        # 尝试多种方式启动Docker
        service docker start || /etc/init.d/docker start || {
            display_status "无法启动Docker服务，请检查WSL配置" "error"
            display_status "WSL环境中可能需要手动设置Docker，推荐以下步骤:" "warning"
            echo "1. 在Windows PowerShell中执行: wsl --shutdown"
            echo "2. 重新打开WSL终端"
            echo "3. 执行: sudo service docker start"
            return 1
        }
        
        # 等待Docker服务启动
        sleep 3
        # 检查Docker是否成功启动
        if ! docker info &>/dev/null; then
            display_status "Docker安装成功但服务未能自动启动" "warning"
            display_status "请尝试手动启动Docker: sudo service docker start" "info"
            return 1
        fi
    fi

    docker --version && display_status "Docker 安装成功。" "success" || display_status "Docker 安装失败。" "error"
}

# 安装 Ollama
install_ollama() {
    display_status "正在安装 Ollama..." "info"
    
    # 创建并设置Ollama目录权限
    setup_ollama_dirs() {
        display_status "设置Ollama目录权限..." "info"
        mkdir -p /root/.ollama/models
        chown -R root:root /root/.ollama
        chmod -R 755 /root/.ollama
        display_status "Ollama目录权限设置完成" "success"
    }
    
    # 检查是否在WSL环境中
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "WSL环境检测到，正在使用特定的Ollama安装方法..." "info"
        
        # 临时目录
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR" || {
            display_status "无法创建临时目录" "error"
            return 1
        }
        
        # 下载Ollama二进制文件
        display_status "下载Ollama..." "info"
        wget -q https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64 -O ollama || {
            display_status "无法下载Ollama二进制文件" "error"
            return 1
        }
        
        # 设置可执行权限
        chmod +x ollama
        
        # 移动到系统路径
        mv ollama /usr/local/bin/
        
        # 设置目录权限
        setup_ollama_dirs
        
        # 清理临时目录
        cd "$HOME"
        rm -rf "$TMP_DIR"
        
        display_status "Ollama 安装成功。请手动运行 'ollama serve' 来启动Ollama服务。" "success"
    else
        # 标准安装方法
        curl -fsSL https://ollama.com/install.sh | sh
        if [ $? -eq 0 ]; then
            # 设置目录权限
            setup_ollama_dirs
            display_status "Ollama 安装成功。" "success"
        else
            display_status "Ollama 安装失败。" "error"
        fi
    fi
}

# 代理设置功能
setup_proxy() {
    display_status "设置网络代理..." "info"
    
    # 检查是否已经设置了代理
    if [ ! -z "$http_proxy" ] || [ ! -z "$https_proxy" ]; then
        display_status "检测到已存在的代理设置:" "info"
        echo "HTTP_PROXY=$http_proxy"
        echo "HTTPS_PROXY=$https_proxy"
        echo "ALL_PROXY=$all_proxy"
        
        read -p "是否保留当前代理设置？(y/n): " keep_proxy
        if [[ $keep_proxy == "y" || $keep_proxy == "Y" ]]; then
            display_status "保留当前代理设置" "success"
            return 0
        fi
    fi
    
    # 在WSL环境中尝试使用Windows宿主机的代理
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "在WSL环境中尝试使用Windows主机代理..." "info"
        
        # 获取WSL宿主机IP地址
        WIN_HOST_IP=$(ip route | grep default | awk '{print $3}')
        
        if [ -z "$WIN_HOST_IP" ]; then
            display_status "无法获取Windows主机IP，将使用127.0.0.1" "warning"
            WIN_HOST_IP="127.0.0.1"
        fi
        
        display_status "检测到Windows主机IP为: $WIN_HOST_IP" "info"
        read -p "请输入代理端口(默认为7890): " proxy_port
        proxy_port=${proxy_port:-7890}
        
        # 设置代理环境变量
        export http_proxy="http://${WIN_HOST_IP}:${proxy_port}"
        export https_proxy="http://${WIN_HOST_IP}:${proxy_port}"
        export all_proxy="socks5://${WIN_HOST_IP}:${proxy_port}"
        
        # 为wget和curl设置代理
        echo "use_proxy=yes" > ~/.wgetrc
        echo "http_proxy=${http_proxy}" >> ~/.wgetrc
        echo "https_proxy=${https_proxy}" >> ~/.wgetrc
        
        echo "proxy=${http_proxy}" > ~/.curlrc
        
        display_status "代理已设置为:" "success"
        echo "HTTP_PROXY=$http_proxy"
        echo "HTTPS_PROXY=$https_proxy"
        echo "ALL_PROXY=$all_proxy"
        
        # 测试代理是否有效
        if curl -s --connect-timeout 5 https://github.com &>/dev/null; then
            display_status "GitHub连接测试成功，代理设置有效" "success"
        else
            display_status "GitHub连接测试失败，请检查代理设置" "warning"
            read -p "是否手动输入代理地址?(y/n): " manual_proxy
            if [[ $manual_proxy == "y" || $manual_proxy == "Y" ]]; then
                read -p "请输入完整的http代理地址(例如: http://127.0.0.1:7890): " custom_proxy
                if [ ! -z "$custom_proxy" ]; then
                    export http_proxy="$custom_proxy"
                    export https_proxy="$custom_proxy"
                    export all_proxy="${custom_proxy/http/socks5}"
                    
                    echo "use_proxy=yes" > ~/.wgetrc
                    echo "http_proxy=${http_proxy}" >> ~/.wgetrc
                    echo "https_proxy=${https_proxy}" >> ~/.wgetrc
                    
                    echo "proxy=${http_proxy}" > ~/.curlrc
                    
                    display_status "代理已手动设置为:" "success"
                    echo "HTTP_PROXY=$http_proxy"
                    echo "HTTPS_PROXY=$https_proxy"
                    echo "ALL_PROXY=$all_proxy"
                fi
            fi
        fi
    else
        # 普通环境中手动输入代理
        read -p "是否需要设置网络代理?(y/n): " need_proxy
        if [[ $need_proxy == "y" || $need_proxy == "Y" ]]; then
            read -p "请输入完整的http代理地址(例如: http://127.0.0.1:7890): " custom_proxy
            if [ ! -z "$custom_proxy" ]; then
                export http_proxy="$custom_proxy"
                export https_proxy="$custom_proxy"
                export all_proxy="${custom_proxy/http/socks5}"
                
                echo "use_proxy=yes" > ~/.wgetrc
                echo "http_proxy=${http_proxy}" >> ~/.wgetrc
                echo "https_proxy=${https_proxy}" >> ~/.wgetrc
                
                echo "proxy=${http_proxy}" > ~/.curlrc
                
                display_status "代理已设置为:" "success"
                echo "HTTP_PROXY=$http_proxy"
                echo "HTTPS_PROXY=$https_proxy"
                echo "ALL_PROXY=$all_proxy"
            fi
        fi
    fi
}

# 清除代理设置
clear_proxy() {
    unset http_proxy
    unset https_proxy
    unset all_proxy
    rm -f ~/.wgetrc ~/.curlrc
    display_status "代理设置已清除" "info"
}

# 添加DNS修复功能
fix_wsl_dns() {
    display_status "WSL DNS修复工具" "info"
    echo "检测到DNS解析问题，正在修复..."
    
    # 备份当前resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    
    # 修复DNS配置
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    
    # 添加Dria节点到hosts文件
    if ! grep -q "node1.dria.co" /etc/hosts; then
        display_status "添加Dria节点IP映射到hosts文件" "info"
        cat >> /etc/hosts << 'EOF'
# Dria节点IP映射
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
EOF
    fi
    
    # 创建DNS修复脚本，用于系统启动时自动修复
    cat > /usr/local/bin/fix-dns.sh << 'EOF'
#!/bin/bash
echo "正在修复DNS配置..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 确保hosts文件包含Dria节点
if ! grep -q "node1.dria.co" /etc/hosts; then
    cat >> /etc/hosts << 'HOSTS'
# Dria节点IP映射
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
HOSTS
fi
echo "DNS配置已更新!"
EOF
    chmod +x /usr/local/bin/fix-dns.sh
    
    # 添加到rc.local以便开机自动运行
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/bash' > /etc/rc.local
        chmod +x /etc/rc.local
    fi
    
    if ! grep -q "fix-dns.sh" /etc/rc.local; then
        echo "/usr/local/bin/fix-dns.sh" >> /etc/rc.local
    fi
    
    # 测试DNS是否修复成功
    display_status "测试DNS配置" "info"
    if ping -c 1 -W 2 node1.dria.co &>/dev/null; then
        display_status "DNS修复成功！可以正常解析node1.dria.co" "success"
    else
        display_status "DNS问题仍然存在，但已添加hosts映射" "warning"
    fi
    
    return 0
}

# 网络诊断和修复函数
diagnose_network() {
    display_status "开始网络诊断..." "info"
    
    # 检查防火墙状态
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            display_status "检测到防火墙已启用，正在检查端口..." "warning"
            # 检查必要的端口
            for port in 4001 1337 11434; do
                if ! ufw status | grep -q "$port"; then
                    display_status "端口 $port 未开放，正在添加规则..." "info"
                    ufw allow $port/tcp
                    ufw allow $port/udp
                fi
            done
        fi
    fi
    
    # 检查系统DNS配置
    if [ ! -f "/etc/resolv.conf" ] || ! grep -q "nameserver 8.8.8.8" "/etc/resolv.conf"; then
        display_status "正在优化DNS配置..." "info"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi
    
    # 检查hosts文件
    if ! grep -q "node1.dria.co" "/etc/hosts"; then
        display_status "正在添加Dria节点IP映射..." "info"
        cat >> /etc/hosts << EOF
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
EOF
    fi
    
    # 检查Docker网络
    if command -v docker &> /dev/null; then
        display_status "正在检查Docker网络配置..." "info"
        docker network prune -f
        docker system prune -f
    fi
    
    display_status "网络诊断完成" "success"
}

# 检查并配置防火墙
check_and_configure_firewall() {
    display_status "检查防火墙配置..." "info"
    
    # 检查端口是否被占用
    check_port() {
        local port=$1
        local protocol=$2
        if netstat -tuln | grep -q ":$port "; then
            echo "端口 $port ($protocol) 已被占用"
            return 1
        fi
        return 0
    }
    
    # 安装必要的工具
    if ! command -v netstat &> /dev/null; then
        display_status "安装网络工具..." "info"
        apt-get update
        apt-get install -y net-tools
    fi
    
    # 检查并安装UFW
    if ! command -v ufw &> /dev/null; then
        display_status "安装UFW防火墙..." "info"
        apt-get update
        apt-get install -y ufw
    fi
    
    # 检查并安装iptables
    if ! command -v iptables &> /dev/null; then
        display_status "安装iptables..." "info"
        apt-get update
        apt-get install -y iptables
    fi
    
    # 检查端口占用情况
    display_status "检查端口占用情况..." "info"
    for port in 4001 1337 11434; do
        if ! check_port $port "TCP"; then
            display_status "端口 $port 已被占用，正在尝试释放..." "warning"
            # 查找占用端口的进程
            pid=$(lsof -i :$port -t)
            if [ ! -z "$pid" ]; then
                echo "正在停止占用端口 $port 的进程 (PID: $pid)"
                kill -9 $pid
                sleep 2
            fi
        fi
    done
    
    # 配置UFW
    display_status "配置UFW防火墙..." "info"
    if command -v ufw &> /dev/null; then
        # 如果UFW未启用，先启用它
        if ! ufw status | grep -q "Status: active"; then
            echo "y" | ufw enable
        fi
        
        # 添加必要的端口规则
        ufw allow 4001/tcp
        ufw allow 4001/udp
        ufw allow 1337/tcp
        ufw allow 11434/tcp
        
        # 重新加载防火墙规则
        ufw reload
    fi
    
    # 配置iptables
    display_status "配置iptables..." "info"
    if command -v iptables &> /dev/null; then
        # 添加必要的端口规则
        iptables -A INPUT -p tcp --dport 4001 -j ACCEPT
        iptables -A INPUT -p udp --dport 4001 -j ACCEPT
        iptables -A INPUT -p tcp --dport 1337 -j ACCEPT
        iptables -A INPUT -p tcp --dport 11434 -j ACCEPT
        
        # 保存iptables规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables.rules
        fi
    fi
    
    # 检查云服务商防火墙
    display_status "检查云服务商防火墙配置..." "info"
    echo "请确保在云服务商控制面板中开放以下端口："
    echo "- TCP 4001"
    echo "- UDP 4001"
    echo "- TCP 1337"
    echo "- TCP 11434"
    
    # 测试端口是否可访问
    display_status "测试端口可访问性..." "info"
    if ! command -v nc &> /dev/null; then
        display_status "安装netcat进行端口测试..." "info"
        apt-get update
        apt-get install -y netcat
    fi
    
    # 测试TCP端口
    for port in 4001 1337 11434; do
        echo "测试TCP端口 $port..."
        if nc -zv localhost $port 2>&1 | grep -q "succeeded"; then
            display_status "TCP端口 $port 开放成功" "success"
        else
            display_status "TCP端口 $port 可能未开放" "warning"
        fi
    done
    
    # 测试UDP端口
    echo "测试UDP端口 4001..."
    if nc -zuv localhost 4001 2>&1 | grep -q "succeeded"; then
        display_status "UDP端口 4001 开放成功" "success"
    else
        display_status "UDP端口 4001 可能未开放" "warning"
    fi
    
    # 显示当前端口状态
    display_status "当前端口状态:" "info"
    netstat -tulpn | grep -E '4001|1337|11434'
    
    # 显示防火墙状态
    if command -v ufw &> /dev/null; then
        display_status "UFW防火墙状态:" "info"
        ufw status
    fi
    
    if command -v iptables &> /dev/null; then
        display_status "iptables规则:" "info"
        iptables -L -n | grep -E '4001|1337|11434'
    fi
    
    display_status "防火墙配置完成" "success"
}

# 创建超级修复工具
create_superfix_tool() {
    display_status "创建超级修复工具" "info"
    
    # 检查并配置防火墙
    check_and_configure_firewall
    
    # 检测运行环境
    if grep -qi "microsoft" /proc/version || grep -qi "microsoft" /proc/sys/kernel/osrelease; then
        display_status "检测到WSL环境" "info"
    else
        display_status "检测到原生Linux环境" "info"
    fi
    
    # 停止现有服务
    systemctl stop dria-node 2>/dev/null
    pkill -f dkn-compute-launcher
    sleep 2
    
    # 清理Docker资源
    if command -v docker &> /dev/null; then
        echo "清理Docker资源..."
        docker network prune -f
        docker system prune -f
        docker container prune -f
    fi
    
    # 修复DNS
    echo "修复DNS配置..."
    if [ "$ENV_TYPE" = "wsl" ]; then
        # WSL环境使用Windows主机作为DNS
        WIN_HOST_IP=$(ip route | grep default | awk '{print $3}')
        if [ ! -z "$WIN_HOST_IP" ]; then
            echo "nameserver $WIN_HOST_IP" > /etc/resolv.conf
        fi
    fi
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
    
    # 创建优化的网络配置
    echo "创建优化的网络配置..."
    mkdir -p /root/.dria
    
    # 获取本机IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="0.0.0.0"
    fi
    
    # 根据环境创建不同的网络配置
    if [ "$ENV_TYPE" = "wsl" ]; then
        # WSL环境配置
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
            "/ip4/$LOCAL_IP/tcp/4001",
            "/ip4/$LOCAL_IP/udp/4001/quic-v1"
        ]
    }
}
EOL
    else
        # 原生Linux环境配置
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
            "/ip4/$LOCAL_IP/tcp/4001",
            "/ip4/$LOCAL_IP/udp/4001/quic-v1"
        ]
    }
}
EOL
    fi
    
    # 检查防火墙
    if command -v ufw &> /dev/null; then
        echo "配置防火墙规则..."
        ufw allow 4001/tcp
        ufw allow 4001/udp
        ufw allow 1337/tcp
        ufw allow 11434/tcp
    fi
    
    # 启动节点
    echo "启动Dria节点..."
    export DKN_LOG=debug
    dkn-compute-launcher start
}

# WSL网络修复功能
fix_wsl_network() {
    # 检查是否在WSL环境中
    if ! grep -qi "microsoft" /proc/version && ! grep -qi "microsoft" /proc/sys/kernel/osrelease; then
        display_status "此功能仅适用于WSL环境" "error"
        return 1
    fi
    
    display_status "正在进行WSL网络修复..." "info"
    
    # 停止现有服务
    display_status "停止现有服务..." "info"
    systemctl stop dria-node 2>/dev/null || true
    docker-compose -f /root/.dria/docker-compose.yml down 2>/dev/null || true
    pkill -f dkn-compute-launcher || true
    
    # 获取Windows主机IP
    display_status "获取Windows主机IP..." "info"
    WINDOWS_HOST_IP=$(ip route | grep default | awk '{print $3}')
    if [ -z "$WINDOWS_HOST_IP" ]; then
        display_status "无法获取Windows主机IP，使用默认IP 172.16.0.1" "warning"
        WINDOWS_HOST_IP="172.16.0.1"
    fi
    display_status "Windows主机IP: $WINDOWS_HOST_IP" "info"
    
    # 修复DNS配置
    display_status "修复DNS配置..." "info"
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    
    # 配置hosts映射
    display_status "配置hosts映射..." "info"
    if ! grep -q "node1.dria.co" /etc/hosts; then
        cat >> /etc/hosts << EOF
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
EOF
    fi
    
    # 检查dkn-compute-launcher是否存在
    if ! command -v dkn-compute-launcher &> /dev/null; then
        display_status "未检测到dkn-compute-launcher，尝试安装..." "warning"
        
        # 创建临时目录
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR" || return 1
        
        # 尝试获取最新版本
        LATEST_RELEASE=$(curl -s --connect-timeout 10 https://api.github.com/repos/firstbatchxyz/dkn-compute-launcher/releases/latest | grep "tag_name" | cut -d '"' -f 4)
        if [ -z "$LATEST_RELEASE" ]; then
            LATEST_RELEASE="v0.3.9"  # 使用默认版本
        fi
        
        display_status "下载dkn-compute-launcher版本 $LATEST_RELEASE..." "info"
        DOWNLOAD_URL="https://github.com/firstbatchxyz/dkn-compute-launcher/releases/download/${LATEST_RELEASE}/dkn-compute-launcher-linux-amd64"
        
        if ! wget --progress=dot:giga --timeout=60 "$DOWNLOAD_URL" -O dkn-compute-launcher; then
            display_status "下载失败，无法安装dkn-compute-launcher" "error"
            return 1
        fi
        
        chmod +x dkn-compute-launcher
        mv dkn-compute-launcher /usr/local/bin/
        cd - > /dev/null
        rm -rf "$TMP_DIR"
        display_status "dkn-compute-launcher安装完成" "success"
    fi
    
    # 创建优化的网络配置
    display_status "创建优化的网络配置..." "info"
    mkdir -p /root/.dria
    cat > /root/.dria/settings.json << EOF
{
    "network": {
        "enable_relay": true,
        "relay_discovery": true,
        "connection_timeout": 300,
        "direct_connection_timeout": 20000,
        "relay_connection_timeout": 60000,
        "mesh": {
            "high": 20,
            "low": 5,
            "target": 10
        },
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
            "/ip4/$WINDOWS_HOST_IP/tcp/4001",
            "/ip4/$WINDOWS_HOST_IP/udp/4001/quic-v1"
        ]
    }
}
EOF
    
    # 设置启动器配置
    display_status "配置dkn-compute-launcher..." "info"
    dkn-compute-launcher settings set docker.pull-policy IfNotPresent || true
    
    # 创建Windows端口转发脚本
    display_status "创建Windows端口转发脚本..." "info"
    cat > /root/.dria/wsl_port_forward.ps1 << EOF
# 以管理员身份运行此脚本
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "请以管理员身份运行此脚本！"
    exit
}

# 获取WSL IP地址
\$wslIp = wsl hostname -I | ForEach-Object { \$_.Trim() }
Write-Host "WSL IP: \$wslIp"

# 移除现有端口转发规则
netsh interface portproxy reset

# 添加新的端口转发规则
netsh interface portproxy add v4tov4 listenport=4001 listenaddress=0.0.0.0 connectport=4001 connectaddress=\$wslIp
netsh interface portproxy add v4tov4 listenport=1337 listenaddress=0.0.0.0 connectport=1337 connectaddress=\$wslIp
netsh interface portproxy add v4tov4 listenport=11434 listenaddress=0.0.0.0 connectport=11434 connectaddress=\$wslIp

# 添加防火墙规则（如果不存在）
if (-Not (Get-NetFirewallRule -DisplayName "Dria-TCP-4001" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Dria-TCP-4001" -Direction Inbound -Protocol TCP -LocalPort 4001 -Action Allow
}
if (-Not (Get-NetFirewallRule -DisplayName "Dria-UDP-4001" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Dria-UDP-4001" -Direction Inbound -Protocol UDP -LocalPort 4001 -Action Allow
}
if (-Not (Get-NetFirewallRule -DisplayName "Dria-TCP-1337" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Dria-TCP-1337" -Direction Inbound -Protocol TCP -LocalPort 1337 -Action Allow
}
if (-Not (Get-NetFirewallRule -DisplayName "Dria-TCP-11434" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Dria-TCP-11434" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
}

# 显示端口转发规则
Write-Host "当前端口转发规则:"
netsh interface portproxy show all

Write-Host "防火墙规则已添加，端口转发已配置。"
EOF
    
    # 提示用户在Windows中运行脚本
    display_status "端口转发脚本已创建: /root/.dria/wsl_port_forward.ps1" "success"
    display_status "请在Windows中打开PowerShell(管理员)，执行以下命令设置端口转发：" "warning"
    WSL_PATH=$(wslpath -w /root/.dria/wsl_port_forward.ps1)
    echo "powershell.exe -ExecutionPolicy Bypass -File \"$WSL_PATH\""
    
    # 创建优化启动器脚本
    display_status "创建优化启动器脚本..." "info"
    cat > /usr/local/bin/dria-optimized << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示状态函数
display_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${RED}❌ 错误: ${message}${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️ 警告: ${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}✅ 成功: ${message}${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ 信息: ${message}${NC}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    display_status "请使用root权限运行此脚本" "error"
    exit 1
fi

# 修复DNS问题
display_status "检查DNS配置..." "info"
if ! ping -c 1 -W 2 node1.dria.co &>/dev/null; then
    display_status "检测到DNS问题，正在修复..." "warning"
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    
    if ! grep -q "node1.dria.co" /etc/hosts; then
        cat >> /etc/hosts << EOF
34.145.16.76 node1.dria.co
34.42.109.93 node2.dria.co
34.42.43.172 node3.dria.co
35.200.247.78 node4.dria.co
34.92.171.75 node5.dria.co
EOF
    fi
fi

# 停止现有服务
display_status "停止现有服务..." "info"
systemctl stop dria-node 2>/dev/null || true
docker-compose -f /root/.dria/docker-compose.yml down 2>/dev/null || true
pkill -f dkn-compute-launcher || true

# 获取Windows主机IP
WINDOWS_HOST_IP=$(ip route | grep default | awk '{print $3}')
if [ -z "$WINDOWS_HOST_IP" ]; then
    display_status "无法获取Windows主机IP，使用默认IP 172.16.0.1" "warning"
    WINDOWS_HOST_IP="172.16.0.1"
fi
display_status "Windows主机IP: $WINDOWS_HOST_IP" "info"

# 更新优化的网络配置
display_status "更新网络配置..." "info"
mkdir -p /root/.dria
cat > /root/.dria/settings.json << EOF
{
    "network": {
        "enable_relay": true,
        "relay_discovery": true,
        "connection_timeout": 300,
        "direct_connection_timeout": 20000,
        "relay_connection_timeout": 60000,
        "mesh": {
            "high": 20,
            "low": 5,
            "target": 10
        },
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
            "/ip4/$WINDOWS_HOST_IP/tcp/4001",
            "/ip4/$WINDOWS_HOST_IP/udp/4001/quic-v1"
        ]
    }
}
EOF

# 设置启动器配置
display_status "配置dkn-compute-launcher..." "info"
dkn-compute-launcher settings set docker.pull-policy IfNotPresent || true

# 提示端口转发
display_status "确保已执行Windows端口转发脚本！" "warning"
WSL_PATH=$(wslpath -w /root/.dria/wsl_port_forward.ps1 2>/dev/null)
if [ -n "$WSL_PATH" ]; then
    echo "powershell.exe -ExecutionPolicy Bypass -File \"$WSL_PATH\""
fi

# 启动节点
display_status "正在启动Dria节点..." "info"
export DKN_LOG=debug
dkn-compute-launcher start
EOF
    
    chmod +x /usr/local/bin/dria-optimized
    
    # 创建服务文件
    display_status "创建系统服务..." "info"
    cat > /etc/systemd/system/dria-node.service << EOF
[Unit]
Description=Dria Compute Node
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dria-optimized
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable dria-node.service
    
    # 提示用户执行端口转发
    display_status "请在Windows中执行端口转发脚本！" "warning"
    display_status "在Windows PowerShell(管理员)中执行:" "info"
    WSL_PATH=$(wslpath -w /root/.dria/wsl_port_forward.ps1)
    echo "powershell.exe -ExecutionPolicy Bypass -File \"$WSL_PATH\""
    
    # 询问是否立即启动节点
    read -p "是否立即启动节点? (y/n): " START_NODE
    if [[ $START_NODE == "y" || $START_NODE == "Y" ]]; then
        display_status "启动Dria节点..." "info"
        systemctl start dria-node
        display_status "已启动Dria节点，您可以使用'journalctl -u dria-node -f'查看日志" "success"
    else
        display_status "您可以稍后使用'systemctl start dria-node'启动节点" "info"
    fi
    
    display_status "WSL网络修复完成" "success"
    display_status "重要提示：确保在Windows中执行端口转发脚本，否则外部无法连接到您的节点" "warning"
    display_status "您可以使用以下命令管理节点:" "info"
    echo "- 启动节点: systemctl start dria-node"
    echo "- 停止节点: systemctl stop dria-node"
    echo "- 查看日志: journalctl -u dria-node -f"
    echo "- 手动启动: dria-optimized"
    
    return 0
}

# 安装 Dria 节点 - 使用官方安装脚本
install_dria_node() {
    display_status "正在安装 Dria 计算节点..." "info"
    
    # 检查Docker状态
    if ! docker info &>/dev/null; then
        display_status "Docker服务未运行，无法安装Dria节点。请先确保Docker正常运行。" "error"
        return 1
    fi
    
    # 设置代理
    setup_proxy
    
    # 直接使用手动安装方法，跳过官方脚本
    display_status "使用直接下载安装方法..." "info"
    
    # 创建临时目录
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || {
        display_status "无法创建临时目录" "error"
        return 1
    }
    
    # 获取最新版本号
    display_status "尝试获取最新版本信息..." "info"
    LATEST_RELEASE=$(curl -s --connect-timeout 10 https://api.github.com/repos/firstbatchxyz/dkn-compute-launcher/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    
    if [ -z "$LATEST_RELEASE" ] || [[ ! "$LATEST_RELEASE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        display_status "获取最新版本失败，使用预设的稳定版本..." "warning"
        LATEST_RELEASE="v0.3.9"  # 更新为GitHub上的实际最新版本
    fi
    
    # 去掉版本号前面的'v'
    CLEAN_VERSION="${LATEST_RELEASE#v}"
    display_status "使用版本: $LATEST_RELEASE" "info"
    
    # 下载对应平台的二进制文件 - 使用直接链接
    DOWNLOAD_URL="https://github.com/firstbatchxyz/dkn-compute-launcher/releases/download/${LATEST_RELEASE}/dkn-compute-launcher-linux-amd64"
    display_status "下载链接: $DOWNLOAD_URL" "info"
    
    # 使用wget带进度指示下载
    display_status "正在下载Dria计算节点..." "info"
    if ! wget --progress=dot:giga --timeout=60 "$DOWNLOAD_URL" -O dkn-compute-launcher; then
        display_status "主下载链接失败，尝试备用链接..." "warning"
        BACKUP_URL="https://github.com/firstbatchxyz/dkn-compute-launcher/releases/latest/download/dkn-compute-launcher-linux-amd64"
        if ! wget --progress=dot:giga --timeout=60 "$BACKUP_URL" -O dkn-compute-launcher; then
            display_status "下载失败！请检查网络连接或代理设置。" "error"
            display_status "尝试通过手动方式下载..." "info"
            
            # 手动下载指导
            echo "请执行以下命令手动下载:"
            echo "------------------------"
            echo "export http_proxy=$http_proxy"
            echo "export https_proxy=$https_proxy"
            echo "wget $DOWNLOAD_URL -O /usr/local/bin/dkn-compute-launcher"
            echo "chmod +x /usr/local/bin/dkn-compute-launcher"
            echo "------------------------"
            
            cd "$HOME"
            rm -rf "$TMP_DIR"
            
            # 询问是否清除代理设置
            read -p "是否清除代理设置?(y/n): " clear_proxy_setting
            if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
                clear_proxy
            fi
            
            return 1
        fi
    fi
    
    display_status "设置可执行权限..." "info"
    chmod +x dkn-compute-launcher
    
    display_status "安装到系统路径..." "info"
    mv dkn-compute-launcher /usr/local/bin/
    
    # 添加别名到.bashrc
    if ! grep -q "start-dria" ~/.bashrc; then
        echo 'alias start-dria="dkn-compute-launcher start"' >> ~/.bashrc
        echo 'alias dria-settings="dkn-compute-launcher settings"' >> ~/.bashrc
        echo 'alias dria-points="dkn-compute-launcher points"' >> ~/.bashrc
        source ~/.bashrc
    fi
    
    # 初始化设置
    display_status "初始化Dria计算节点设置..." "info"
    dkn-compute-launcher settings set docker.pull-policy IfNotPresent
    
    # 是否询问配置代码
    read -p "是否想配置推荐码(赚取更多点数)?(y/n): " setup_ref_code
    if [[ $setup_ref_code == "y" || $setup_ref_code == "Y" ]]; then
        read -p "请输入推荐码: " ref_code
        if [ ! -z "$ref_code" ]; then
            dkn-compute-launcher settings set refer-code "$ref_code"
            display_status "已设置推荐码: $ref_code" "success"
        fi
    fi
    
    # 询问是否清除代理设置
    read -p "是否清除代理设置?(y/n): " clear_proxy_setting
    if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
        clear_proxy
    else
        display_status "保留当前代理设置，您可以稍后手动清除" "info"
    fi
    
    # 在WSL环境中询问是否进行网络优化
    if [ "$ENV_TYPE" = "wsl" ]; then
        read -p "是否进行WSL网络优化配置(推荐)?(y/n): " setup_wsl_network
        if [[ $setup_wsl_network == "y" || $setup_wsl_network == "Y" ]]; then
            display_status "正在进行WSL网络优化配置..." "info"
            configure_wsl_network
            
            display_status "Dria节点安装和配置完成，请使用优化的启动命令: 'dria-optimized'" "success"
        else
            display_status "Dria节点安装和配置完成，您现在可以使用 'start-dria' 命令启动节点。" "success"
            display_status "或者使用 'dkn-compute-launcher settings' 命令配置您的节点。" "info"
        fi
    else
        display_status "Dria节点安装和配置完成，您现在可以使用 'start-dria' 命令启动节点。" "success"
        display_status "或者使用 'dkn-compute-launcher settings' 命令配置您的节点。" "info"
    fi
}

# Dria 节点管理功能
manage_dria_node() {
    display_status "Dria 节点管理" "info"
    
    # 首先检查dkn-compute-launcher是否存在
    if ! command -v dkn-compute-launcher &> /dev/null; then
        display_status "未检测到dkn-compute-launcher，请先安装Dria计算节点" "error"
        read -n 1 -s -r -p "按任意键继续..."
        return 1
    fi
    
    # 检查Docker状态
    if ! docker info &>/dev/null; then
        if [ "$ENV_TYPE" = "wsl" ]; then
            display_status "Docker服务未运行，正在尝试启动..." "warning"
            service docker start || {
                display_status "无法启动Docker服务，请检查WSL配置" "error"
                read -n 1 -s -r -p "按任意键继续..."
                return 1
            }
        else
            display_status "Docker服务未运行，请确保Docker正常运行" "error"
            read -n 1 -s -r -p "按任意键继续..."
            return 1
        fi
    fi
    
    # 创建必要的目录和文件
    mkdir -p /root/.dria/dkn-compute-launcher
    if [ ! -f /root/.dria/dkn-compute-launcher/.env ]; then
        touch /root/.dria/dkn-compute-launcher/.env
        chmod 600 /root/.dria/dkn-compute-launcher/.env
    fi
    
    # 确保目录和文件权限正确
    chown -R root:root /root/.dria
    chmod -R 700 /root/.dria
    chmod 600 /root/.dria/dkn-compute-launcher/.env
    
    echo -e "${MENU_COLOR}请选择操作:${NORMAL}"
    echo -e "${MENU_COLOR}1. 启动 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}2. 配置 Dria 节点设置${NORMAL}"
    echo -e "${MENU_COLOR}3. 查看 Dria 点数${NORMAL}"
    echo -e "${MENU_COLOR}4. 管理推荐码${NORMAL}"
    echo -e "${MENU_COLOR}5. 测量本地模型性能${NORMAL}"
    echo -e "${MENU_COLOR}6. 更新 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}7. 卸载 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}8. 返回主菜单${NORMAL}"
    echo -e "${MENU_COLOR}9. 设置网络代理${NORMAL}"
    read -p "请输入选项（1-9）: " OPTION

    case $OPTION in
        1) dkn-compute-launcher start ;;
        2) dkn-compute-launcher settings ;;
        3) dkn-compute-launcher points ;;
        4) 
            # 检查是否已经配置了基本设置
            ENV_FILE="/root/.dria/dkn-compute-launcher/.env"
            if [ ! -f "$ENV_FILE" ]; then
                display_status "配置文件不存在，请先进行配置" "warning"
                dkn-compute-launcher settings
                return
            fi
            
            # 检查配置文件内容
            if ! grep -q "WALLET_SECRET_KEY=" "$ENV_FILE" || ! grep -q "MODELS=" "$ENV_FILE"; then
                display_status "检测到未完成基本配置，请先进行配置" "warning"
                dkn-compute-launcher settings
                return
            fi
            
            # 检查钱包配置是否为空
            WALLET_KEY=$(grep "WALLET_SECRET_KEY=" "$ENV_FILE" | cut -d'=' -f2)
            if [ -z "$WALLET_KEY" ] || [ "$WALLET_KEY" = '""' ]; then
                display_status "检测到钱包配置为空，请先配置钱包" "warning"
                dkn-compute-launcher settings
                return
            fi
            
            # 如果已经配置了基本设置，则继续处理推荐码
            display_status "正在配置推荐码管理环境..." "info"
            dkn-compute-launcher referrals
            ;;
        5) dkn-compute-launcher measure ;;
        6) dkn-compute-launcher update ;;
        7) dkn-compute-launcher uninstall ;;
        8) return ;;
        9) setup_proxy ;;
        *) display_status "无效选项，请重试。" "error" ;;
    esac
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 检查网络连接
check_network() {
    # 清屏以确保显示完整信息
    clear
    display_status "检查网络连接..." "info"
    
    # 创建临时日志文件
    LOG_FILE="/tmp/dria_network_check_$(date +%s).log"
    echo "开始网络检查日志 $(date)" > "$LOG_FILE"
    
    # 告诉用户正在执行详细检查
    echo -e "\n${BOLD}${INFO_COLOR}正在执行详细网络诊断，请稍候...${NORMAL}"
    echo -e "${BOLD}${INFO_COLOR}诊断日志保存在: $LOG_FILE${NORMAL}\n"
    
    # 测试基本网络连接
    echo -e "${BOLD}${INFO_COLOR}【1/5】基础网络连接测试:${NORMAL}"
    echo "【1/5】基础网络连接测试:" >> "$LOG_FILE"
    
    # 执行ping测试并显示结果
    echo "执行ping测试 8.8.8.8:" >> "$LOG_FILE"
    ping -c 1 -W 3 8.8.8.8 >> "$LOG_FILE" 2>&1
    PING_STATUS=$?
    
    if [ $PING_STATUS -ne 0 ]; then
        display_status "无法连接到互联网，请检查网络设置" "error"
        echo "Ping测试失败，退出码: $PING_STATUS" >> "$LOG_FILE"
        
        # 显示网络接口信息帮助诊断
        echo -e "\n${BOLD}${INFO_COLOR}网络接口信息:${NORMAL}"
        echo -e "\n网络接口信息:" >> "$LOG_FILE"
        ip addr show | tee -a "$LOG_FILE"
        
        # 检查默认路由
        echo -e "\n${BOLD}${INFO_COLOR}路由信息:${NORMAL}"
        echo -e "\n路由信息:" >> "$LOG_FILE"
        ip route | tee -a "$LOG_FILE"
        
        echo -e "\n${BOLD}${INFO_COLOR}网络诊断结果已保存到 $LOG_FILE${NORMAL}"
        return 1
    else
        display_status "基础网络连接正常" "success"
        echo "Ping测试成功" >> "$LOG_FILE"
    fi
    
    # 测试DNS配置
    echo -e "\n${BOLD}${INFO_COLOR}【2/5】DNS配置检查:${NORMAL}"
    echo "【2/5】DNS配置检查:" >> "$LOG_FILE"
    
    # 强制显示DNS配置
    echo -e "当前DNS配置(/etc/resolv.conf):"
    echo "当前DNS配置(/etc/resolv.conf):" >> "$LOG_FILE"
    
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf | tee -a "$LOG_FILE"
    else
        echo "文件不存在！创建基本DNS配置..." | tee -a "$LOG_FILE"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
        cat /etc/resolv.conf | tee -a "$LOG_FILE"
    fi
    
    # 验证DNS服务器是否可用
    dns_servers=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}')
    echo -e "\n已配置的DNS服务器: $dns_servers" | tee -a "$LOG_FILE"
    
    if [ -z "$dns_servers" ]; then
        echo "没有检测到DNS服务器配置，添加默认DNS服务器..." | tee -a "$LOG_FILE"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
        dns_servers="8.8.8.8 1.1.1.1"
        echo "新配置的DNS服务器: $dns_servers" | tee -a "$LOG_FILE"
    fi
    
    # 确保dnsutils已安装
    if ! command -v dig &>/dev/null || ! command -v host &>/dev/null; then
        echo "正在安装DNS诊断工具..." | tee -a "$LOG_FILE"
        apt-get update -y >> "$LOG_FILE" 2>&1
        apt-get install -y dnsutils >> "$LOG_FILE" 2>&1
    fi
    
    # 测试每个DNS服务器的连通性
    echo -e "\n${BOLD}${INFO_COLOR}【3/5】DNS服务器连通性测试:${NORMAL}"
    echo "【3/5】DNS服务器连通性测试:" >> "$LOG_FILE"
    
    for dns in $dns_servers; do
        echo -e "测试DNS服务器 $dns:" | tee -a "$LOG_FILE"
        ping -c 1 -W 2 $dns >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ DNS服务器 $dns 可访问" | tee -a "$LOG_FILE"
        else
            echo "❌ DNS服务器 $dns 无法访问" | tee -a "$LOG_FILE"
        fi
    done
    
    # DNS解析测试
    echo -e "\n${BOLD}${INFO_COLOR}【4/5】DNS解析测试:${NORMAL}"
    echo "【4/5】DNS解析测试:" >> "$LOG_FILE"
    
    # 使用多种DNS工具测试
    echo -e "使用host命令测试github.com解析:" | tee -a "$LOG_FILE"
    host github.com | tee -a "$LOG_FILE" || echo "host命令测试失败" | tee -a "$LOG_FILE"
    
    echo -e "\n使用dig命令测试github.com解析:" | tee -a "$LOG_FILE"
    dig github.com +short | tee -a "$LOG_FILE" || echo "dig命令测试失败" | tee -a "$LOG_FILE"
    
    echo -e "\n使用nslookup命令测试github.com解析:" | tee -a "$LOG_FILE"
    nslookup github.com | tee -a "$LOG_FILE" || echo "nslookup命令测试失败" | tee -a "$LOG_FILE"
    
    # 检查DNS解析问题并尝试修复
    if ! host github.com &>/dev/null; then
        display_status "DNS解析失败，尝试修复..." "warning"
        echo "DNS解析失败，尝试修复..." >> "$LOG_FILE"
        
        # WSL特定修复
        if [ "$ENV_TYPE" = "wsl" ]; then
            echo "应用WSL特定DNS修复..." | tee -a "$LOG_FILE"
            
            # 获取Windows主机IP
            win_host=$(ip route | grep default | awk '{print $3}')
            echo "Windows主机IP: $win_host" | tee -a "$LOG_FILE"
            
            if [ ! -z "$win_host" ]; then
                echo "使用Windows主机作为DNS服务器..." | tee -a "$LOG_FILE"
                echo "nameserver $win_host" > /etc/resolv.conf
                echo "nameserver 8.8.8.8" >> /etc/resolv.conf
                echo "nameserver 1.1.1.1" >> /etc/resolv.conf
                
                echo "新的DNS配置:" | tee -a "$LOG_FILE"
                cat /etc/resolv.conf | tee -a "$LOG_FILE"
                
                echo "重新测试DNS解析:" | tee -a "$LOG_FILE"
                host github.com | tee -a "$LOG_FILE"
                
                if [ $? -eq 0 ]; then
                    display_status "DNS解析问题已修复" "success"
                    echo "DNS解析问题已修复" >> "$LOG_FILE"
                else
                    display_status "DNS问题仍然存在，尝试使用中国大陆DNS" "warning"
                    echo "DNS问题仍然存在，尝试使用中国大陆DNS" >> "$LOG_FILE"
                    
                    echo "nameserver 114.114.114.114" > /etc/resolv.conf
                    echo "nameserver 223.5.5.5" >> /etc/resolv.conf
                    echo "使用中国大陆DNS的新配置:" | tee -a "$LOG_FILE"
                    cat /etc/resolv.conf | tee -a "$LOG_FILE"
                    
                    echo "使用中国大陆DNS重新测试:" | tee -a "$LOG_FILE"
                    host github.com | tee -a "$LOG_FILE" || echo "DNS解析仍然失败" | tee -a "$LOG_FILE"
                fi
            else
                display_status "无法获取Windows主机IP" "error"
                echo "无法获取Windows主机IP" >> "$LOG_FILE"
            fi
        else
            # 标准Ubuntu修复
            echo "应用标准Ubuntu DNS修复..." | tee -a "$LOG_FILE"
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo "nameserver 1.1.1.1" >> /etc/resolv.conf
            
            echo "使用公共DNS重新测试:" | tee -a "$LOG_FILE"
            host github.com | tee -a "$LOG_FILE"
            
            if [ $? -ne 0 ]; then
                echo "使用中国大陆DNS重新测试:" | tee -a "$LOG_FILE"
                echo "nameserver 114.114.114.114" > /etc/resolv.conf
                echo "nameserver 223.5.5.5" >> /etc/resolv.conf
                host github.com | tee -a "$LOG_FILE" || echo "DNS解析仍然失败" | tee -a "$LOG_FILE"
            fi
        fi
    else
        display_status "DNS解析正常" "success"
        echo "DNS解析正常" >> "$LOG_FILE"
    fi
    
    # GitHub连接测试
    echo -e "\n${BOLD}${INFO_COLOR}【5/5】GitHub连接测试:${NORMAL}"
    echo "【5/5】GitHub连接测试:" >> "$LOG_FILE"
    
    echo "尝试连接到GitHub API..." | tee -a "$LOG_FILE"
    curl -v --connect-timeout 5 https://api.github.com 2>&1 | tee -a "$LOG_FILE" | grep -E "Connected to|Failed|Couldn't|connect to"
    
    if curl -s --connect-timeout 5 --max-time 10 https://api.github.com &>/dev/null; then
        display_status "GitHub连接正常" "success"
        echo "GitHub连接正常" >> "$LOG_FILE"
    else
        display_status "GitHub连接失败，可能需要设置代理" "warning"
        echo "GitHub连接失败" >> "$LOG_FILE"
        
        # 显示当前代理设置
        if [ ! -z "$http_proxy" ]; then
            echo "当前代理设置: $http_proxy" | tee -a "$LOG_FILE"
        else
            echo "未设置HTTP代理" | tee -a "$LOG_FILE"
        fi
        
        # WSL特定提示
        if [ "$ENV_TYPE" = "wsl" ]; then
            echo "WSL环境可以通过选项8设置Windows主机代理" | tee -a "$LOG_FILE"
            win_host=$(ip route | grep default | awk '{print $3}')
            if [ ! -z "$win_host" ]; then
                echo "Windows主机IP: $win_host" | tee -a "$LOG_FILE"
                echo "常用代理端口: 7890、1080、8080、8118等" | tee -a "$LOG_FILE"
            fi
        fi
    fi
    
    # 诊断总结
    echo -e "\n${BOLD}${INFO_COLOR}网络诊断总结:${NORMAL}" | tee -a "$LOG_FILE"
    echo "1. 基本网络连接: $(if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then echo "正常"; else echo "异常"; fi)" | tee -a "$LOG_FILE"
    echo "2. DNS服务器可访问性: $(if ping -c 1 -W 2 $(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}') &>/dev/null; then echo "正常"; else echo "异常"; fi)" | tee -a "$LOG_FILE"
    echo "3. DNS解析: $(if host github.com &>/dev/null; then echo "正常"; else echo "异常"; fi)" | tee -a "$LOG_FILE"
    echo "4. GitHub访问: $(if curl -s --connect-timeout 3 https://api.github.com &>/dev/null; then echo "正常"; else echo "异常"; fi)" | tee -a "$LOG_FILE"
    
    # 建议措施
    echo -e "\n${BOLD}${INFO_COLOR}建议措施:${NORMAL}" | tee -a "$LOG_FILE"
    if ! host github.com &>/dev/null; then
        echo "- DNS问题: 请尝试设置不同的DNS服务器或使用网络代理" | tee -a "$LOG_FILE"
    fi
    
    if ! curl -s --connect-timeout 3 https://api.github.com &>/dev/null; then
        echo "- GitHub访问问题: 请使用选项8设置网络代理" | tee -a "$LOG_FILE"
    fi
    
    echo -e "\n${BOLD}${INFO_COLOR}完整诊断日志保存在: $LOG_FILE${NORMAL}"
    display_status "网络连接检查完成" "success"
    
    # 确保用户能看到输出
    sleep 1
    
    return 0
}

# 检查系统环境
check_system_environment() {
    clear
    display_status "系统环境检查" "info"
    
    echo -e "${MENU_COLOR}操作系统信息:${NORMAL}"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release
    else
        echo "无法获取操作系统信息"
    fi
    
    echo -e "\n${MENU_COLOR}内核版本:${NORMAL}"
    uname -a
    
    echo -e "\n${MENU_COLOR}WSL检测:${NORMAL}"
    if [ "$ENV_TYPE" = "wsl" ]; then
        echo "WSL环境：已检测到"
        echo -e "\nWSL版本信息:"
        if [ -f /proc/sys/kernel/osrelease ]; then
            cat /proc/sys/kernel/osrelease
        fi
    else
        echo "WSL环境：未检测到"
    fi
    
    echo -e "\n${MENU_COLOR}Docker状态:${NORMAL}"
    if command -v docker &> /dev/null; then
        echo "Docker已安装"
        if docker info &>/dev/null; then
            echo "Docker服务运行正常"
            docker --version
        else
            echo "Docker服务未运行"
        fi
    else
        echo "Docker未安装"
    fi
    
    echo -e "\n${MENU_COLOR}Ollama状态:${NORMAL}"
    if command -v ollama &> /dev/null; then
        echo "Ollama已安装"
        ollama --version
    else
        echo "Ollama未安装"
    fi
    
    echo -e "\n${MENU_COLOR}Dria计算节点状态:${NORMAL}"
    if command -v dkn-compute-launcher &> /dev/null; then
        echo "Dria计算节点已安装"
        dkn-compute-launcher --version || echo "无法获取版本信息"
    else
        echo "Dria计算节点未安装"
    fi
    
    echo -e "\n${MENU_COLOR}系统资源:${NORMAL}"
    echo "CPU信息:"
    lscpu | grep "Model name\|CPU(s)\|CPU MHz"
    
    echo -e "\n内存信息:"
    free -h
    
    echo -e "\n磁盘空间:"
    df -h / /home
    
    read -n 1 -s -r -p "按任意键继续..."
}

# 初始化函数
initialize() {
    # 检查是否需要安装基本工具
    if ! command -v curl &>/dev/null || ! command -v ping &>/dev/null || ! command -v wget &>/dev/null; then
        display_status "安装基本工具..." "info"
        apt update -y &>/dev/null
        apt install -y curl wget iputils-ping &>/dev/null
    fi
    
    # 为WSL环境执行特殊初始化
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "执行WSL环境初始化..." "info"
        
        # 确保/etc/resolv.conf正确 - 不阻塞
        if [ ! -f /etc/resolv.conf ] || ! grep -q "nameserver" /etc/resolv.conf; then
            display_status "创建/修复DNS配置..." "info"
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        
        # 检查Docker服务可用性 - 不阻塞
        if command -v docker &>/dev/null && ! timeout 2 docker info &>/dev/null; then
            display_status "尝试启动Docker服务..." "info"
            service docker start &>/dev/null || /etc/init.d/docker start &>/dev/null &
        fi
    fi
}

# 网络初始化 - 在后台进行
init_network_check() {
    # 在后台执行网络检查并将结果保存到临时文件
    (
        # 快速测试Google DNS，超时设为2秒
        if timeout 2 ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            echo "internet_ok" > /tmp/dria_network_status
        else
            echo "internet_error" > /tmp/dria_network_status
        fi
        
        # 快速测试GitHub连接，超时设为3秒
        if timeout 3 curl -s --connect-timeout 3 https://api.github.com &>/dev/null; then
            echo "github_ok" > /tmp/dria_github_status
        else
            echo "github_error" > /tmp/dria_github_status
        fi
    ) &
}

# 显示脚本信息
display_info() {
    clear
    # 署名信息
    cat << "EOF"

   __   _         _                                    ___    _  _   
  / _| (_)       | |                                  |__ \  | || |  
 | |_   _   ___  | |__    ____   ___    _ __     ___     ) | | || |_ 
 |  _| | | / __| | '_ \  |_  /  / _ \  | '_ \   / _ \   / /  |__   _|
 | |   | | \__ \ | | | |  / /  | (_) | | | | | |  __/  / /_     | |  
 |_|   |_| |___/ |_| |_| /___|  \___/  |_| |_|  \___| |____|    |_|  
                                                                     
                                                                     

                                                                                                                                  

EOF
    echo -e "${BLUE}==================================================================${RESET}"
    echo -e "${GREEN}Dria 节点一键管理脚本${RESET}"
    echo -e "${YELLOW}脚本作者: fishzone24 - 推特: https://x.com/fishzone24${RESET}"
    echo -e "${YELLOW}此脚本为免费开源脚本，如有问题请提交 issue${RESET}"
    echo -e "${BLUE}==================================================================${RESET}"
    
    echo ""
    echo -e "${GREEN}此脚本将帮助您在 Ubuntu 系统上自动安装和配置 Dria 计算节点。${RESET}"
    if [ "$ENV_TYPE" = "wsl" ]; then
        echo -e "${YELLOW}当前在Windows Subsystem for Linux (WSL)环境中运行${RESET}"
    else
        echo -e "${YELLOW}当前在原生Ubuntu环境中运行${RESET}"
    fi
    echo "安装过程包括:"
    echo "- 更新系统并安装必要的依赖"
    echo "- 安装 Docker 环境"
    echo "- 安装 Ollama（用于本地模型）"
    echo "- 安装 Dria 计算节点"
    echo "- 提供节点管理界面"
    echo ""
    echo "注意:"
    echo "1. 请确保您已经以 root 用户身份运行此脚本"
    echo "2. 安装过程需要稳定的网络连接"
    echo "3. 请确保您的系统资源足够运行 Dria 节点"
    echo ""
    
    # 只在第一次启动时提示按键继续
    if [ -z "$SCRIPT_INITIALIZED" ]; then
        read -n 1 -s -r -p "按任意键继续..."
        export SCRIPT_INITIALIZED=true
    fi
}

# 主菜单功能
main_menu() {
    # 不使用while循环
    clear
    # 添加署名信息
    cat << "EOF"

   __   _         _                                    ___    _  _   
  / _| (_)       | |                                  |__ \  | || |  
 | |_   _   ___  | |__    ____   ___    _ __     ___     ) | | || |_ 
 |  _| | | / __| | '_ \  |_  /  / _ \  | '_ \   / _ \   / /  |__   _|
 | |   | | \__ \ | | | |  / /  | (_) | | | | | |  __/  / /_     | |  
 |_|   |_| |___/ |_| |_| /___|  \___/  |_| |_|  \___| |____|    |_|  
                                                                     
                                                                     

                                                                                                                                  

EOF
    echo -e "${BLUE}==================================================================${RESET}"
    echo -e "${GREEN}Dria 节点一键管理脚本${RESET}"
    echo -e "${YELLOW}脚本作者: fishzone24 - 推特: https://x.com/fishzone24${RESET}"
    echo -e "${YELLOW}此脚本为免费开源脚本，如有问题请提交 issue${RESET}"
    echo -e "${BLUE}==================================================================${RESET}"
    
    # 显示运行环境
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "当前运行在Windows Subsystem for Linux (WSL)环境中" "info"
    else
        display_status "当前运行在原生Ubuntu环境中" "info"
    fi
    
    # 显示代理状态
    if [ ! -z "$http_proxy" ]; then
        display_status "代理已设置: $http_proxy" "info"
    fi
    
    # 显示网络状态
    if [ -f /tmp/dria_github_status ] && [ "$(cat /tmp/dria_github_status)" = "github_error" ]; then
        display_status "GitHub连接不可用，建议设置网络代理" "warning"
    fi
    
    echo -e "${MENU_COLOR}${BOLD}============================ Dria 节点管理工具 ============================${NORMAL}"
    echo -e "${MENU_COLOR}请选择操作:${NORMAL}"
    echo -e "${MENU_COLOR}1. 更新系统并安装依赖项${NORMAL}"
    echo -e "${MENU_COLOR}2. 安装 Docker 环境${NORMAL}"
    echo -e "${MENU_COLOR}3. 安装 Ollama${NORMAL}"
    echo -e "${MENU_COLOR}4. 安装 Dria 计算节点${NORMAL}"
    echo -e "${MENU_COLOR}5. Dria 节点管理${NORMAL}"
    echo -e "${MENU_COLOR}6. 检查系统环境${NORMAL}"
    echo -e "${MENU_COLOR}7. 检查网络连接${NORMAL}"
    echo -e "${MENU_COLOR}8. 设置网络代理${NORMAL}"
    echo -e "${MENU_COLOR}9. 清除网络代理${NORMAL}"
    echo -e "${MENU_COLOR}H. Ollama修复工具${NORMAL}"
    echo -e "${MENU_COLOR}O. Ollama Docker修复${NORMAL}"
    echo -e "${MENU_COLOR}D. DNS修复工具${NORMAL}"
    echo -e "${MENU_COLOR}F. 超级修复工具${NORMAL}"
    echo -e "${MENU_COLOR}I. 直接IP连接${NORMAL}"
    echo -e "${MENU_COLOR}W. WSL网络修复工具${NORMAL}"
    echo -e "${MENU_COLOR}0. 退出${NORMAL}"
    read -p "请输入选项（0-9/H/O/D/F/I/W）: " OPTION

    case $OPTION in
        1) 
            setup_prerequisites
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        2) 
            install_docker
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        3) 
            install_ollama
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        4) 
            install_dria_node
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        5) 
            manage_dria_node
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        6) 
            check_system_environment
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        7) 
            check_network
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        8) 
            setup_proxy
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        9) 
            clear_proxy
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        [Hh])
            display_status "正在修复Ollama..." "info"
            mkdir -p /root/.ollama/models
            chown -R root:root /root/.ollama
            chmod -R 755 /root/.ollama
            display_status "Ollama目录权限已修复" "success"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        [Oo])
            display_status "正在运行Ollama Docker修复工具..." "info"
            fix_ollama_docker
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        [Dd])
            display_status "正在运行DNS修复工具..." "info"
            fix_wsl_dns
            display_status "DNS修复完成" "success"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        [Ff])
            display_status "正在运行超级修复工具..." "info"
            create_superfix_tool
            display_status "超级修复工具已创建，可以使用 'dria-superfix' 命令启动" "success"
            read -p "是否立即运行超级修复工具?(y/n): " run_superfix
            if [[ $run_superfix == "y" || $run_superfix == "Y" ]]; then
                /usr/local/bin/dria-superfix
            fi
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        [Ii])
            display_status "创建直接IP连接工具..." "info"
                
            # 创建工具脚本
            cat > /usr/local/bin/dria-direct << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示状态函数
display_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${RED}❌ 错误: ${message}${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️ 警告: ${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}✅ 成功: ${message}${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ 信息: ${message}${NC}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    display_status "请使用root权限运行此脚本" "error"
    exit 1
fi

# 检查并安装docker-compose
if ! command -v docker-compose &> /dev/null; then
    display_status "未检测到docker-compose，开始安装..." "info"
    
    # 检查Docker是否已安装
    if ! command -v docker &> /dev/null; then
        display_status "未检测到Docker，无法安装docker-compose" "error"
        exit 1
    fi
    
    # 安装docker-compose
    display_status "安装docker-compose..." "info"
    apt update -y
    apt install -y docker-compose
    
    # 验证安装
    if ! command -v docker-compose &> /dev/null; then
        display_status "docker-compose安装失败，尝试使用pip安装" "warning"
        apt install -y python3-pip
        pip3 install docker-compose
        
        if ! command -v docker-compose &> /dev/null; then
            display_status "docker-compose安装失败，请手动安装后重试" "error"
            exit 1
        fi
    fi
    display_status "docker-compose安装成功" "success"
fi

# 停止现有服务
display_status "停止现有服务..." "info"
systemctl stop dria-node 2>/dev/null || true
docker-compose -f /root/.dria/docker-compose.yml down 2>/dev/null || true

# 获取本机IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="0.0.0.0"
fi

# 创建优化的网络配置
display_status "创建优化的网络配置..." "info"
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
            "/ip4/$LOCAL_IP/tcp/4001",
            "/ip4/$LOCAL_IP/udp/4001/quic-v1"
        ]
    }
}
EOL

# 创建docker-compose.yml文件
display_status "创建docker-compose.yml文件..." "info"
cat > /root/.dria/docker-compose.yml << 'EOL'
version: '3.8'

services:
  dria-node:
    image: dria/dkn-compute-launcher:latest
    container_name: dria-node
    restart: unless-stopped
    network_mode: host
    volumes:
      - /root/.dria:/root/.dria
    environment:
      - DKN_LOG=debug
    ports:
      - "4001:4001"
      - "1337:1337"
      - "11434:11434"
    command: start
    pull_policy: never

networks:
  default:
    name: dria-network
    driver: bridge
EOL

# 确保文件权限正确
chmod 644 /root/.dria/docker-compose.yml
chown root:root /root/.dria/docker-compose.yml

# 检查Docker网络
display_status "检查Docker网络..." "info"
if ! docker network inspect dria-network >/dev/null 2>&1; then
    docker network create dria-network
fi

# 检查本地镜像
if ! docker images | grep -q "dria/dkn-compute-launcher"; then
    display_status "本地不存在Dria镜像，查找可用的替代镜像..." "warning"
    
    # 查找可能的替代镜像
    ALT_IMAGE=$(docker images | grep -i "dria\|dkn" | head -n 1 | awk '{print $1":"$2}')
    
    if [ -n "$ALT_IMAGE" ]; then
        display_status "找到替代镜像: $ALT_IMAGE，将使用该镜像" "info"
        # 替换docker-compose.yml中的镜像
        sed -i "s|image: dria/dkn-compute-launcher:latest|image: $ALT_IMAGE|g" /root/.dria/docker-compose.yml
    else
        display_status "未找到任何可用的Dria相关镜像，将尝试列出所有本地镜像" "warning"
        echo "可用的本地镜像:"
        docker images
        
        # 询问用户是否要使用本地某个镜像
        read -p "请输入要使用的本地镜像名称（格式：name:tag，直接回车使用默认）: " USER_IMAGE
        
        if [ -n "$USER_IMAGE" ]; then
            display_status "将使用镜像: $USER_IMAGE" "info"
            sed -i "s|image: dria/dkn-compute-launcher:latest|image: $USER_IMAGE|g" /root/.dria/docker-compose.yml
        else
            display_status "未指定替代镜像，将尝试使用默认镜像" "warning"
        fi
    fi
fi

# 尝试启动节点
display_status "尝试启动节点..." "info"
if docker-compose -f /root/.dria/docker-compose.yml up -d; then
    display_status "节点启动成功" "success"
    echo "请检查节点状态："
    docker-compose -f /root/.dria/docker-compose.yml logs | head -n 20
    display_status "使用以下命令查看完整日志：docker-compose -f /root/.dria/docker-compose.yml logs -f" "info"
else
    display_status "节点启动失败" "error"
    exit 1
fi
EOF

                # 设置执行权限
                chmod +x /usr/local/bin/dria-direct
                display_status "直接IP连接工具已创建，可以使用 'dria-direct' 命令启动" "success"
                
                read -p "是否立即运行直接IP连接?(y/n): " run_direct
                if [[ $run_direct == "y" || $run_direct == "Y" ]]; then
                    /usr/local/bin/dria-direct
                fi
                read -n 1 -s -r -p "按任意键返回主菜单..."
                main_menu
                ;;
        [Ww])
            display_status "正在运行WSL网络修复工具..." "info"
            fix_wsl_network
            display_status "WSL网络修复完成" "success"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
        0) exit 0 ;;
        *) 
            display_status "无效选项，请重试。" "error"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            main_menu
            ;;
    esac
}

# 执行脚本
initialize      # 快速初始化
init_network_check  # 网络检测在后台进行
display_info
main_menu
