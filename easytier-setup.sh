#!/usr/bin/env bash
# EasyTier systemd installer for the system that comes up after DD.
# Matches the 家庭云电脑 tutorial: EasyTier v2.6.4, tcp peer, optional static IP.
set -o pipefail

NAME=""
SECRET=""
PEER=""
IP_ADDR=""
VER="2.6.4"

show_help() {
    cat << 'EOF'
用法:
  bash easytier-setup.sh --name <网络名> --secret <网络密码> --peer <tcp://IP:11010> [--ip <虚拟IP>]

在 DD 完成后的 Debian / Ubuntu 里执行。会安装 easytier-core 并写成开机服务。
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="${2:-}"; shift 2 ;;
        --secret) SECRET="${2:-}"; shift 2 ;;
        --peer) PEER="${2:-}"; shift 2 ;;
        --ip) IP_ADDR="${2:-}"; shift 2 ;;
        --version) VER="${2:-}"; shift 2 ;;
        -h|--help) show_help ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$NAME" || -z "$SECRET" || -z "$PEER" ]]; then
    echo "必须提供 --name --secret --peer" >&2
    exit 1
fi
if [[ "$PEER" != *"://"* ]]; then
    PEER="tcp://${PEER}"
fi

case "$(uname -m)" in
    x86_64|amd64) ARCH_TAG="x86_64" ;;
    aarch64|arm64) ARCH_TAG="aarch64" ;;
    *) echo "不支持的架构: $(uname -m)" >&2; exit 1 ;;
esac

if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y unzip wget ca-certificates
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache unzip wget ca-certificates
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip wget ca-certificates
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

ZIP_NAME="easytier-linux-${ARCH_TAG}-v${VER}.zip"
SRC_URL="https://github.com/EasyTier/EasyTier/releases/download/v${VER}/${ZIP_NAME}"
MIRROR_URL="https://ghproxy.cc/${SRC_URL}"

echo "正在下载 EasyTier v${VER} ..."
if ! wget -q -O "$ZIP_NAME" "$SRC_URL"; then
    echo "官方源失败，改用加速镜像..."
    wget -q -O "$ZIP_NAME" "$MIRROR_URL" || {
        echo "下载 EasyTier 失败: $SRC_URL" >&2
        exit 1
    }
fi
unzip -q "$ZIP_NAME"
BIN_PATH="$(find . -type f -name easytier-core | head -n 1)"
if [[ -z "$BIN_PATH" ]]; then
    echo "压缩包里没有 easytier-core" >&2
    exit 1
fi
install -m 755 "$BIN_PATH" /usr/local/bin/easytier-core

IP_ARG=""
if [[ -n "$IP_ADDR" ]]; then
    IP_ARG="-i ${IP_ADDR} "
fi

cat > /etc/systemd/system/easytier.service << EOF
[Unit]
Description=EasyTier Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/easytier-core ${IP_ARG}--network-name ${NAME} --network-secret ${SECRET} -e ${PEER}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable easytier.service
systemctl restart easytier.service
systemctl --no-pager --full status easytier.service
echo "EasyTier 已安装。网络名: ${NAME}  节点: ${PEER}"
