#!/bin/bash

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
        
        # 清理临时目录
        cd "$HOME"
        rm -rf "$TMP_DIR"
        
        display_status "Ollama 安装成功。请手动运行 'ollama serve' 来启动Ollama服务。" "success"
    else
        # 标准安装方法
        curl -fsSL https://ollama.com/install.sh | sh && display_status "Ollama 安装成功。" "success" || display_status "Ollama 安装失败。" "error"
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
        LATEST_RELEASE="v0.1.5"  # 更新为GitHub上的实际最新版本
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
    
    # 设置权限并移动到系统路径
    chmod +x dkn-compute-launcher
    
    # 检查文件是否正确下载
    if [ ! -f "dkn-compute-launcher" ] || [ ! -s "dkn-compute-launcher" ] || [ ! -x "dkn-compute-launcher" ]; then
        display_status "下载的文件不完整或无法执行" "error"
        cd "$HOME"
        rm -rf "$TMP_DIR"
        
        # 询问是否清除代理设置
        read -p "是否清除代理设置?(y/n): " clear_proxy_setting
        if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
            clear_proxy
        fi
        
        return 1
    fi
    
    # 测试可执行文件是否有效
    if ! ./dkn-compute-launcher --version &>/dev/null; then
        display_status "下载的可执行文件不正常，将尝试从源代码构建..." "warning"
        
        # 如果从二进制安装失败，尝试从源码构建
        if command -v cargo &>/dev/null; then
            display_status "检测到Rust环境，尝试从源码安装..." "info"
            
            # 安装rust工具链
            if ! command -v rustc &>/dev/null; then
                display_status "正在安装Rust工具链..." "info"
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                source "$HOME/.cargo/env"
            fi
            
            # 克隆仓库
            if ! command -v git &>/dev/null; then
                apt update && apt install -y git
            fi
            
            git clone https://github.com/firstbatchxyz/dkn-compute-launcher.git
            cd dkn-compute-launcher
            cargo build --release
            
            if [ -f "target/release/dkn-compute-launcher" ]; then
                cp target/release/dkn-compute-launcher /usr/local/bin/
                display_status "Dria计算节点从源码安装成功" "success"
                cd "$HOME"
                rm -rf "$TMP_DIR"
                
                # 询问是否清除代理设置
                read -p "是否清除代理设置?(y/n): " clear_proxy_setting
                if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
                    clear_proxy
                fi
            else
                display_status "从源码构建失败" "error"
                cd "$HOME"
                rm -rf "$TMP_DIR"
                
                # 询问是否清除代理设置
                read -p "是否清除代理设置?(y/n): " clear_proxy_setting
                if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
                    clear_proxy
                fi
                
                return 1
            fi
        else
            display_status "无法安装Dria计算节点。请尝试手动安装。" "error"
            cd "$HOME"
            rm -rf "$TMP_DIR"
            
            # 询问是否清除代理设置
            read -p "是否清除代理设置?(y/n): " clear_proxy_setting
            if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
                clear_proxy
            fi
            
            return 1
        fi
    else
        mv dkn-compute-launcher /usr/local/bin/
        display_status "Dria计算节点安装成功" "success"
    fi
    
    # 清理临时目录
    cd "$HOME"
    rm -rf "$TMP_DIR"
    
    # 创建一个启动脚本以便于以后的运行
    cat > /usr/local/bin/start-dria << 'EOF'
#!/bin/bash
cd $HOME

# 检查是否在WSL环境中
if grep -q "microsoft" /proc/version 2>/dev/null || grep -q "Microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
    # 在WSL中，确保Docker服务正在运行
    if ! docker info &>/dev/null; then
        echo "正在启动Docker服务..."
        sudo service docker start
        # 等待Docker启动
        sleep 3
    fi
    
    # 检查是否存在代理环境变量
    if [ -f ~/.wgetrc ] || [ -f ~/.curlrc ]; then
        echo "检测到代理设置，正在应用..."
        if [ -f ~/.wgetrc ]; then
            proxy_line=$(grep "http_proxy" ~/.wgetrc)
            if [ ! -z "$proxy_line" ]; then
                export http_proxy="${proxy_line#http_proxy=}"
                export https_proxy="${proxy_line#http_proxy=}"
                export all_proxy="${proxy_line#http_proxy=}"
                all_proxy="${all_proxy/http/socks5}"
                echo "已应用代理设置: $http_proxy"
            fi
        fi
    fi
fi

# 启动Dria节点
echo "启动Dria计算节点..."
dkn-compute-launcher start
EOF
    chmod +x /usr/local/bin/start-dria
    display_status "启动脚本已创建: /usr/local/bin/start-dria" "success"
    
    # 添加基本配置信息
    display_status "正在进行基本配置..." "info"
    mkdir -p "$HOME/.dria" 2>/dev/null
    
    # 确保配置目录存在
    if [ ! -d "$HOME/.dria" ]; then
        display_status "无法创建配置目录" "warning"
    fi
    
    # 询问是否清除代理设置
    read -p "是否清除代理设置?(y/n): " clear_proxy_setting
    if [[ $clear_proxy_setting == "y" || $clear_proxy_setting == "Y" ]]; then
        clear_proxy
    else
        display_status "保留当前代理设置，您可以稍后手动清除" "info"
    fi
    
    display_status "Dria节点安装和配置完成，您现在可以使用 'start-dria' 命令启动节点。" "success"
    display_status "或者使用 'dkn-compute-launcher settings' 命令配置您的节点。" "info"
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
    
    echo -e "${MENU_COLOR}请选择操作:${NORMAL}"
    echo -e "${MENU_COLOR}1. 启动 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}2. 配置 Dria 节点设置${NORMAL}"
    echo -e "${MENU_COLOR}3. 查看 Dria 点数${NORMAL}"
    echo -e "${MENU_COLOR}4. 管理推荐码${NORMAL}"
    echo -e "${MENU_COLOR}5. 测量本地模型性能${NORMAL}"
    echo -e "${MENU_COLOR}6. 更新 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}7. 卸载 Dria 节点${NORMAL}"
    echo -e "${MENU_COLOR}8. 返回主菜单${NORMAL}"
    read -p "请输入选项（1-8）: " OPTION

    case $OPTION in
        1) dkn-compute-launcher start ;;
        2) dkn-compute-launcher settings ;;
        3) dkn-compute-launcher points ;;
        4) dkn-compute-launcher referrals ;;
        5) dkn-compute-launcher measure ;;
        6) dkn-compute-launcher update ;;
        7) dkn-compute-launcher uninstall ;;
        8) return ;;
        *) display_status "无效选项，请重试。" "error" ;;
    esac
    read -n 1 -s -r -p "按任意键继续..."
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
    echo -e "${INFO_COLOR}${BOLD}=========================================================================${NORMAL}"
    echo -e "${INFO_COLOR}${BOLD}                     Dria 计算节点自动安装脚本                           ${NORMAL}"
    echo -e "${INFO_COLOR}${BOLD}=========================================================================${NORMAL}"
    echo -e ""
    echo -e "${INFO_COLOR}此脚本将帮助您在 Ubuntu 系统上自动安装和配置 Dria 计算节点。${NORMAL}"
    
    # 显示当前环境信息
    if [ "$ENV_TYPE" = "wsl" ]; then
        echo -e "${WARNING_COLOR}已检测到Windows Subsystem for Linux (WSL)环境${NORMAL}"
        echo -e "${WARNING_COLOR}脚本已针对WSL环境进行优化${NORMAL}"
    else
        echo -e "${INFO_COLOR}当前在原生Ubuntu环境中运行${NORMAL}"
    fi
    
    # 执行简单的网络检查 - 不阻塞
    if [ -f /tmp/dria_network_status ] && [ "$(cat /tmp/dria_network_status)" = "internet_error" ]; then
        echo -e "${ERROR_COLOR}${BOLD}警告: 网络连接可能有问题，这可能会影响安装过程${NORMAL}"
    fi
    
    if [ -f /tmp/dria_github_status ] && [ "$(cat /tmp/dria_github_status)" = "github_error" ]; then
        echo -e "${ERROR_COLOR}${BOLD}警告: 无法连接到GitHub，请考虑设置网络代理${NORMAL}"
    fi
    
    echo -e "${INFO_COLOR}安装过程包括:${NORMAL}"
    echo -e "${INFO_COLOR}- 更新系统并安装必要的依赖${NORMAL}"
    echo -e "${INFO_COLOR}- 安装 Docker 环境${NORMAL}"
    echo -e "${INFO_COLOR}- 安装 Ollama（用于本地模型）${NORMAL}"
    echo -e "${INFO_COLOR}- 安装 Dria 计算节点${NORMAL}"
    echo -e "${INFO_COLOR}- 提供节点管理界面${NORMAL}"
    echo -e ""
    echo -e "${WARNING_COLOR}${BOLD}注意:${NORMAL}"
    echo -e "${WARNING_COLOR}1. 请确保您已经以 root 用户身份运行此脚本${NORMAL}"
    echo -e "${WARNING_COLOR}2. 安装过程需要稳定的网络连接${NORMAL}"
    echo -e "${WARNING_COLOR}3. 请确保您的系统资源足够运行 Dria 节点${NORMAL}"
    
    # WSL特定提示
    if [ "$ENV_TYPE" = "wsl" ]; then
        echo -e ""
        echo -e "${WARNING_COLOR}${BOLD}WSL环境特别提示:${NORMAL}"
        echo -e "${WARNING_COLOR}1. 确保WSL2集成已启用${NORMAL}"
        echo -e "${WARNING_COLOR}2. 在WSL中Docker可能需要手动启动${NORMAL}"
        echo -e "${WARNING_COLOR}3. 如遇到问题，可尝试重启WSL或Windows系统${NORMAL}"
        echo -e "${WARNING_COLOR}4. 可在Windows PowerShell中执行 wsl --shutdown 后重新启动WSL${NORMAL}"
        echo -e "${WARNING_COLOR}5. 请先设置网络代理以确保能够访问GitHub${NORMAL}"
    fi
    
    echo -e ""
    read -n 1 -s -r -p "按任意键继续..."
}

# 主菜单功能
main_menu() {
    while true; do
        clear
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
        
        # 尝试下载并显示 logo，但设置超时避免卡住
        if command -v curl &> /dev/null; then
            curl -s --connect-timeout 3 --max-time 3 https://raw.githubusercontent.com/fishzone24/dria/main/logo.sh | bash 2>/dev/null || echo "DRIA 节点管理工具"
            sleep 1
        else
            echo "DRIA 节点管理工具"
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
        echo -e "${MENU_COLOR}0. 退出${NORMAL}"
        read -p "请输入选项（0-9）: " OPTION

        case $OPTION in
            1) setup_prerequisites ;;
            2) install_docker ;;
            3) install_ollama ;;
            4) install_dria_node ;;
            5) manage_dria_node ;;
            6) check_system_environment ;;
            7) check_network ;;
            8) setup_proxy ;;
            9) clear_proxy ;;
            0) exit 0 ;;
            *) display_status "无效选项，请重试。" "error" ;;
        esac
        read -n 1 -s -r -p "按任意键返回主菜单..."
    done
}

# 执行脚本
initialize      # 快速初始化
init_network_check  # 网络检测在后台进行
display_info
main_menu 
main_menu 