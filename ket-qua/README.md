# Kết quả kiểm chứng — 10/11/2026

| | |
|---|---|
| Lần chạy CI | [lab #42747059740](https://github.com/technicalors/factory-sql-lab/actions/runs/42747059740) (commit `eab4500`, GitHub Actions `ubuntu-latest`) |
| Máy nhà máy (giả lập) | Windows 10 (VM KVM) + **SQL Server 2008 R2 Express** cài từ bộ cài chính thức của Microsoft |
| Phía ORS | Debian 13, WireGuard, FreeTDS (TDS 7.3) + PHP 8.4 PDO `dblib`, Microsoft ODBC Driver 18 |
| Kết luận | **ĐẠT** cả trước và sau khi vá TLS 1.2 |

| Hạng mục | SP3 chưa TLS 1.2 (10.50.6000) | Sau KB4057113 (10.50.6560) |
|---|---|---|
| WireGuard: Windows sau NAT tự kết nối ra, TCP 1433 qua tunnel | ĐẠT | ĐẠT |
| CRUD + transaction ROLLBACK + tiếng Việt (FreeTDS, 4 cấu hình mã hoá) | 12/12 × 4 | 12/12 × 4 |
| Thao tác ngoài quyền bị chặn (đọc bảng khác, CREATE/DROP/ALTER/TRUNCATE, tạo login) | ĐẠT | ĐẠT |
| Máy ngoài Internet truy cập thẳng 1433 | Bị chặn | Bị chặn |
| Máy nhà máy gọi ngược vào Linux qua tunnel | Bị chặn | Bị chặn |
| ODBC Driver 18 (tham khảo) | Chỉ kết nối được khi cho phép TLS 1.0 | Cần `TrustServerCertificate=yes` hoặc `Encrypt=optional` |

Chạy lại: tab [Actions](https://github.com/technicalors/factory-sql-lab/actions/workflows/lab.yml) → *Run workflow*, hoặc `./lab.sh all` trên máy Linux có KVM (xem [README](../README.md)).

## Lần 1 — SP3, chưa có TLS 1.2

```
# Kết quả: 1-sp3-chua-tls12
== 1. Mạng / WireGuard
  [PASS] Handshake WireGuard 6s trước (Windows sau NAT tự kết nối ra)
  [INFO] Ping 10.80.0.2 không trả lời (Windows mặc định chặn ICMP — bình thường)
Connection to 10.80.0.2 1433 port [tcp/*] succeeded!
  [PASS] TCP 10.80.0.2:1433 mở qua tunnel
== 2. CRUD + quyền tối thiểu (PHP PDO dblib / FreeTDS)
 -- freetds section [factory]
  [PASS] Kết nối (factory) — 10.50.6000.34 SP3 Express Edition (64-bit)
  [PASS] INSERT — Id=3
  [PASS] SELECT + Unicode tiếng Việt — Thép tấm Đà Nẵng — ưu tiên
  [PASS] UPDATE — rows=1
  [PASS] Transaction ROLLBACK giữ nguyên dữ liệu — Qty=25
  [PASS] DELETE — rows=1
  [PASS] Bị chặn: Đọc bảng không được cấp (dbo.Recipe) — SQLSTATE[HY000]: General error: 20018 The SELECT permission was denied on the object 'Recipe', database 'Fact…
  [PASS] Bị chặn: Tạo bảng — SQLSTATE[HY000]: General error: 20018 CREATE TABLE permission denied in database 'FactoryDB'. [20018] (severi…
  [PASS] Bị chặn: Xoá bảng (DROP) — SQLSTATE[HY000]: General error: 20018 Cannot drop the table 'ProductionOrder', because it does not exist or y…
  [PASS] Bị chặn: Sửa cấu trúc bảng (ALTER) — SQLSTATE[HY000]: General error: 20018 Cannot find the object "ProductionOrder" because it does not exist or y…
  [PASS] Bị chặn: TRUNCATE — SQLSTATE[HY000]: General error: 20018 Cannot find the object "ProductionOrder" because it does not exist or y…
  [PASS] Bị chặn: Tạo login mới — SQLSTATE[HY000]: General error: 20018 User does not have permission to perform this action. [20018] (severity…
  => 12 PASS, 0 FAIL
 -- freetds section [factory_noenc]
  [ OK ] Kết nối (factory_noenc) — 10.50.6000.34 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
 -- freetds section [factory_require]
  [ OK ] Kết nối (factory_require) — 10.50.6000.34 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
 -- freetds section [factory_tls10]
  [ OK ] Kết nối (factory_tls10) — 10.50.6000.34 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
  [PASS] CRUD + quyền tối thiểu đạt với FreeTDS: factory factory_noenc factory_require factory_tls10
== 3. Microsoft ODBC Driver 18 (sqlcmd) — [ OK ]/[ KO ] là thông tin tương thích, không tính đạt/không đạt
  [ KO ] mặc định (Encrypt=yes, kiểm tra chứng chỉ) → Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider: [error:0A000102:SSL routines::unsupported protocol][error:0A0000C7:SSL routines::peer did not retur
  [ KO ] Encrypt=yes + TrustServerCertificate (-C) → Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider: [error:0A000102:SSL routines::unsupported protocol]. Sqlcmd: Error: Microsoft ODBC Driver 18 for SQ
  [ KO ] Encrypt=optional (-N o) → Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider: [error:0A000102:SSL routines::unsupported protocol]. Sqlcmd: Error: Microsoft ODBC Driver 18 for SQ
  [ OK ] Encrypt=optional + OPENSSL_CONF cho TLS 1.0 → 10.50.6000.34 SP3 
  [ OK ] Encrypt=yes -C + OPENSSL_CONF cho TLS 1.0 → 10.50.6000.34 SP3 
== 5. Truy cập trực tiếp từ Internet (không qua VPN)
Connection to 172.30.0.20 22 port [tcp/*] succeeded!
  [INFO] attacker tới được 172.30.0.20:22 (đường mạng thông — đối chứng)
  [PASS] attacker bị Windows Firewall chặn ở 1433
== 6. Chiều ngược: máy nhà máy gọi vào Linux qua tunnel
  [PASS] Windows KHÔNG mở được dịch vụ trên Linux qua tunnel
  [INFO] gói bị firewall Linux chặn: 5
== 7. Phía Windows
  [INFO] MSSQL$SQLEXPRESS: Running / Automatic
  [INFO] WireGuardTunnel$factory: Running / Automatic
  [INFO] profile factory: Public
  [INFO] profile Ethernet: Private

KẾT LUẬN [1-sp3-chua-tls12]: ĐẠT
```

## Lần 2 — sau bản vá TLS 1.2 (KB4057113)

```
# Kết quả: 2-sp3-co-tls12
== 1. Mạng / WireGuard
  [PASS] Handshake WireGuard 118s trước (Windows sau NAT tự kết nối ra)
  [INFO] Ping 10.80.0.2 không trả lời (Windows mặc định chặn ICMP — bình thường)
Connection to 10.80.0.2 1433 port [tcp/*] succeeded!
  [PASS] TCP 10.80.0.2:1433 mở qua tunnel
== 2. CRUD + quyền tối thiểu (PHP PDO dblib / FreeTDS)
 -- freetds section [factory]
  [PASS] Kết nối (factory) — 10.50.6560.0 SP3 Express Edition (64-bit)
  [PASS] INSERT — Id=7
  [PASS] SELECT + Unicode tiếng Việt — Thép tấm Đà Nẵng — ưu tiên
  [PASS] UPDATE — rows=1
  [PASS] Transaction ROLLBACK giữ nguyên dữ liệu — Qty=25
  [PASS] DELETE — rows=1
  [PASS] Bị chặn: Đọc bảng không được cấp (dbo.Recipe) — SQLSTATE[HY000]: General error: 20018 The SELECT permission was denied on the object 'Recipe', database 'Fact…
  [PASS] Bị chặn: Tạo bảng — SQLSTATE[HY000]: General error: 20018 CREATE TABLE permission denied in database 'FactoryDB'. [20018] (severi…
  [PASS] Bị chặn: Xoá bảng (DROP) — SQLSTATE[HY000]: General error: 20018 Cannot drop the table 'ProductionOrder', because it does not exist or y…
  [PASS] Bị chặn: Sửa cấu trúc bảng (ALTER) — SQLSTATE[HY000]: General error: 20018 Cannot find the object "ProductionOrder" because it does not exist or y…
  [PASS] Bị chặn: TRUNCATE — SQLSTATE[HY000]: General error: 20018 Cannot find the object "ProductionOrder" because it does not exist or y…
  [PASS] Bị chặn: Tạo login mới — SQLSTATE[HY000]: General error: 20018 User does not have permission to perform this action. [20018] (severity…
  => 12 PASS, 0 FAIL
 -- freetds section [factory_noenc]
  [ OK ] Kết nối (factory_noenc) — 10.50.6560.0 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
 -- freetds section [factory_require]
  [ OK ] Kết nối (factory_require) — 10.50.6560.0 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
 -- freetds section [factory_tls10]
  [ OK ] Kết nối (factory_tls10) — 10.50.6560.0 SP3 Express Edition (64-bit)
  => 12 PASS, 0 FAIL
  [PASS] CRUD + quyền tối thiểu đạt với FreeTDS: factory factory_noenc factory_require factory_tls10
== 3. Microsoft ODBC Driver 18 (sqlcmd) — [ OK ]/[ KO ] là thông tin tương thích, không tính đạt/không đạt
  [ KO ] mặc định (Encrypt=yes, kiểm tra chứng chỉ) → Sqlcmd: Error: Microsoft ODBC Driver 18 for SQL Server : SSL Provider: [error:0A000086:SSL routines::certificate verify failed:EE certificate key too weak]. Sqlcmd: Error
  [ OK ] Encrypt=yes + TrustServerCertificate (-C) → 10.50.6560.0 SP3 
  [ OK ] Encrypt=optional (-N o) → 10.50.6560.0 SP3 
  [ OK ] Encrypt=optional + OPENSSL_CONF cho TLS 1.0 → 10.50.6560.0 SP3 
  [ OK ] Encrypt=yes -C + OPENSSL_CONF cho TLS 1.0 → 10.50.6560.0 SP3 
== 5. Truy cập trực tiếp từ Internet (không qua VPN)
Connection to 172.30.0.20 22 port [tcp/*] succeeded!
  [INFO] attacker tới được 172.30.0.20:22 (đường mạng thông — đối chứng)
  [PASS] attacker bị Windows Firewall chặn ở 1433
== 6. Chiều ngược: máy nhà máy gọi vào Linux qua tunnel
  [PASS] Windows KHÔNG mở được dịch vụ trên Linux qua tunnel
  [INFO] gói bị firewall Linux chặn: 10
== 7. Phía Windows
  [INFO] MSSQL$SQLEXPRESS: Running / Automatic
  [INFO] WireGuardTunnel$factory: Running / Automatic
  [INFO] profile factory: Public
  [INFO] profile Ethernet: Private

KẾT LUẬN [2-sp3-co-tls12]: ĐẠT
```
