#!/bin/bash
# 从 GitHub Release 下载并安装 Caddy
# 仓库: https://github.com/liasica/xcaddy

set -e

REPO="liasica/xcaddy"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/caddy"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 检测系统架构
detect_arch() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case $arch in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l|armhf) arch="arm" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

# 获取最新版本
get_latest_version() {
    local api_url="https://api.github.com/repos/${REPO}/releases/latest"
    local version

    version=$(curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$version" ]; then
        log_error "无法获取最新版本"
        exit 1
    fi

    echo "$version"
}

# 下载 Caddy
download_caddy() {
    local version="$1"
    local platform="$2"
    local tmp_file="$3"
    local download_url="https://github.com/${REPO}/releases/download/${version}/caddy-${platform}"

    log_info "下载 Caddy ${version} (${platform})..."

    if ! curl -L -f -o "$tmp_file" "$download_url"; then
        log_error "下载失败: $download_url"
        exit 1
    fi
}

# 安装 Caddy 二进制
install_binary() {
    local tmp_file="$1"

    log_info "安装 Caddy 到 ${INSTALL_DIR}..."

    chmod +x "$tmp_file"
    mv "$tmp_file" "${INSTALL_DIR}/caddy"

    # 创建符号链接到 /usr/bin（兼容性）
    ln -sf "${INSTALL_DIR}/caddy" /usr/bin/caddy 2>/dev/null || true
}

# 创建 caddy 用户和组
create_user() {
    if ! id -u caddy &>/dev/null; then
        log_info "创建 caddy 用户和组..."
        groupadd --system caddy
        useradd --system --gid caddy --create-home \
            --home-dir /var/lib/caddy \
            --shell /usr/sbin/nologin \
            --comment "Caddy web server" caddy
    else
        log_info "caddy 用户已存在"
    fi
}

# 创建配置目录
create_config_dir() {
    log_info "创建配置目录..."
    mkdir -p "$CONFIG_DIR"
    chown -R caddy:caddy "$CONFIG_DIR"
}

# 生成 Caddyfile
generate_caddyfile() {
    log_info "生成 Caddyfile..."

    if [ -f "${CONFIG_DIR}/Caddyfile" ]; then
        log_warn "Caddyfile 已存在，跳过"
        return
    fi

    # 交互式输入配置
    echo ""
    log_info "请输入 Caddy 配置信息:"
    echo ""

    # 域名
    read -p "请输入域名 (如: example.com): " domain
    while [ -z "$domain" ]; do
        log_error "域名不能为空"
        read -p "请输入域名 (如: example.com): " domain
    done

    # 邮箱
    read -p "请输入邮箱 (用于 TLS 证书，如: admin@example.com): " email
    while [ -z "$email" ]; do
        log_error "邮箱不能为空"
        read -p "请输入邮箱 (用于 TLS 证书，如: admin@example.com): " email
    done

    # 用户名
    read -p "请输入代理认证用户名: " username
    while [ -z "$username" ]; do
        log_error "用户名不能为空"
        read -p "请输入代理认证用户名: " username
    done

    # 密码
    read -s -p "请输入代理认证密码: " password
    echo ""
    while [ -z "$password" ]; do
        log_error "密码不能为空"
        read -s -p "请输入代理认证密码: " password
        echo ""
    done

    # 伪装网站
    read -p "请输入伪装网站 URL (默认: https://cdn.jsdelivr.net): " proxy_site
    proxy_site=${proxy_site:-https://cdn.jsdelivr.net}

    cat << EOF > "${CONFIG_DIR}/Caddyfile"
# Caddy 配置文件
# 域名: ${domain}

:443, ${domain}
tls ${email}

route {
    # Naive 代理配置
    forward_proxy {
        basic_auth ${username} ${password}
        hide_ip
        hide_via
        probe_resistance
    }

    # 反向代理到网站（伪装）
    reverse_proxy ${proxy_site} {
        header_up Host {upstream_hostport}
        header_up X-Forwarded-Host {host}
    }
}
EOF

    chmod 600 "${CONFIG_DIR}/Caddyfile"
    log_info "Caddyfile 已生成: ${CONFIG_DIR}/Caddyfile"
}

# 生成 systemd 服务文件
generate_systemd_service() {
    log_info "生成 systemd 服务文件..."

    cat << 'EOF' > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/caddy.service
}

# 启动 Caddy 服务
start_service() {
    log_info "重新加载 systemd..."
    systemctl daemon-reload

    log_info "启用 Caddy 服务..."
    systemctl enable caddy

    log_info "启动 Caddy 服务..."
    systemctl start caddy

    sleep 2
    systemctl status caddy --no-pager || true
}

# 主函数
main() {
    log_info "=========================================="
    log_info "Caddy 安装脚本"
    log_info "仓库: https://github.com/${REPO}"
    log_info "=========================================="

    # 检查操作系统
    local os=$(uname -s)
    if [ "$os" != "Linux" ]; then
        log_error "此脚本仅支持 Linux 系统"
        log_error "当前系统: $os"
        exit 1
    fi

    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi

    # 检测平台
    platform=$(detect_arch)
    log_info "检测到平台: $platform"

    # 获取最新版本
    version=$(get_latest_version)
    log_info "最新版本: $version"

    # 下载
    local tmp_file="/tmp/caddy"
    download_caddy "$version" "$platform" "$tmp_file"

    # 安装
    install_binary "$tmp_file"

    # 创建用户
    create_user

    # 创建配置目录
    create_config_dir

    # 生成配置文件
    generate_caddyfile

    # 生成服务文件
    generate_systemd_service

    # 启动服务
    start_service

    echo ""
    log_info "=========================================="
    log_info "安装完成！"
    log_info "=========================================="
    echo ""
    log_info "配置文件: ${CONFIG_DIR}/Caddyfile"
    echo ""
    log_info "常用命令:"
    echo "  查看状态: systemctl status caddy"
    echo "  重启服务: systemctl restart caddy"
    echo "  查看日志: journalctl -u caddy -f"
    echo "  重新加载: systemctl reload caddy"
}

main "$@"
