#!/usr/bin/env bash
# ==============================================================================
# Script Name: alpine-to-debian.sh
# Description: Alpine Linux 内存微系统自动过渡到 Debian / Ubuntu 重装脚本
# Reference:   NodeSeek #69759 (移动云电脑DD Linux 总结)
# Features:
#   1. 自动安装 wget / curl / bash / ca-certificates 等底层依赖
#   2. 智能探测中国大陆网络，自动切换 Gitee / 国内加速源
#   3. 支持 Debian (11/12/13) 与 Ubuntu (24.04/26.04) 跨系统重装
#   4. 支持自定义 root 密码与 SSH 端口
#   5. 专为移动云电脑、天翼云电脑等特殊虚拟化云电脑优化
# ==============================================================================

set -o pipefail

# 终端色彩
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_OS="debian"
OS_VER="12"
ROOT_PASS=""
SSH_PORT="22"
AUTO_CONFIRM=false
ZEROTIER_ID=""

# ----------------- 帮助信息 -----------------
show_help() {
    echo -e "${BOLD}${CYAN}Alpine -> Debian / Ubuntu 自动化转接安装脚本${NC}
${BOLD}用法:${NC}
  bash alpine-to-debian.sh [选项]

${BOLD}选项说明:${NC}
  -o, --os <系统>            目标操作系统 (可选: debian, ubuntu, 默认: debian)
  -v, --version <版本>       系统版本:
                              Debian: 12 (默认), 13 (Trixie), 11 (Bullseye)
                              Ubuntu: 24.04 (或 24), 26.04 (或 26), 22.04
  -p, --password <密码>      Linux root 密码 (留空则随机生成)
  -P, --port <端口>          SSH 连接端口 (默认: 22)
  -z, --zerotier <网络ID>    可选: ZeroTier Network ID
  -y, --yes                  静默直接安装 (不等待手动确认)
  -h, --help                 显示帮助信息"
    exit 0
}

# ----------------- 参数解析 -----------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--os)
            TARGET_OS="$2"
            shift 2
            ;;
        -v|--version)
            OS_VER="$2"
            shift 2
            ;;
        -p|--password)
            ROOT_PASS="$2"
            shift 2
            ;;
        -P|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -z|--zerotier)
            ZEROTIER_ID="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            shift
            ;;
    esac
done

# ----------------- 智能识别与规范化系统和版本 -----------------
# 若版本号符合 Ubuntu 特征且未显式指定 OS，自动判定为 Ubuntu
if [[ "$OS_VER" == "24" || "$OS_VER" == "24.04" || "$OS_VER" == "26" || "$OS_VER" == "26.04" || "$OS_VER" == "22" || "$OS_VER" == "22.04" ]]; then
    if [[ "$TARGET_OS" == "debian" && "$OS_VER" != "12" && "$OS_VER" != "13" && "$OS_VER" != "11" ]]; then
        TARGET_OS="ubuntu"
    fi
fi

TARGET_OS=$(echo "$TARGET_OS" | tr '[:upper:]' '[:lower:]')

if [[ "$TARGET_OS" == "ubuntu" ]]; then
    case "$OS_VER" in
        24|24.04) OS_VER="24.04"; OS_DISPLAY="Ubuntu 24.04 LTS (Noble)" ;;
        26|26.04) OS_VER="26.04"; OS_DISPLAY="Ubuntu 26.04 LTS (Resolute)" ;;
        22|22.04) OS_VER="22.04"; OS_DISPLAY="Ubuntu 22.04 LTS (Jammy)" ;;
        *) OS_VER="24.04"; OS_DISPLAY="Ubuntu 24.04 LTS" ;;
    esac
else
    TARGET_OS="debian"
    case "$OS_VER" in
        13) OS_VER="13"; OS_DISPLAY="Debian 13 (Trixie)" ;;
        11) OS_VER="11"; OS_DISPLAY="Debian 11 (Bullseye)" ;;
        12|*) OS_VER="12"; OS_DISPLAY="Debian 12 (Bookworm)" ;;
    esac
fi

# ----------------- 环境检查与依赖安装 -----------------
echo -e "${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}${GREEN}        正在为 Alpine 配置 ${OS_DISPLAY} 自动化重装环境        ${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"

echo -e "${GREEN}[1/4] 正在更新 Alpine 软件仓库并安装底层依赖...${NC}"
apk update >/dev/null 2>&1
apk add --no-cache wget curl bash ca-certificates openssl coreutils >/dev/null 2>&1

# ----------------- 智能网络检测 -----------------
echo -e "${GREEN}[2/4] 正在检测网络路由环境...${NC}"
IS_CHINA="false"
if curl -s --connect-timeout 3 https://cip.cc 2>/dev/null | grep -q '中国'; then
    IS_CHINA="true"
    echo -e "  * 网络节点: ${YELLOW}中国大陆节点 (启用国内镜像加速)${NC}"
else
    echo -e "  * 网络节点: ${YELLOW}海外/全球节点 (直连 GitHub 官方源)${NC}"
fi

# ----------------- 密码设置 -----------------
if [ -z "$ROOT_PASS" ]; then
    # 随机生成强密码
    PASS_PREFIX="Debian"
    if [ "$TARGET_OS" == "ubuntu" ]; then
        PASS_PREFIX="Ubuntu"
    fi
    ROOT_PASS="${PASS_PREFIX}#$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 8 || date +%s)"
fi

echo -e "\n${BOLD}${CYAN}----------------- 安装参数概览 -----------------${NC}"
echo -e "  目标系统:     ${YELLOW}${OS_DISPLAY} (64-bit)${NC}"
echo -e "  登录用户:     ${YELLOW}root${NC}"
echo -e "  登录密码:     ${YELLOW}${ROOT_PASS}${NC}"
echo -e "  SSH 端口:     ${YELLOW}${SSH_PORT}${NC}"
if [ -n "$ZEROTIER_ID" ]; then
    echo -e "  ZeroTier ID:  ${YELLOW}${ZEROTIER_ID}${NC}"
fi
echo -e "${BOLD}${CYAN}------------------------------------------------${NC}\n"

if [ "$AUTO_CONFIRM" = false ]; then
    echo -ne "${BOLD}确认开始安装 ${OS_DISPLAY}？(直接按回车继续，或 Ctrl+C 取消): ${NC}"
    read -r
fi

# ----------------- 下载重装引擎 -----------------
echo -e "\n${GREEN}[3/4] 正在拉取重装引擎 (InstallNET.sh)...${NC}"
INSTALLNET_URL="https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
if [ "$IS_CHINA" == "true" ]; then
    INSTALLNET_URL="https://gitee.com/mb9e8j2/Tools/raw/master/Linux_reinstall/InstallNET.sh"
fi

rm -f /InstallNET.sh
if ! wget --no-check-certificate -qO /InstallNET.sh "$INSTALLNET_URL"; then
    echo -e "${YELLOW}[WARN] 主源下载失败，尝试备用源...${NC}"
    wget --no-check-certificate -qO /InstallNET.sh "https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" || {
        echo -e "${RED}[ERROR] 下载 InstallNET.sh 失败，请检查网络！${NC}"
        exit 1
    }
fi
chmod +x /InstallNET.sh

# ----------------- 启动安装 -----------------
echo -e "${GREEN}[4/4] 正在启动 ${OS_DISPLAY} 底层写入与网络配置...${NC}"
echo -e "${YELLOW}提示: 脚本执行完毕后将自动重启，安装过程大约需要 5~15 分钟。${NC}"
sleep 2

bash /InstallNET.sh -"$TARGET_OS" "$OS_VER" -pwd "$ROOT_PASS" -port "$SSH_PORT"
RET=$?

if [ $RET -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}================================================================${NC}"
    echo -e "${BOLD}${GREEN}      ${OS_DISPLAY} 配置成功！系统即将在 5 秒后自动重启部署      ${NC}"
    echo -e "${BOLD}${GREEN}================================================================${NC}"
    echo -e " 登录账户:   ${YELLOW}root${NC}"
    echo -e " 登录密码:   ${YELLOW}${ROOT_PASS}${NC}"
    echo -e " SSH 端口:   ${YELLOW}${SSH_PORT}${NC}"
    echo -e " 进度观察:   可在移动云电脑官方客户端查看黑屏/安装滚屏"
    echo -e "${BOLD}${GREEN}================================================================${NC}\n"
    sleep 5
    reboot
else
    echo -e "${RED}[ERROR] ${OS_DISPLAY} 安装配置失败，请查看上方报错！${NC}"
    exit $RET
fi
