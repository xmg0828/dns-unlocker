#!/bin/bash

# DNS解锁脚本 - 适用于Debian系统
# 基于dnsmasq实现不同服务的DNS解锁

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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
    
    # 检查jq
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
        cat > "$SERVICES_FILE" << EOFMARKER
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
      "api.openai.com",
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
EOFMARKER
    fi
}

# 初始化配置
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}初始化配置文件...${NC}"
        cat > "$CONFIG_FILE" << EOFMARKER
{
  "dns_server": "8.8.8.8,8.8.4.4",
  "unlocked_services": {}
}
EOFMARKER
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
    rm -f $DNSMASQ_DIR/unlocker_*.conf
    
    # 更新配置文件
    echo '{"dns_server": "8.8.8.8,8.8.4.4", "unlocked_services": {}}' > $CONFIG_FILE
    
    # 重启dnsmasq
    systemctl restart dnsmasq
    
    echo -e "${GREEN}已重置所有DNS解锁配置${NC}"
}

# 显示当前解锁状态
show_status() {
    echo -e "${BLUE}当前DNS解锁状态:${NC}"
    echo -e "${CYAN}----------------------------${NC}"
    
    # 检查dnsmasq是否运行
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${GREEN}dnsmasq 服务状态: 运行中${NC}"
    else
        echo -e "${RED}dnsmasq 服务状态: 未运行${NC}"
    fi
    
    # 检查已解锁的服务
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}已解锁的服务:${NC}"
        jq -r '.unlocked_services | to_entries[] | "  \(.key): \(.value)"' $CONFIG_FILE
        
        # 显示当前DNS服务器
        DNS_SERVER=$(jq -r '.dns_server' $CONFIG_FILE)
        echo -e "${YELLOW}当前默认DNS服务器: ${DNS_SERVER}${NC}"
    else
        echo -e "${RED}配置文件不存在${NC}"
    fi
    
    echo -e "${CYAN}----------------------------${NC}"
}

# 配置基本dnsmasq设置
configure_dnsmasq_base() {
    echo -e "${BLUE}配置基本dnsmasq设置...${NC}"
    
    DNS_SERVER=$(jq -r '.dns_server' $CONFIG_FILE)
    
    # 基本配置
    cat > /etc/dnsmasq.conf << EOFMARKER
# DNS解锁配置 - 由dns-unlocker.sh生成

# 不使用/etc/hosts
no-hosts

# 启用conf.d目录
conf-dir=/etc/dnsmasq.d/,*.conf

# 缓存大小
cache-size=1024

# 使用上游DNS服务器
server=$DNS_SERVER

# 监听地址
listen-address=127.0.0.1

# 不使用resolv.conf
no-resolv

# 日志设置
log-queries
log-facility=/var/log/dnsmasq.log
EOFMARKER
}

# 为特定服务配置DNS解锁规则
configure_service() {
    SERVICE_CATEGORY=$1
    SERVICE_NAME=$2
    UNLOCK_IP=$3
    
    echo -e "${BLUE}为 $SERVICE_NAME 配置DNS解锁规则 (使用IP: $UNLOCK_IP)...${NC}"
    
    # 获取服务的域名列表
    DOMAINS=$(jq -r ".$SERVICE_CATEGORY.\"$SERVICE_NAME\"[]" $SERVICES_FILE)
    
    # 创建配置文件
    CONFIG_FILE_NAME="${DNSMASQ_DIR}/unlocker_${SERVICE_NAME// /_}.conf"
    
    echo "# DNS解锁配置 - $SERVICE_NAME" > $CONFIG_FILE_NAME
    
    # 添加每个域名的解析规则
    for DOMAIN in $DOMAINS; do
        echo "address=/$DOMAIN/$UNLOCK_IP" >> $CONFIG_FILE_NAME
    done
    
    # 更新配置文件中的解锁服务列表
    jq --arg service "$SERVICE_NAME" --arg ip "$UNLOCK_IP" '.unlocked_services[$service] = $ip' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    
    echo -e "${GREEN}$SERVICE_NAME 的DNS解锁规则已配置${NC}"
}

# 修改系统DNS配置
configure_system_dns() {
    echo -e "${BLUE}配置系统DNS设置...${NC}"
    
    # 修改resolv.conf以使用本地dnsmasq
    cat > /etc/resolv.conf << EOFMARKER
# Generated by dns-unlocker.sh
nameserver 127.0.0.1
EOFMARKER
    
    echo -e "${GREEN}系统DNS已设置为使用本地dnsmasq${NC}"
}

# 设置DNS服务器
set_dns_server() {
    echo -e "${YELLOW}请输入默认DNS服务器 (格式: 8.8.8.8,8.8.4.4):${NC}"
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
                    echo -e "${RED}错误: IP地址不能为空${NC}"
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
                return
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# AI服务解锁菜单
ai_menu() {
    while true; do
        clear
        echo -e "${CYAN}===== AI服务解锁菜单 =====${NC}"
        echo -e "${YELLOW}1. OpenAI (ChatGPT)${NC}"
        echo -e "${YELLOW}2. Claude${NC}"
        echo -e "${YELLOW}3. Google Gemini${NC}"
        echo -e "${YELLOW}0. 返回主菜单${NC}"
        echo -e "${CYAN}=========================${NC}"
        echo -ne "${GREEN}请选择要解锁的服务: ${NC}"
        read choice
        
        case $choice in
            1)
                echo -ne "${GREEN}请输入用于解锁 OpenAI 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "ai" "OpenAI" $ip
                ;;
            2)
                echo -ne "${GREEN}请输入用于解锁 Claude 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "ai" "Claude" $ip
                ;;
            3)
                echo -ne "${GREEN}请输入用于解锁 Gemini 的IP地址: ${NC}"
                read ip
                if [ -z "$ip" ]; then
                    echo -e "${RED}错误: IP地址不能为空${NC}"
                    sleep 2
                    continue
                fi
                configure_service "ai" "Gemini" $ip
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 添加自定义域名解锁菜单
custom_domain_menu() {
    clear
    echo -e "${CYAN}===== 自定义域名解锁 =====${NC}"
    echo -ne "${GREEN}请输入要解锁的域名 (如: example.com): ${NC}"
    read domain
    
    if [ -z "$domain" ]; then
        echo -e "${RED}错误: 域名不能为空${NC}"
        sleep 2
        return
    fi
    
    echo -ne "${GREEN}请输入用于解锁 $domain 的IP地址: ${NC}"
    read ip
    
    if [ -z "$ip" ]; then
        echo -e "${RED}错误: IP地址不能为空${NC}"
        sleep 2
        return
    fi
    
    # 创建配置文件
    CONFIG_FILE_NAME="${DNSMASQ_DIR}/unlocker_custom_${domain//./_}.conf"
    
    echo "# DNS解锁配置 - 自定义域名: $domain" > $CONFIG_FILE_NAME
    echo "address=/$domain/$ip" >> $CONFIG_FILE_NAME
    
    # 更新配置文件中的解锁服务列表
    jq --arg service "自定义: $domain" --arg ip "$ip" '.unlocked_services[$service] = $ip' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    
    echo -e "${GREEN}自定义域名 $domain 的DNS解锁规则已配置${NC}"
    sleep 2
}

# 应用配置并重启服务
apply_config() {
    echo -e "${BLUE}应用配置并重启服务...${NC}"
    
    # 重启dnsmasq服务
    systemctl restart dnsmasq
    
    # 检查dnsmasq是否成功启动
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${GREEN}dnsmasq服务已成功重启${NC}"
    else
        echo -e "${RED}dnsmasq服务启动失败，请检查配置${NC}"
        # 显示错误日志
        echo -e "${YELLOW}dnsmasq错误日志:${NC}"
        journalctl -u dnsmasq -n 10
    fi
    
    echo -e "${GREEN}所有配置已应用${NC}"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}======================================${NC}"
        echo -e "${CYAN}          DNS解锁脚本 v1.0           ${NC}"
        echo -e "${CYAN}======================================${NC}"
        echo -e "${YELLOW}1. 流媒体服务解锁 (Netflix/Disney+/TikTok)${NC}"
        echo -e "${YELLOW}2. AI服务解锁 (OpenAI/Claude/Gemini)${NC}"
        echo -e "${YELLOW}3. 添加自定义域名解锁${NC}"
        echo -e "${YELLOW}4. 设置默认DNS服务器${NC}"
        echo -e "${YELLOW}5. 应用配置并重启服务${NC}"
        echo -e "${YELLOW}6. 显示当前解锁状态${NC}"
        echo -e "${YELLOW}7. 重置所有配置${NC}"
        echo -e "${YELLOW}0. 退出${NC}"
        echo -e "${CYAN}======================================${NC}"
        echo -ne "${GREEN}请选择操作: ${NC}"
        read choice
        
        case $choice in
            1)
                streaming_menu
                ;;
            2)
                ai_menu
                ;;
            3)
                custom_domain_menu
                ;;
            4)
                set_dns_server
                ;;
            5)
                configure_dnsmasq_base
                configure_system_dns
                apply_config
                echo -e "${GREEN}按任意键继续...${NC}"
                read -n 1 || read
                ;;
            6)
                show_status
                echo -e "${GREEN}按任意键继续...${NC}"
                read -n 1 || read
                ;;
            7)
                echo -ne "${RED}确定要重置所有配置吗? (y/n): ${NC}"
                read confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    reset_dnsmasq_conf
                fi
                echo -e "${GREEN}按任意键继续...${NC}"
                read -n 1 || read
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
    check_install
    
    # 初始化服务列表和配置
    init_services
    init_config
    
    # 备份dnsmasq配置
    backup_dnsmasq_conf
    
    # 显示主菜单
    main_menu
}

# 运行主函数
main
