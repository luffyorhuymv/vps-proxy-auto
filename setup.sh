#!/bin/bash

# ==========================================================
# Script: setup_proxy.sh
# Purpose: Auto setup 3proxy (HTTP/SOCKS5) on VPS (Ubuntu/Debian)
# Version: 1.0.2
# Features: Auto-fix common errors, simple authentication, systemd service
# ==========================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HTTP_PORT=8080
SOCKS_PORT=1080
PROXY_USER="huy"
PROXY_PASS="huy"

log_info() {
    echo -e "${YELLOW}$1${NC}"
}

log_ok() {
    echo -e "${GREEN}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

wait_for_port() {
    local port="$1"
    local retries=10

    while [ "$retries" -gt 0 ]; do
        if ss -ltn | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
            return 0
        fi
        sleep 1
        retries=$((retries - 1))
    done

    return 1
}

show_recent_logs() {
    journalctl -u 3proxy --no-pager | tail -n 20 || true
}

verify_proxy() {
    if ! wait_for_port "$HTTP_PORT"; then
        log_error "HTTP proxy did not start on port ${HTTP_PORT}."
        show_recent_logs
        exit 1
    fi

    if ! wait_for_port "$SOCKS_PORT"; then
        log_error "SOCKS5 proxy did not start on port ${SOCKS_PORT}."
        show_recent_logs
        exit 1
    fi

    if ! curl -fsS --max-time 20 -x "http://${PROXY_USER}:${PROXY_PASS}@127.0.0.1:${HTTP_PORT}" https://google.com >/dev/null; then
        log_error "HTTP proxy health check failed."
        show_recent_logs
        exit 1
    fi

    if ! curl -fsS --max-time 20 --proxy "socks5h://${PROXY_USER}:${PROXY_PASS}@127.0.0.1:${SOCKS_PORT}" https://google.com >/dev/null; then
        log_error "SOCKS5 proxy health check failed."
        show_recent_logs
        exit 1
    fi
}

log_ok "=== BAT DAU CAI DAT PROXY TU DONG ==="

if [[ $EUID -ne 0 ]]; then
    log_error "Loi: Script nay can chay voi quyen root (sudo)."
    exit 1
fi

log_info "Dang cap nhat he thong va cai dat dependencies..."
update_system() {
    apt-get update -y || {
        log_info "Thu lai apt update..."
        sleep 5
        apt-get update -y
    }

    apt-get install -y build-essential libssl-dev git ufw wget curl iproute2 psmisc || {
        log_info "Co loi xay ra, dang thu sua bang apt --fix-broken install..."
        apt-get install -f -y
        apt-get install -y build-essential libssl-dev git ufw wget curl iproute2 psmisc
    }
}
update_system

log_info "Dang tai va bien dich 3proxy..."
cd /tmp
rm -rf 3proxy 3proxy.tar.gz

log_info "Thu tai 3proxy tu nhieu nguon..."
if wget -q --show-progress https://github.com/3proxy/3proxy/archive/0.9.4.tar.gz -O 3proxy.tar.gz; then
    log_ok "Tai thanh cong ban 0.9.4 tu GitHub (wget)"
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
elif wget -q --show-progress https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -O 3proxy.tar.gz; then
    log_ok "Tai thanh cong ban 0.9.4 (tags - wget)"
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
elif git clone --depth 1 https://github.com/3proxy/3proxy.git 3proxy; then
    log_ok "Tai thanh cong tu GitHub repo (git clone)"
    cd 3proxy
else
    log_info "Thu tai ban master tarball..."
    wget -q --show-progress https://github.com/3proxy/3proxy/archive/refs/heads/master.tar.gz -O 3proxy.tar.gz
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
fi

ln -sf Makefile.Linux Makefile
make || {
    log_error "Loi khi bien dich 3proxy. Kiem tra log phia tren."
    exit 1
}

mkdir -p /etc/3proxy/bin
cp bin/3proxy /etc/3proxy/bin/
if [ -f scripts/add3proxyuser.sh ]; then
    cp scripts/add3proxyuser.sh /etc/3proxy/bin/
fi
chmod +x /etc/3proxy/bin/3proxy

log_info "Dang tao file cau hinh..."
mkdir -p /var/log/3proxy

cat <<EOF > /etc/3proxy/3proxy.cfg
maxconn 1024
nscache 65536
nserver 8.8.8.8
nserver 8.8.4.4
timeouts 1 5 30 60 180 1800 15 60

# Logs
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# Authentication
auth strong
users ${PROXY_USER}:CL:${PROXY_PASS}

# HTTP Proxy
allow ${PROXY_USER}
proxy -p${HTTP_PORT}

# SOCKS5 Proxy
allow ${PROXY_USER}
socks -p${SOCKS_PORT}

flush
EOF

log_info "Thiet lap systemd service..."
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/etc/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log_info "Dang cau hinh firewall..."
ufw allow ${HTTP_PORT}/tcp || true
ufw allow ${SOCKS_PORT}/tcp || true
ufw allow ssh || true
log_info "Goi y: Neu UFW chua bat, hay chay 'ufw enable' sau khi kiem tra ky."

systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy || {
    log_error "Loi: Khong khoi dong duoc 3proxy. Dang kiem tra log loi..."
    show_recent_logs
    log_info "Thu dong cac ung dung dang dung port ${HTTP_PORT}/${SOCKS_PORT}..."
    fuser -k ${HTTP_PORT}/tcp || true
    fuser -k ${SOCKS_PORT}/tcp || true
    systemctl restart 3proxy
}

verify_proxy

IP_ADDRESS=$(curl -fsS https://api.ipify.org || hostname -I | awk '{print $1}')

log_ok "========================================"
log_ok "CAI DAT HOAN TAT!"
log_info "Thong tin Proxy cua ban:"
echo -e "IP: ${IP_ADDRESS}"
echo -e "HTTP Port: ${HTTP_PORT}"
echo -e "SOCKS5 Port: ${SOCKS_PORT}"
echo -e "Username: ${PROXY_USER}"
echo -e "Password: ${PROXY_PASS}"
log_ok "========================================"
log_ok "Dinh dang IP:PORT:USER:PASS:"
echo -e "${YELLOW}HTTP Proxy: ${IP_ADDRESS}:${HTTP_PORT}:${PROXY_USER}:${PROXY_PASS}${NC}"
echo -e "${YELLOW}SOCKS5 Proxy: ${IP_ADDRESS}:${SOCKS_PORT}:${PROXY_USER}:${PROXY_PASS}${NC}"
log_ok "========================================"
echo -e "Dung lenh sau de kiem tra: curl -x http://${PROXY_USER}:${PROXY_PASS}@${IP_ADDRESS}:${HTTP_PORT} https://google.com"
