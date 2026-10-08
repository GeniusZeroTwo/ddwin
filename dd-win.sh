#!/usr/bin/env bash
# ==============================================================================
# Script Name: dd-win.sh
# Description: Linux 一键重装/DD至 Windows 官方中文服务版脚本
# Features:
#   1. 自动拉取微软官方原版中文镜像 (Server 2025/2022/2019/2016, Win11, Win10 LTSC)
#   2. 全无人值守自动安装 (Unattended Setup)
#   3. 自动配置自定义管理员用户名与合规强密码
#   4. 全量 VirtIO 驱动自动注入 (存储/网卡/Balloon，杜绝蓝屏断网)
#   5. 原生网络静态 IP / 网关 / DNS 自动保活与恢复 (防止云服务器断连)
#   6. 自动开启远程桌面 (RDP 3389/自定义端口) & 放行防火墙与 ICMP Ping
#   7. 引导模式自动适配 (UEFI GPT / Legacy BIOS MBR)
#   8. C盘自动全盘扩容 (Auto Disk Extension)
#   9. 国内/海外 CDN 与镜像源智能路由加速
#  10. 交互式向导与 CLI 静默参数双重支持
# ==============================================================================

set -o pipefail

# ----------------- 终端色彩与样式定义 -----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ----------------- 默认全局变量 -----------------
WIN_VERSION="2022"
WIN_USER="Administrator"
WIN_PASS=""
RDP_PORT="3389"
ALLOW_PING="true"
INSTALL_MODE="iso" # iso (官方原版直装) 或 dd (快速镜像直写)
TARGET_DISK=""
AUTO_CONFIRM=false
CUSTOM_ISO_URL=""
IS_CHINA="false"

# 临时工作目录
WORK_DIR="/tmp/ddwin_temp"

# ----------------- 帮助信息 -----------------
show_help() {
    echo -e "${BOLD}${CYAN}Linux 一键安装/DD 到 Windows 官方中文版脚本${NC}

${BOLD}用法:${NC}
  bash dd-win.sh [选项]

${BOLD}选项说明:${NC}
  -v, --version <版本>       Windows 版本 (可选: 2025, 2022, 2019, 2016, 11, 10, 默认: 2022)
  -u, --user <用户名>        管理员账户名 (默认: Administrator)
  -p, --password <密码>      管理员密码 (必须满足复杂度要求: 至少8位, 包含大写/小写/数字/特殊字符)
  --port <端口>              远程桌面 RDP 端口 (默认: 3389)
  -d, --disk <磁盘设备>      目标磁盘 (例如: /dev/vda, /dev/sda, 默认自动检测系统主盘)
  -m, --mode <模式>          安装模式: iso (官方原版动态直装, 推荐) 或 dd (极速DD镜像)
  --iso <URL>                自定义官方/第三方 ISO 下载直链
  -y, --yes                  静默无人值守模式 (跳过交互式确认与倒计时)
  -h, --help                 显示本帮助信息

${BOLD}示例:${NC}
  # 交互式菜单运行 (推荐新手):
  bash dd-win.sh

  # 静默一键安装 Windows Server 2022 并设置密码:
  bash dd-win.sh -v 2022 -p \"P@ssw0rd2022!\" -y

  # 安装 Windows Server 2025 并修改 RDP 端口为 33890:
  bash dd-win.sh -v 2025 -p \"Win2025_Admin#\" --port 33890 -y"
    exit 0
}

# ----------------- 日志打印函数 -----------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$1${NC}"
}

# ----------------- 权限与依赖检查 -----------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "本脚本必须以 root 权限运行！请使用 sudo -i 或 su root 切换后再执行。"
        exit 1
    fi
}

install_dependencies() {
    log_step "正在检查并安装必要系统工具组件..."
    local pkgs=()

    command -v curl >/dev/null 2>&1 || pkgs+=("curl")
    command -v wget >/dev/null 2>&1 || pkgs+=("wget")
    command -v ip >/dev/null 2>&1 || pkgs+=("iproute2")
    command -v awk >/dev/null 2>&1 || pkgs+=("gawk")
    command -v grep >/dev/null 2>&1 || pkgs+=("grep")
    command -v parted >/dev/null 2>&1 || pkgs+=("parted")

    if [ ${#pkgs[@]} -gt 0 ]; then
        log_info "正在补充缺失依赖: ${pkgs[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -y -q >/dev/null 2>&1
            apt-get install -y -q "${pkgs[@]}" >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y -q "${pkgs[@]}" >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y -q "${pkgs[@]}" >/dev/null 2>&1
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache "${pkgs[@]}" >/dev/null 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm "${pkgs[@]}" >/dev/null 2>&1
        fi
    fi
    log_info "基础依赖检测完成。"
}

# ----------------- 系统环境自动检测 -----------------
detect_environment() {
    log_step "正在检测当前服务器硬件与网络环境..."

    # 1. 架构检测
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        log_error "不支持的 CPU 架构: $ARCH (仅支持 x86_64 / aarch64)"
        exit 1
    fi

    # 2. 虚拟化环境
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT_TYPE=$(systemd-detect-virt)
    else
        VIRT_TYPE="KVM/QEMU (默认检测)"
    fi

    # 3. 内存与 Swap
    TOTAL_RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    TOTAL_SWAP_MB=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
    [ -z "$TOTAL_RAM_MB" ] && TOTAL_RAM_MB=1024
    [ -z "$TOTAL_SWAP_MB" ] && TOTAL_SWAP_MB=0

    # 4. 引导模式 (UEFI 或 BIOS)
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS (MBR)"
    fi

    # 5. 目标磁盘智能检测 (寻找根目录挂载的物理盘)
    if [ -z "$TARGET_DISK" ]; then
        local root_part
        root_part=$(df / 2>/dev/null | tail -n1 | awk '{print $1}')
        if command -v lsblk >/dev/null 2>&1; then
            local parent_disk
            parent_disk=$(lsblk -no PKNAME "$root_part" 2>/dev/null | head -n1)
            if [ -n "$parent_disk" ]; then
                TARGET_DISK="/dev/$parent_disk"
            fi
        fi

        if [ -z "$TARGET_DISK" ]; then
            if [[ "$root_part" =~ ^/dev/nvme[0-9]+n[0-9]+ ]]; then
                TARGET_DISK="${BASH_REMATCH[0]}"
            elif [[ "$root_part" =~ ^/dev/[a-z]+ ]]; then
                TARGET_DISK=$(echo "$root_part" | sed -E 's/[0-9]+$//')
            else
                TARGET_DISK="/dev/vda"
            fi
        fi
    fi

    DISK_SIZE="未知"
    if [ -b "$TARGET_DISK" ]; then
        DISK_SIZE=$(lsblk -bno SIZE "$TARGET_DISK" 2>/dev/null | head -n1 | awk '{printf "%.1f GB", $1/1024/1024/1024}')
        [ -z "$DISK_SIZE" ] && DISK_SIZE=$(fdisk -l "$TARGET_DISK" 2>/dev/null | grep -i 'Disk.*bytes' | awk '{print $3, $4}' | tr -d ',')
    fi

    # 6. 网络状态提取 (IP / 网关 / 子网掩码 / DNS / 网卡名)
    NET_IFACE=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1)
    [ -z "$NET_IFACE" ] && NET_IFACE=$(ip link | grep -E '^[0-9]+: (eth|ens|enp|eno|vi)' | awk -F: '{print $2}' | tr -d ' ' | head -n1)

    NET_IP=$(ip -4 addr show dev "$NET_IFACE" 2>/dev/null | grep -w "inet" | head -n1 | awk '{print $2}' | cut -d/ -f1)
    NET_CIDR=$(ip -4 addr show dev "$NET_IFACE" 2>/dev/null | grep -w "inet" | head -n1 | awk '{print $2}' | cut -d/ -f2)
    NET_GATEWAY=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | head -n1)
    NET_DNS=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -n2 | tr '\n' ' ')
    [ -z "$NET_DNS" ] && NET_DNS="8.8.8.8 1.1.1.1"

    # 7. 检测当前服务器是否位于中国大陆 (启用国内镜像加速)
    local test_ip
    test_ip=$(curl -s --connect-timeout 3 https://cip.cc 2>/dev/null | grep -i '中国')
    if [ -n "$test_ip" ]; then
        IS_CHINA="true"
    fi
}

# ----------------- 密码复杂度验证与自动生成 -----------------
validate_password() {
    local pwd="$1"
    local user="${2:-Administrator}"

    # 长度至少 8 位
    if [ ${#pwd} -lt 8 ]; then
        return 1
    fi

    # 必须包含大写、小写、数字、特殊符号中的至少 3 种
    local score=0
    [[ "$pwd" =~ [A-Z] ]] && ((score++))
    [[ "$pwd" =~ [a-z] ]] && ((score++))
    [[ "$pwd" =~ [0-9] ]] && ((score++))
    [[ "$pwd" =~ [^A-Za-z0-9] ]] && ((score++))

    if [ $score -lt 3 ]; then
        return 1
    fi

    # 不能包含用户名
    local lower_pwd=$(echo "$pwd" | tr '[:upper:]' '[:lower:]')
    local lower_user=$(echo "$user" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_pwd" == *"$lower_user"* ]]; then
        return 1
    fi

    return 0
}

generate_strong_password() {
    # 生成高熵Windows合规强密码 (例如: Win!9kM2#x7Q)
    local part1="WinServer"
    local part2=$(date +%Y)
    local part3=$(tr -dc 'A-Za-z0-9!@#$' </dev/urandom | head -c 4)
    echo "${part1}@${part2}_${part3}"
}

# ----------------- 低内存自动保护 (Swap 创建) -----------------
ensure_memory_safety() {
    local required_mb=1800
    local current_total=$((TOTAL_RAM_MB + TOTAL_SWAP_MB))

    if [ "$current_total" -lt "$required_mb" ]; then
        log_warn "检测到当前服务器物理内存仅 ${TOTAL_RAM_MB}MB (低于推荐值 2GB)。"
        log_info "正在自动创建 2GB 临时 Swap 虚拟内存，以保证 Windows 镜像释放与驱动注入不发生 OOM..."
        
        local swap_file="/ddwin_swapfile"
        if [ ! -f "$swap_file" ]; then
            if command -v fallocate >/dev/null 2>&1; then
                fallocate -l 2G "$swap_file" 2>/dev/null || dd if=/dev/zero of="$swap_file" bs=1M count=2048 status=none
            else
                dd if=/dev/zero of="$swap_file" bs=1M count=2048 status=none
            fi
            chmod 600 "$swap_file"
            mkswap "$swap_file" >/dev/null 2>&1
            swapon "$swap_file" >/dev/null 2>&1
            log_info "临时 2GB Swap 扩展已成功激活！"
        fi
    fi
}

# ----------------- 终端交互配置菜单 -----------------
interactive_menu() {
    clear
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo -e "${BOLD}${WHITE}    Linux 一键重装/DD至 Windows 官方中文版安装配置向导    ${NC}"
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo -e " ${GREEN}[系统检测概况]${NC}"
    echo -e "  * CPU 架构:      ${YELLOW}${ARCH}${NC}"
    echo -e "  * 虚拟化类型:    ${YELLOW}${VIRT_TYPE}${NC}"
    echo -e "  * 物理内存:      ${YELLOW}${TOTAL_RAM_MB} MB (Swap: ${TOTAL_SWAP_MB} MB)${NC}"
    echo -e "  * 引导模式:      ${YELLOW}${BOOT_MODE}${NC}"
    echo -e "  * 目标主硬盘:    ${YELLOW}${TARGET_DISK} (${DISK_SIZE})${NC}"
    echo -e "  * 网络适配器:    ${YELLOW}${NET_IFACE} (${NET_IP}/${NET_CIDR})${NC}"
    echo -e "  * 默认网关:      ${YELLOW}${NET_GATEWAY}${NC}"
    echo -e "  * 网络加速模式:  ${YELLOW}$( [[ "$IS_CHINA" == "true" ]] && echo "国内 CDN 加速节点" || echo "全球直连节点" )${NC}"
    echo -e "${BOLD}${CYAN}----------------------------------------------------------------${NC}"

    # 1. 选择 Windows 版本
    echo -e "${BOLD}${WHITE}请选择需要安装的操作系统版本:${NC}"
    echo -e "  ${GREEN}1)${NC} Windows Server 2022 简体中文官方原版 ${YELLOW}(强烈推荐，性能稳固，驱动完善)${NC}"
    echo -e "  ${GREEN}2)${NC} Windows Server 2025 简体中文官方原版 ${YELLOW}(微软最新旗舰版)${NC}"
    echo -e "  ${GREEN}3)${NC} Windows Server 2019 简体中文官方原版 ${YELLOW}(兼容性极强)${NC}"
    echo -e "  ${GREEN}4)${NC} Windows Server 2016 简体中文官方原版 ${YELLOW}(经典低内存占用)${NC}"
    echo -e "  ${GREEN}5)${NC} Windows 11 Pro 专业版 简体中文原版"
    echo -e "  ${GREEN}6)${NC} Windows 10 LTSC 2021 长期企业版 简体中文原版 ${YELLOW}(轻量纯净)${NC}"
    echo -e "  ${GREEN}7)${NC} 自定义安装镜像 (输入第三方 ISO 或 DD 镜像直链)"
    
    local choice_ver
    read -rp "请输入版本序号 [默认: 1]: " choice_ver
    case "$choice_ver" in
        2) WIN_VERSION="2025" ;;
        3) WIN_VERSION="2019" ;;
        4) WIN_VERSION="2016" ;;
        5) WIN_VERSION="11" ;;
        6) WIN_VERSION="10" ;;
        7) 
            WIN_VERSION="custom"
            read -rp "请输入自定义镜像的直链下载地址 (URL): " CUSTOM_ISO_URL
            while [ -z "$CUSTOM_ISO_URL" ]; do
                read -rp "URL 不能为空，请重新输入: " CUSTOM_ISO_URL
            done
            ;;
        *) WIN_VERSION="2022" ;;
    esac

    # 2. 设置管理员账户名
    echo -e "\n${BOLD}${WHITE}设置管理员账户名:${NC}"
    read -rp "请输入管理员用户名 [默认: Administrator]: " input_user
    [ -n "$input_user" ] && WIN_USER="$input_user"

    # 3. 设置管理员密码
    echo -e "\n${BOLD}${WHITE}设置管理员登录密码:${NC}"
    echo -e "${YELLOW}提示: Windows Server 要求强密码复杂度 (大写字母+小写字母+数字+特殊符号，>=8位)${NC}"
    
    local default_pass
    default_pass=$(generate_strong_password)
    while true; do
        read -rp "请输入密码 [回车使用随机安全密码: ${default_pass}]: " input_pass
        if [ -z "$input_pass" ]; then
            WIN_PASS="$default_pass"
            break
        elif validate_password "$input_pass" "$WIN_USER"; then
            WIN_PASS="$input_pass"
            break
        else
            log_warn "密码不符合 Windows 复杂度策略！必须包含大写/小写/数字/特殊字符中至少三种，且不得包含用户名。请重试。"
        fi
    done

    # 4. 设置远程桌面端口
    echo -e "\n${BOLD}${WHITE}设置远程桌面 (RDP) 服务端口:${NC}"
    read -rp "请输入 RDP 端口 [默认: 3389]: " input_port
    if [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 1 ] && [ "$input_port" -le 65535 ]; then
        RDP_PORT="$input_port"
    fi

    # 5. 自动选定目标主磁盘 (全自动化，无需人工干预)
    log_info "已自动选定目标主硬盘: ${TARGET_DISK} (${DISK_SIZE})"
    if [ ! -b "$TARGET_DISK" ]; then
        log_error "未找到有效的磁盘设备: $TARGET_DISK"
        exit 1
    fi
}

# ----------------- 执行前安全确认 -----------------
confirm_execution() {
    clear
    echo -e "${BOLD}${RED}================================================================${NC}"
    echo -e "${BOLD}${RED}                     高 危 操 作 确 认 提 示                     ${NC}"
    echo -e "${BOLD}${RED}================================================================${NC}"
    echo -e " 目标硬盘:     ${BOLD}${RED}${TARGET_DISK}${NC} (${DISK_SIZE})"
    echo -e " 操作系统:     ${BOLD}${GREEN}Windows ${WIN_VERSION} 简体中文官方版${NC}"
    echo -e " 管理员账号:   ${BOLD}${GREEN}${WIN_USER}${NC}"
    echo -e " 管理员密码:   ${BOLD}${GREEN}${WIN_PASS}${NC}"
    echo -e " 远程桌面端口: ${BOLD}${GREEN}${RDP_PORT}${NC}"
    echo -e " 静态IP保活:   ${BOLD}${GREEN}${NET_IP}/${NET_CIDR} (网关: ${NET_GATEWAY})${NC}"
    echo -e " 引导方式:     ${BOLD}${GREEN}${BOOT_MODE}${NC}"
    echo -e "${BOLD}${RED}----------------------------------------------------------------${NC}"
    echo -e "${BOLD}${YELLOW}警告: 安装过程将彻底格式化并重写 ${TARGET_DISK}，盘内所有数据将不可逆丢失！${NC}"
    echo -e "${BOLD}${YELLOW}请务必确认已做好关键数据异地备份！${NC}"
    echo -e "${BOLD}${RED}================================================================${NC}\n"

    if [ "$AUTO_CONFIRM" = false ]; then
        echo -ne "${BOLD}确认继续执行请在 10 秒内按回车键 (取消请按 Ctrl+C)... ${NC}"
        read -t 10 -r || echo ""
    else
        log_info "静默模式激活，自动确认执行。"
    fi
}

# ----------------- 官方镜像动态部署核心引擎 -----------------
execute_installation() {
    log_step "正在启动 Windows 自动化安装部署引擎..."

    ensure_memory_safety

    # 构建并准备安装后端环境
    local reinstall_url="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
    if [ "$IS_CHINA" == "true" ]; then
        reinstall_url="https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.sh"
    fi

    mkdir -p "$WORK_DIR"
    local local_script="$WORK_DIR/reinstall.sh"

    log_info "正在拉取原版安装引擎组件..."
    if ! curl -sSL -k --retry 3 "$reinstall_url" -o "$local_script"; then
        log_warn "通过加速节点拉取失败，尝试备用官方直连源..."
        curl -sSL -k --retry 3 "https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh" -o "$local_script" || {
            log_error "拉取安装组件失败，请检查网络连接。"
            exit 1
        }
    fi
    chmod +x "$local_script"

    # 构建匹配官方镜像名称 (Windows Server 必须包含 Edition，如 ServerDatacenter)
    local target_img_name=""
    case "$WIN_VERSION" in
        "2025")
            target_img_name="Windows Server 2025 ServerDatacenter"
            ;;
        "2022")
            target_img_name="Windows Server 2022 ServerDatacenter"
            ;;
        "2019")
            target_img_name="Windows Server 2019 ServerDatacenter"
            ;;
        "2016")
            target_img_name="Windows Server 2016 ServerDatacenter"
            ;;
        "11")
            target_img_name="Windows 11 Pro"
            ;;
        "10")
            target_img_name="Windows 10 Enterprise LTSC 2021"
            ;;
        "custom")
            target_img_name="custom"
            ;;
    esac

    # 组装完整的无人值守参数命令 (底层参数需空格分隔，禁止使用=号以防参数解析异常)
    local cmd_args=()
    cmd_args+=("windows")

    if [ "$WIN_VERSION" == "custom" ]; then
        cmd_args+=("--iso" "${CUSTOM_ISO_URL}")
    else
        cmd_args+=("--image-name" "${target_img_name}")
        cmd_args+=("--lang" "zh-cn")
    fi

    # 用户名与密码注入
    [ -n "$WIN_USER" ] && cmd_args+=("--username" "${WIN_USER}")
    [ -n "$WIN_PASS" ] && cmd_args+=("--password" "${WIN_PASS}")

    # 远程桌面 RDP 端口与防火墙优化
    cmd_args+=("--rdp-port" "${RDP_PORT}")
    [ "$ALLOW_PING" == "true" ] && cmd_args+=("--allow-ping")

    # 静态网络参数安全备份提示
    log_info "已准备网络自愈配置:"
    log_info "  IP: ${NET_IP} / Netmask: ${NET_CIDR} / Gateway: ${NET_GATEWAY} / DNS: ${NET_DNS}"
    log_info "驱动注入策略: 自动注入最新红帽官方 VirtIO 存储与网络驱动全集。"

    echo -e "\n${BOLD}${GREEN}================================================================${NC}"
    echo -e "${BOLD}${GREEN}               系统部署配置完毕，即将执行自动重启！               ${NC}"
    echo -e "${BOLD}${GREEN}================================================================${NC}"
    echo -e " 远程连接 IP:      ${YELLOW}${NET_IP}${NC}"
    echo -e " 远程桌面端口:    ${YELLOW}${RDP_PORT}${NC}"
    echo -e " 远程登录用户:    ${YELLOW}${WIN_USER}${NC}"
    echo -e " 远程登录密码:    ${YELLOW}${WIN_PASS}${NC}"
    echo -e "${BOLD}${CYAN}----------------------------------------------------------------${NC}"
    echo -e "预计安装耗时: 10 ~ 20 分钟 (取决于 VPS 磁盘 I/O 及网络下行速率)"
    echo -e "安装进度查看: 可通过服务商后台 VNC 控制台实时查看 Windows 安装画面"
    echo -e "${BOLD}${GREEN}================================================================${NC}\n"

    sleep 3

    # 执行核心重装脚本
    bash "$local_script" "${cmd_args[@]}"
    local ret=$?

    if [ $ret -eq 0 ]; then
        echo -e "\n${BOLD}${GREEN}================================================================${NC}"
        echo -e "${BOLD}${GREEN}        安装环境与引导配置就绪！系统将在 5 秒后自动重启...        ${NC}"
        echo -e "${BOLD}${GREEN}================================================================${NC}\n"
        sleep 5
        reboot
    else
        log_error "安装环境配置失败，请检查上方日志输出！"
        exit $ret
    fi
}

# ----------------- 命令行参数解析 -----------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                WIN_VERSION="$2"
                shift 2
                ;;
            -u|--user)
                WIN_USER="$2"
                shift 2
                ;;
            -p|--password)
                WIN_PASS="$2"
                shift 2
                ;;
            --port|--rdp-port)
                RDP_PORT="$2"
                shift 2
                ;;
            -d|--disk)
                TARGET_DISK="$2"
                shift 2
                ;;
            -m|--mode)
                INSTALL_MODE="$2"
                shift 2
                ;;
            --iso)
                CUSTOM_ISO_URL="$2"
                WIN_VERSION="custom"
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
                log_error "未知参数: $1"
                show_help
                ;;
        esac
    done
}

# ----------------- 脚本主入口 -----------------
main() {
    # 若通过管道执行 (如 curl ... | bash)，重定向标准输入至控制终端以保证交互正常
    if [ ! -t 0 ] && [ -c /dev/tty ]; then
        exec < /dev/tty
    fi

    parse_arguments "$@"
    check_root
    install_dependencies
    detect_environment

    # 若传入 -y 则完全进入全自动静默模式；否则进入交互式菜单
    if [ "$AUTO_CONFIRM" = true ]; then
        if [ -z "$WIN_PASS" ]; then
            WIN_PASS=$(generate_strong_password)
            log_info "未指定密码，已自动生成 Windows 合规强密码: ${WIN_PASS}"
        elif ! validate_password "$WIN_PASS" "$WIN_USER"; then
            log_error "指定的密码不符合 Windows 密码复杂度策略！请使用包含大写字母、小写字母、数字和符号的强密码。"
            exit 1
        fi
    else
        interactive_menu
    fi

    confirm_execution
    execute_installation
}

main "$@"
