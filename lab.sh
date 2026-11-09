#!/usr/bin/env bash
# Điều phối lab. Chạy local (Podman) hoặc CI (Docker):
#   ./lab.sh all                 # toàn bộ: chuẩn bị → dựng → cài → test SP3 → vá TLS 1.2 → test lại
#   ./lab.sh <bước> ...          # secrets | download | up | wait | provision | test <tên> | patch-tls12 | win '<lệnh PowerShell>' | down
# Biến môi trường: CTR=podman|docker, COMPOSE="podman-compose"|"docker compose"
set -euo pipefail
cd "$(dirname "$0")"
CTR=${CTR:-podman}
COMPOSE=${COMPOSE:-podman-compose}
RESULTS=results
mkdir -p "$RESULTS"

log() { printf '\n\033[1;36m### %s\033[0m\n' "$*"; }

secrets() {
  [ -s keys/sql-password ] && [ -s wg/linux-wg0.conf ] && { echo "secrets: đã có"; return; }
  log "Sinh khoá WireGuard, SSH, mật khẩu SQL (không commit)"
  mkdir -p keys wg
  $COMPOSE build linux-server
  $CTR run --rm -v "$PWD/wg:/out" localhost/factory-lab-linux:latest sh -c '
    umask 077
    L=$(wg genkey); F=$(wg genkey); LP=$(echo $L | wg pubkey); FP=$(echo $F | wg pubkey)
    printf "[Interface]\nPrivateKey = %s\nListenPort = 51820\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 10.80.0.2/32\n" "$L" "$FP" > /out/linux-wg0.conf
    printf "[Interface]\r\nPrivateKey = %s\r\nAddress = 10.80.0.2/32\r\n\r\n[Peer]\r\nPublicKey = %s\r\nEndpoint = 172.30.0.10:51820\r\nAllowedIPs = 10.80.0.1/32\r\nPersistentKeepalive = 25\r\n" "$F" "$LP" > /out/factory.conf
    chmod 644 /out/*'
  cp wg/factory.conf oem/factory.conf
  [ -s keys/lab_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C factory-lab -f keys/lab_ed25519
  cp keys/lab_ed25519.pub oem/administrators_authorized_keys
  python3 -c "import secrets,string;a=string.ascii_letters+string.digits;print('Ors#'+''.join(secrets.choice(a) for _ in range(20)))" > keys/sql-password
}

download() { log "Tải bộ cài chính thức"; sh scripts/download-installers.sh; }

up() { log "Dựng lab"; $COMPOSE up -d; }

down() { $COMPOSE down; }

lin() { $CTR exec -i lab-linux "$@"; }

win() {
  lin ssh -q -i /lab/keys/lab_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=15 -o ServerAliveInterval=30 factory@172.30.0.20 \
    "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"$*\""
}

wait_windows() {
  log "Chờ Windows cài xong (SSH lên)"
  local max=${WAIT_MINUTES:-150} i=0
  while (( i < max * 2 )); do
    [ "$($CTR inspect -f '{{.State.Status}}' lab-windows)" = running ] || { $CTR logs --tail 30 lab-windows; return 1; }
    if lin nc -z -w3 172.30.0.20 22 2>/dev/null && win 'exit 0' 2>/dev/null; then echo "SSH sẵn sàng sau ~$((i / 2)) phút"; return 0; fi
    (( i % 10 == 0 )) && { echo "[$((i / 2)) phút] $($CTR logs --tail 1 lab-windows 2>&1 | tr '\r' '\n' | grep -v '^\s*$' | tail -1)"; }
    sleep 30; i=$((i + 1))
  done
  echo "Hết thời gian chờ"; $CTR logs --tail 30 lab-windows; return 1
}

provision() {
  local pw; pw=$(cat keys/sql-password)
  log "Chờ OEM install.bat (OpenSSH + .NET 3.5) xong"
  for _ in $(seq 1 60); do win "if (Select-String -Quiet -Path C:\\OEM\\install.log -Pattern done) { exit 0 } else { exit 1 }" && break; sleep 20; done
  log "Cài SQL Server 2008 R2 SP2 Express (cấu hình mặc định như nhà máy)"
  win "& C:\\OEM\\scripts\\10-install-sql2008r2-express.ps1"
  log "Cài SP3 (chưa có TLS 1.2)"
  win "& C:\\OEM\\scripts\\20-install-patch.ps1 -Patch sp3"
  log "Áp dụng các bước trong đề xuất (TCP 1433, Mixed Mode, audit, firewall, tài khoản CRUD)"
  win "& C:\\OEM\\scripts\\30-apply-proposal.ps1 -SqlPassword '$pw'"
  log "Cài WireGuard for Windows + tunnel service"
  win "& C:\\OEM\\scripts\\40-install-wireguard.ps1"
  for _ in $(seq 1 12); do lin sh -c '[ "$(wg show wg0 latest-handshakes | cut -f2)" -gt 0 ]' && break; sleep 5; done
}

patch_tls12() {
  log "Cài bản vá TLS 1.2 (KB4057113)"
  win "& C:\\OEM\\scripts\\20-install-patch.ps1 -Patch tls12"
}

test_phase() {
  local name=$1 out="$RESULTS/$1.txt" rc=0
  log "TEST: $name"
  {
    echo "# Kết quả: $name"
    lin sh /lab/tests/run-tests.sh || rc=1

    echo "== 5. Truy cập trực tiếp từ Internet (không qua VPN)"
    if $CTR exec lab-attacker nc -z -w5 172.30.0.20 22; then
      echo "  [INFO] attacker tới được 172.30.0.20:22 (đường mạng thông — đối chứng)"
    fi
    if $CTR exec lab-attacker nc -z -w5 172.30.0.20 1433; then
      echo "  [FAIL] attacker kết nối được SQL 1433 trực tiếp"; rc=1
    else
      echo "  [PASS] attacker bị Windows Firewall chặn ở 1433"
    fi

    echo "== 6. Chiều ngược: máy nhà máy gọi vào Linux qua tunnel"
    if win "if (Test-NetConnection 10.80.0.1 -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue) { exit 0 } else { exit 1 }"; then
      echo "  [FAIL] Windows mở được 10.80.0.1:8080 trên Linux"; rc=1
    else
      echo "  [PASS] Windows KHÔNG mở được dịch vụ trên Linux qua tunnel"
    fi
    echo "  [INFO] gói bị firewall Linux chặn: $(lin nft list chain inet lab input | grep -o 'packets [0-9]*' | awk '{print $2}' | tail -1)"

    echo "== 7. Phía Windows"
    win "Get-Service 'WireGuardTunnel`$factory','MSSQL`$SQLEXPRESS' | ForEach-Object { '  [INFO] ' + \$_.Name + ': ' + \$_.Status + ' / ' + \$_.StartType }; Get-NetConnectionProfile | ForEach-Object { '  [INFO] profile ' + \$_.InterfaceAlias + ': ' + \$_.NetworkCategory }"
    echo
    [ $rc -eq 0 ] && echo "KẾT LUẬN [$name]: ĐẠT" || echo "KẾT LUẬN [$name]: KHÔNG ĐẠT"
  } 2>&1 | tee "$out"
  grep -q "ĐẠT$" "$out" && ! grep -q "KHÔNG ĐẠT" "$out"
}

summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  for f in "$RESULTS"/*.txt; do
    { echo '```'; cat "$f"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
  done
}

all() {
  secrets; download; up; wait_windows; provision
  local rc=0
  test_phase 1-sp3-chua-tls12 || rc=1
  patch_tls12
  test_phase 2-sp3-co-tls12 || rc=1
  summary
  return $rc
}

cmd=${1:-all}; shift || true
case $cmd in
  all) all ;;
  secrets) secrets ;;
  download) download ;;
  up) up ;;
  down) down ;;
  wait) wait_windows ;;
  provision) provision ;;
  patch-tls12) patch_tls12 ;;
  test) test_phase "${1:-adhoc}" ;;
  summary) summary ;;
  win) win "$@" ;;
  *) echo "lệnh không hợp lệ: $cmd"; exit 2 ;;
esac
