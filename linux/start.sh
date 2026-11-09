#!/bin/sh
# Khởi động phía Linux Server: WireGuard (10.80.0.1) + firewall + dịch vụ giả lập để test chiều ngược.
set -e

ip link add wg0 type wireguard
wg setconf wg0 /lab/wg/linux-wg0.conf
ip address add 10.80.0.1/24 dev wg0
ip link set wg0 up

# Firewall: qua đường hầm chỉ nhận gói trả về của kết nối do Linux khởi tạo.
nft -f - <<'EOF'
table inet lab {
  chain input {
    type filter hook input priority 0; policy accept;
    iifname "wg0" ct state established,related accept
    iifname "wg0" counter drop
  }
}
EOF

# Dịch vụ giả lập trên Linux (đại diện app/DB nội bộ) để kiểm tra nhà máy KHÔNG gọi ngược vào được.
mkdir -p /srv/www && echo "linux-internal-service" > /srv/www/index.html
php -S 0.0.0.0:8080 -t /srv/www >/dev/null 2>&1 &

echo "linux-server ready"; wg show wg0
exec sleep infinity
