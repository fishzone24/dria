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
                service docker start || {
                    display_status "无法启动Docker服务，请检查WSL配置，可能需要手动执行以下命令:" "error"
                    echo "sudo service docker start"
                    echo "如果问题持续，可能需要重新启动WSL或Windows系统"
                    read -n 1 -s -r -p "按任意键继续..."
                    return 1
                }
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
        service docker start || {
            display_status "无法启动Docker服务，请检查WSL配置" "error"
            return 1
        }
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

# 安装 Dria 节点 - 使用官方安装脚本
install_dria_node() {
    display_status "正在安装 Dria 计算节点..." "info"
    
    # 检查Docker状态
    if ! docker info &>/dev/null; then
        display_status "Docker服务未运行，无法安装Dria节点。请先确保Docker正常运行。" "error"
        return 1
    fi
    
    # 在WSL环境中可能需要特别处理
    if [ "$ENV_TYPE" = "wsl" ]; then
        display_status "WSL环境检测到，使用修改后的安装方法..." "info"
        # 确保用户目录权限正确
        cd "$HOME" || {
            display_status "无法访问用户主目录" "error"
            return 1
        }
    fi
    
    # 使用官方脚本安装
    curl -fsSL https://dria.co/launcher | bash
    if [ $? -ne 0 ]; then
        display_status "使用官方脚本安装失败，尝试替代方法..." "warning"
        
        # 创建临时目录
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR" || {
            display_status "无法创建临时目录" "error"
            return 1
        }
        
        # 直接下载最新版本
        display_status "直接下载Dria计算节点..." "info"
        LATEST_RELEASE=$(curl -s https://api.github.com/repos/firstbatchxyz/dkn-compute-launcher/releases/latest | grep "tag_name" | cut -d '"' -f 4)
        
        if [ -z "$LATEST_RELEASE" ]; then
            display_status "无法获取最新版本信息" "error"
            return 1
        fi
        
        display_status "找到最新版本: $LATEST_RELEASE" "info"
        
        # 下载对应平台的二进制文件
        DOWNLOAD_URL="https://github.com/firstbatchxyz/dkn-compute-launcher/releases/download/$LATEST_RELEASE/dkn-compute-launcher-linux-amd64"
        wget -q "$DOWNLOAD_URL" -O dkn-compute-launcher || {
            display_status "无法下载Dria计算节点" "error"
            return 1
        }
        
        # 设置权限并移动到系统路径
        chmod +x dkn-compute-launcher
        mv dkn-compute-launcher /usr/local/bin/
        
        # 清理临时目录
        cd "$HOME"
        rm -rf "$TMP_DIR"
        
        display_status "Dria计算节点安装成功（手动方法）" "success"
    else
        display_status "Dria 计算节点安装成功。" "success"
    fi
    
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
fi

# 启动Dria节点
echo "启动Dria计算节点..."
dkn-compute-launcher start
EOF
    chmod +x /usr/local/bin/start-dria
    display_status "启动脚本已创建: /usr/local/bin/start-dria" "success"
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
        
        # 尝试下载并显示 logo
        if command -v curl &> /dev/null; then
            curl -s https://raw.githubusercontent.com/fishzone24/dria/main/logo.sh | bash 2>/dev/null || echo "DRIA 节点管理工具"
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
        echo -e "${MENU_COLOR}7. 退出${NORMAL}"
        read -p "请输入选项（1-7）: " OPTION

        case $OPTION in
            1) setup_prerequisites ;;
            2) install_docker ;;
            3) install_ollama ;;
            4) install_dria_node ;;
            5) manage_dria_node ;;
            6) check_system_environment ;;
            7) exit 0 ;;
            *) display_status "无效选项，请重试。" "error" ;;
        esac
        read -n 1 -s -r -p "按任意键返回主菜单..."
    done
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
    fi
    
    echo -e ""
    read -n 1 -s -r -p "按任意键继续..."
}

# 执行脚本
display_info
main_menu 