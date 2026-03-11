#!/bin/bash

# ==========================================================
# Script: setup_proxy.sh
# Purpose: Auto setup 3proxy (HTTP/SOCKS5) on VPS (Ubuntu/Debian)
# Version: 1.0.1 (Fixed 3proxy 404 & Git Auth)
# Features: Auto-fix common errors, simple authentication, systemd service
# ==========================================================

set -e

# Color for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== BẮT ĐẦU CÀI ĐẶT PROXY TỰ ĐỘNG ===${NC}"

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Lỗi: Script này cần chạy với quyền root (sudo).${NC}"
   exit 1
fi

# 2. Cơ chế tự sửa lỗi khi cập nhật hệ thống
echo -e "${YELLOW}Đang cập nhật hệ thống và cài đặt dependencies...${NC}"
update_system() {
    apt-get update -y || { echo -e "${YELLOW}Thử lại apt update...${NC}"; sleep 5; apt-get update -y; }
    apt-get install -y build-essential libssl-dev git ufw wget curl || {
        echo -e "${YELLOW}Có lỗi xảy ra, đang thử sửa bằng apt --fix-broken install...${NC}"
        apt-get install -f -y
        apt-get install -y build-essential libssl-dev git ufw wget curl
    }
}
update_system

# 3. Tải và biên dịch 3proxy (phiên bản mới nhất)
echo -e "${YELLOW}Đang tải và biên dịch 3proxy...${NC}"
cd /tmp
if [ -d "3proxy" ]; then rm -rf 3proxy; fi

# Tải bản release ổn định nhất
# Ưu tiên tải bản tar.gz vì wget không bao giờ hỏi mật khẩu GitHub đối với repo công khai
echo -e "${YELLOW}Thử tải 3proxy từ nhiều nguồn...${NC}"
if wget -q --show-progress https://github.com/3proxy/3proxy/archive/0.9.4.tar.gz -O 3proxy.tar.gz; then
    echo -e "${GREEN}Tải thành công bản 0.9.4 từ GitHub (wget)${NC}"
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
elif wget -q --show-progress https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -O 3proxy.tar.gz; then
    echo -e "${GREEN}Tải thành công bản 0.9.4 (tags - wget)${NC}"
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
elif git clone --depth 1 https://github.com/3proxy/3proxy.git 3proxy; then
    echo -e "${GREEN}Tải thành công từ GitHub repo (git clone)${NC}"
    cd 3proxy
else
    echo -e "${YELLOW}Thử tải bản master zip...${NC}"
    wget -q --show-progress https://github.com/3proxy/3proxy/archive/refs/heads/master.tar.gz -O 3proxy.tar.gz
    tar -xvzf 3proxy.tar.gz
    mv 3proxy-* 3proxy
    cd 3proxy
fi

ln -s Makefile.Linux Makefile
make || { echo -e "${RED}Lỗi khi biên dịch 3proxy. Kiểm tra log phía trên.${NC}"; exit 1; }

# Cài đặt binary
mkdir -p /etc/3proxy/bin
cp bin/3proxy /etc/3proxy/bin/
cp scripts/add3proxyuser.sh /etc/3proxy/bin/
chmod +x /etc/3proxy/bin/3proxy

# 4. Cấu hình proxy (Mặc định: HTTP 8080, SOCKS5 1080)
echo -e "${YELLOW}Đang tạo file cấu hình...${NC}"
mkdir -p /var/log/3proxy

# Thiết lập thông tin đăng nhập mặc định huy/huy
PROXY_USER="huy"
PROXY_PASS="huy"

cat <<EOF > /etc/3proxy/3proxy.cfg
daemon
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
proxy -p8080

# SOCKS5 Proxy
allow ${PROXY_USER}
socks -p1080

flush
EOF

# 5. Thiết lập systemd service
echo -e "${YELLOW}Thiết lập systemd service...${NC}"
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

# 6. Mở Firewall
echo -e "${YELLOW}Đang cấu hình Firewall...${NC}"
ufw allow 8080/tcp || true
ufw allow 1080/tcp || true
# Đảm bảo SSH không bị chặn
ufw allow ssh || true
# Không kích hoạt ufw ngay lập tức để tránh mất kết nối, chỉ gợi ý
echo -e "${YELLOW}Gợi ý: Nếu ufw chưa bật, hãy chạy 'ufw enable' sau khi kiểm tra kỹ.${NC}"

# 7. Khởi chạy
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy || {
    echo -e "${RED}Lỗi: Không khởi động được 3proxy. Đang kiểm tra log lỗi...${NC}"
    journalctl -u 3proxy --no-pager | tail -n 20
    # Thử fix lỗi port bị chiếm dụng
    echo -e "${YELLOW}Thử đóng các ứng dụng đang dùng port 8080/1080...${NC}"
    fuser -k 8080/tcp || true
    fuser -k 1080/tcp || true
    systemctl restart 3proxy
}

# 8. Hoàn tất
IP_ADDRESS=$(curl -s https://api.ipify.org)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CÀI ĐẶT HOÀN TẤT!${NC}"
echo -e "${YELLOW}Thông tin Proxy của bạn:${NC}"
echo -e "IP: ${IP_ADDRESS}"
echo -e "HTTP Port: 8080"
echo -e "SOCKS5 Port: 1080"
echo -e "Username: ${PROXY_USER}"
echo -e "Password: ${PROXY_PASS}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Định dạng IP:PORT:USER:PASS:${NC}"
echo -e "${YELLOW}HTTP Proxy: ${IP_ADDRESS}:8080:${PROXY_USER}:${PROXY_PASS}${NC}"
echo -e "${YELLOW}SOCKS5 Proxy: ${IP_ADDRESS}:1080:${PROXY_USER}:${PROXY_PASS}${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Dùng lệnh sau để kiểm tra: curl -x http://${PROXY_USER}:${PROXY_PASS}@${IP_ADDRESS}:8080 https://google.com"
