# VPS Auto Proxy Setup (3proxy)

Script tự động cài đặt Proxy (HTTP & SOCKS5) trên VPS Linux (Ubuntu/Debian) chỉ với 1 dòng lệnh.

## Tính năng
- Tự động cài đặt dependencies.
- Tự động tải và biên dịch 3proxy mới nhất.
- Tự động cấu hình User/Pass bảo mật.
- Tự động thiết lập Systemd (tự khởi động cùng VPS).
- Cơ chế tự sửa lỗi khi cài đặt (fix apt, fix port).
- Hỗ trợ cả HTTP Proxy (8080) và SOCKS5 Proxy (1080).

## Cách sử dụng

### Bước 1: Upload lên GitHub
1. Tạo một repository mới trên GitHub của bạn.
2. Upload file `setup.sh` lên repo đó.

### Bước 2: Chạy trên VPS
Mở terminal của VPS và chạy lệnh sau (**Đây là lệnh ĐÃ THAY THẾ tài khoản của bạn `luffyorhuymv`, bạn có thể copy và chạy ngay**):

```bash
# Lệnh wget (Khuyên dùng):
wget https://raw.githubusercontent.com/luffyorhuymv/vps-proxy-auto/main/setup.sh && chmod +x setup.sh && sudo ./setup.sh

# Hoặc lệnh curl:
curl -L https://raw.githubusercontent.com/luffyorhuymv/vps-proxy-auto/main/setup.sh | sudo bash
```

> **Lưu ý:** Lỗi `404 Not Found` thường xảy ra nếu bạn copy dòng lệnh mẫu chứa `YOUR_GITHUB_USERNAME` mà không thay thế bằng tên thật. Hãy dùng lệnh trên để tránh lỗi.

### Cách chạy khác (Dùng Git Clone)
Nếu lệnh trên vẫn lỗi tải, hãy dùng cách này (tải cả thư mục về VPS):
```bash
git clone https://github.com/luffyorhuymv/vps-proxy-auto.git && cd vps-proxy-auto && chmod +x setup.sh && sudo ./setup.sh
```

## Lưu ý
- Script này yêu cầu quyền **root**.
- Sau khi cài xong, script sẽ hiển thị **IP, Port, Username và Password** theo định dạng `ip:port:user:pass`.
- Username/Password mặc định: `huy/huy`.
- Cửa sổ Firewall (UFW) sẽ được cấu hình tự động cho port 8080 và 1080.

## Kiểm tra Proxy
Sau khi cài đặt, bạn có thể kiểm tra bằng lệnh:
```bash
curl -x http://user:pass@ip:8080 https://google.com
```
hoặc
```bash
curl --socks5 user:pass@ip:1080 https://google.com
```
