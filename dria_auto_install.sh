#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
WARNING_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'
MENU_COLOR='\033[1;34m'

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
    apt update -y && apt upgrade -y
    apt-get dist-upgrade -y
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
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update -y && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    docker --version && display_status "Docker 安装成功。" "success" || display_status "Docker 安装失败。" "error"
}

# 安装 Ollama
install_ollama() {
    display_status "正在安装 Ollama..." "info"
    curl -fsSL https://ollama.com/install.sh | sh && display_status "Ollama 安装成功。" "success" || display_status "Ollama 安装失败。" "error"
}

# 安装 Dria 节点 - 使用官方安装脚本
install_dria_node() {
    display_status "正在安装 Dria 计算节点..." "info"
    curl -fsSL https://dria.co/launcher | bash && display_status "Dria 计算节点安装成功。" "success" || display_status "Dria 计算节点安装失败。" "error"
    
    # 创建一个启动脚本以便于以后的运行
    cat > /usr/local/bin/start-dria << 'EOF'
#!/bin/bash
cd $HOME
dkn-compute-launcher start
EOF
    chmod +x /usr/local/bin/start-dria
    display_status "启动脚本已创建: /usr/local/bin/start-dria" "success"
}

# Dria 节点管理功能
manage_dria_node() {
    display_status "Dria 节点管理" "info"
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
        # 尝试下载并显示 logo
        if command -v curl &> /dev/null; then
            curl -s https://raw.githubusercontent.com/ziqing888/logo.sh/refs/heads/main/logo.sh | bash 2>/dev/null || echo "DRIA 节点管理工具"
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
        echo -e "${MENU_COLOR}6. 退出${NORMAL}"
        read -p "请输入选项（1-6）: " OPTION

        case $OPTION in
            1) setup_prerequisites ;;
            2) install_docker ;;
            3) install_ollama ;;
            4) install_dria_node ;;
            5) manage_dria_node ;;
            6) exit 0 ;;
            *) display_status "无效选项，请重试。" "error" ;;
        esac
        read -n 1 -s -r -p "按任意键返回主菜单..."
    done
}

# 显示脚本信息
display_info() {
    clear
    echo -e "${INFO_COLOR}${BOLD}=========================================================================${NORMAL}"
    echo -e "${INFO_COLOR}${BOLD}                     Dria 计算节点自动安装脚本                           ${NORMAL}"
    echo -e "${INFO_COLOR}${BOLD}=========================================================================${NORMAL}"
    echo -e ""
    echo -e "${INFO_COLOR}此脚本将帮助您在 Ubuntu 系统上自动安装和配置 Dria 计算节点。${NORMAL}"
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
    echo -e ""
    read -n 1 -s -r -p "按任意键继续..."
}

# 执行脚本
display_info
main_menu 