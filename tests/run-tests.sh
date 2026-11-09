#!/bin/sh
# Chạy trong container lab-linux (gọi qua ./lab.sh test <tên>)
PW=$(cat /lab/keys/sql-password)
RC=0
ok()   { echo "  [PASS] $*"; }
bad()  { echo "  [FAIL] $*"; RC=1; }
info() { echo "  [INFO] $*"; }

echo "== 1. Mạng / WireGuard"
HS=$(wg show wg0 latest-handshakes | awk '{print $2}')
NOW=$(date +%s)
[ -n "$HS" ] && [ "$HS" -gt 0 ] && [ $((NOW - HS)) -lt 180 ] && ok "Handshake WireGuard $((NOW - HS))s trước (Windows sau NAT tự kết nối ra)" || bad "Chưa có handshake WireGuard"
ping -c2 -W2 10.80.0.2 >/dev/null 2>&1 && ok "Ping 10.80.0.2 qua tunnel" || info "Ping 10.80.0.2 không trả lời (Windows mặc định chặn ICMP — bình thường)"
nc -z -w5 10.80.0.2 1433 && ok "TCP 10.80.0.2:1433 mở qua tunnel" || bad "TCP 10.80.0.2:1433 không vào được"

echo "== 2. CRUD + quyền tối thiểu (PHP PDO dblib / FreeTDS)"
ANY_OK=""
for s in factory factory_noenc factory_require factory_tls10; do
  echo " -- freetds section [$s]"
  if php /lab/tests/crud.php "$s" "$PW" > /tmp/crud-$s.txt 2>&1; then ANY_OK="$ANY_OK $s"; fi
  if [ -z "$SHOWN" ] && grep -q "=> " /tmp/crud-$s.txt && ! grep -q "Kết nối.*FAIL\|\[FAIL\] Kết nối" /tmp/crud-$s.txt; then cat /tmp/crud-$s.txt; SHOWN=1
  else grep -E "Kết nối|=>" /tmp/crud-$s.txt | sed 's/\[PASS\]/[ OK ]/; s/\[FAIL\]/[ KO ]/'; fi
done
[ -n "$ANY_OK" ] && ok "CRUD + quyền tối thiểu đạt với FreeTDS:$ANY_OK" || bad "Không cấu hình FreeTDS nào chạy được CRUD"

echo "== 3. Microsoft ODBC Driver 18 (sqlcmd) — [ OK ]/[ KO ] là thông tin tương thích, không tính đạt/không đạt"
q="SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + ' ' + CAST(SERVERPROPERTY('ProductLevel') AS varchar(10))"
try() {
  label=$1; shift
  out=$(timeout 25 "$@" -S tcp:10.80.0.2,1433 -d FactoryDB -U ors_integration -P "$PW" -l 10 -h -1 -Q "$q" 2>&1 | tr -s ' \n' ' ' | cut -c1-170)
  case "$out" in *10.50.*) echo "  [ OK ] $label → $out" ;; *) echo "  [ KO ] $label → $out" ;; esac
}
try "mặc định (Encrypt=yes, kiểm tra chứng chỉ)"           sqlcmd
try "Encrypt=yes + TrustServerCertificate (-C)"            sqlcmd -C
try "Encrypt=optional (-N o)"                              sqlcmd -N o
try "Encrypt=optional + OPENSSL_CONF cho TLS 1.0" env OPENSSL_CONF=/etc/ssl/openssl-legacy.cnf sqlcmd -N o -C
try "Encrypt=yes -C + OPENSSL_CONF cho TLS 1.0"   env OPENSSL_CONF=/etc/ssl/openssl-legacy.cnf sqlcmd -C

exit $RC
