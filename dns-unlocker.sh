              show_status
                echo -e "${GREEN}按任意键继续...${NC}"
                read -n 1
                ;;
            7)
                echo -ne "${RED}确定要重置所有配置吗? (y/n): ${NC}"
                read confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    reset_dnsmasq_conf
                fi
                echo -e "${GREEN}按任意键继续...${NC}"
                read -n 1
                ;;
            0)
                echo -e "${GREEN}感谢使用DNS解锁脚本!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 主函数
main() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}        DNS解锁脚本安装向导         ${NC}"
    echo -e "${CYAN}======================================${NC}"
    
    # 检查并安装必要的软件包
    chec
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}安装jq...${NC}"
        apt-get install -y jq
    fi
    
    echo -e "${GREEN}所有必要的软件包已安装${NC}"
}

# 初始化服务列表
init_services() {
    if [ ! -f "$SERVICES_FILE" ]; then
        echo -e "${BLUE}初始化服务列表...${NC}"
        cat > "$SERVICES_FILE" << EOF
{
  "streaming": {
    "Netflix": [
      "netflix.com",
      "nflxext.com",
      "nflximg.com",
      "nflximg.net",
      "nflxvideo.net",
      "nflxso.net",
      "netflix.net"
    ],
    "Disney+": [
      "disney.com",
      "disney-plus.net",
      "dssott.com",
      "disneyplus.com",
      "bamgrid.com",
      "disney-portal.my.onetrust.com",
      "disneystreaming.com"
    ],
    "TikTok": [
      "tiktok.com",
      "tiktokv.com",
      "tiktokcdn.com",
      "tiktokcdn-us.com",
      "tik-tokapi.com",
      "muscdn.com"
    ]
  },
  "ai": {
    "OpenAI": [
      "openai.com",
      "ai.com",
      "chat.openai.com",
      "api.openai.c: 8.8.8.8,8.8.4.4):${NC}"
    read DNS_SERVER
    
    if [ -z "$DNS_SERVER" ]; then
        DNS_SERVER="8.8.8.8,8.8.4.4"
    fi
    
    # 更新配置文件
    jq --arg dns "$DNS_SERVER" '.dns_server = $dns' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    
    echo -e "${GREEN}默认DNS服务器已设置为: $DNS_SERVER${NC}"
}

# 流媒体服务解锁菜单
streaming_menu() {
    while true; do
        clear
        echo -e "${CYAN}===== 流媒体服务解锁菜单 =====${NC}"
        echo -e "${YELLOW}1. Netflix${NC}"
        echo -e "${YELLOW}2. Disney+${NC}"
        echo -e "${YELLOW}3. TikTok${NC}"
        echo -e "${YELLOW}0. 返回主菜单${NC}"
        echo -e "${CYAN}=============================${NC}"
        echo -ne "${GREEN}请选择要解锁的服务: ${NC}"
        read choice
        
        case $choice in
            1)
                echo -ne "${GREEN}请输入用于解锁 Netflix 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
 #!/bin/bash

# DNS解锁脚本 - 适用于Debian系统
# 基于dnsmasq实现不同服务的DNS解锁

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
   echo -e "${YELLOW}请使用 sudo ./dns-unlocker.sh 运行此脚本${NC}"
   exit 1
fi

# 配置文件路径
CONFIG_DIR="/etc/dns-unlocker"
DNSMASQ_DIR="/etc/dnsmasq.d"
SERVICES_FILE="$CONFIG_DIR/services.json"
CONFIG_FILE="$CONFIG_DIR/config.json"

# 创建配置目录
mkdir -p $CONFIG_DIR
mkdir -p $DNSMASQ_DIR

# 检查并安装必要的软件包
check_install() {
    echo -e "${BLUE}正在检查必要的软件包...${NC}"
    
    # 检查dnsmasq
    if ! command -v dnsmasq &> /dev/null; then
        echo -e "${YELLOW}安装dnsmasq...${NC}"
        apt-get update
        apt-get install -y dnsmasq
    fi
    
    # 检查jqk_install
    
    # 初始化服务列表和配置
    init_services
    init_config
    
    # 备份dnsmasq配置
    backup_dnsmasq_conf
    
    # 显示主菜单
    main_menu
}

# 运行主函数
mainom",
      "platform.openai.com"
    ],
    "Claude": [
      "anthropic.com",
      "claude.ai",
      "api.anthropic.com"
    ],
    "Gemini": [
      "gemini.google.com",
      "bard.google.com",
      "generativelanguage.googleapis.com"
    ]
  }
}
EOF
    fi
}

# 初始化配置
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}初始化配置文件...${NC}"
        cat > "$CONFIG_FILE" << EOF
{
  "dns_server": "8.8.8.8,8.8.4.4",
  "unlocked_services": {}
}
EOF
    fi
}

# 备份当前dnsmasq配置
backup_dnsmasq_conf() {
    echo -e "${BLUE}备份当前dnsmasq配置...${NC}"
    if [ ! -f "/etc/dnsmasq.conf.bak" ]; then
        cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    fi
}

# 重置dnsmasq配置
reset_dnsmasq_conf() {
    echo -e "${BLUE}重置dnsmasq配置...${NC}"
    
    # 恢复原始配置
    if [ -f "/etc/dnsmasq.conf.bak" ]; then
        cp /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
    fi
    
    # 清除解锁服务的配置文件
    rm -f $DNSMASQ_DIR/unlocker                   echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "streaming" "Netflix" $ip
                ;;
            2)
                echo -ne "${GREEN}请输入用于解锁 Disney+ 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "streaming" "Disney+" $ip
                ;;
            3)
                echo -ne "${GREEN}请输入用于解锁 TikTok 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "streaming" "TikTok" $ip
                ;;
            0)
               
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}安装jq...${NC}"
        apt-get install -y jq
    fi
    
    echo -e "${GREEN}所有必要的软件包已安装${NC}"
}

# 初始化服务列表
init_services() {
    if [ ! -f "$SERVICES_FILE" ]; then
        echo -e "${BLUE}初始化服务列表...${NC}"
        cat > "$SERVICES_FILE" << EOF
{
  "streaming": {
    "Netflix": [
      "netflix.com",
      "nflxext.com",
      "nflximg.com",
      "nflximg.net",
      "nflxvideo.net",
      "nflxso.net",
      "netflix.net"
    ],
    "Disney+": [
      "disney.com",
      "disney-plus.net",
      "dssott.com",
      "disneyplus.com",
      "bamgrid.com",
      "disney-portal.my.onetrust.com",
      "disneystreaming.com"
    ],
    "TikTok": [
      "tiktok.com",
      "tiktokv.com",
      "tiktokcdn.com",
      "tiktokcdn-us.com",
      "tik-tokapi.com",
      "muscdn.com"
    ]
  },
  "ai": {
    "OpenAI": [
      "openai.com",
      "ai.com",
      "chat.openai.com",
      "api.openai.c