# factory-sql-lab

Lab kiểm chứng phương án **Linux Server kết nối trực tiếp SQL Server 2008 R2 Express (máy Windows nhà máy) qua WireGuard**, thực hiện đủ `SELECT / INSERT / UPDATE / DELETE`, không qua API trung gian.

Lab chạy **SQL Server 2008 R2 Express thật** (bộ cài chính thức của Microsoft) trong máy ảo Windows 10 (KVM, qua [dockur/windows](https://github.com/dockur/windows)), không giả lập bằng bản SQL mới hơn.

## Mô hình

```
 ┌──────────────── mạng "internet" 172.30.0.0/24 ────────────────┐
 │                                                                │
 │  lab-linux 172.30.0.10           lab-windows 172.30.0.20 (NAT) │
 │  WireGuard 10.80.0.1  ◄──────────  Windows 10 VM               │
 │  UDP 51820            ① Windows    WireGuard 10.80.0.2         │
 │  nftables: chỉ nhận     chủ động   SQL 2008 R2 Express :1433   │
 │  gói trả về từ wg0      kết nối ra Firewall: 1433 chỉ từ       │
 │  FreeTDS / PHP dblib                10.80.0.1                  │
 │  ODBC Driver 18       ② SQL qua tunnel ──────────►             │
 │                                                                │
 │  lab-attacker 172.30.0.66  (máy bất kỳ trên Internet)          │
 └────────────────────────────────────────────────────────────────┘
```

## Kịch bản

| Bước | Nội dung |
|---|---|
| 1 | Cài SQL 2008 R2 SP2 Express với cấu hình mặc định (Windows Auth, TCP tắt) — như máy nhà máy chưa chỉnh |
| 2 | Cài SP3 → build 10.50.6000, **chưa** hỗ trợ TLS 1.2 |
| 3 | Áp dụng đúng các bước của đề xuất: TCP/IP + cổng cố định 1433, Mixed Mode, audit đăng nhập, Windows Firewall chỉ cho `10.80.0.1`, tài khoản `ors_integration` có quyền CRUD trên bảng được chỉ định |
| 4 | Cài WireGuard for Windows, tunnel chạy dạng service |
| 5 | **Test lần 1** |
| 6 | Cài KB4057113 → build 10.50.6560, **có** TLS 1.2 |
| 7 | **Test lần 2** |

Các nhóm test:

1. WireGuard handshake khi Windows nằm sau NAT, cổng 1433 qua tunnel.
2. CRUD + transaction/rollback + Unicode tiếng Việt qua PHP PDO `dblib` (FreeTDS, TDS 7.3) với 4 cấu hình mã hoá; các thao tác ngoài quyền (đọc bảng khác, CREATE/DROP/ALTER/TRUNCATE, tạo login) phải bị chặn.
3. Ma trận tương thích Microsoft ODBC Driver 18 (`sqlcmd`) theo chế độ Encrypt / TrustServerCertificate / OpenSSL cho phép TLS 1.0 — chỉ để tham khảo.
4. Máy ngoài Internet truy cập thẳng 1433 → phải bị chặn.
5. Máy nhà máy gọi ngược vào dịch vụ trên Linux qua tunnel → phải bị chặn.

Kết quả ghi vào `results/*.txt` (CI: tab Summary và artifact `results`).

## Kết quả kiểm chứng

Lần chạy ngày 10/11/2026 **ĐẠT** cả trước và sau khi vá TLS 1.2 — chi tiết từng test: [`ket-qua/`](ket-qua/README.md).

## Chạy

Yêu cầu: Linux có KVM, module `wireguard`, Podman + podman-compose (hoặc Docker), ~60 GB trống, ~8 GB RAM rảnh.

```sh
sudo modprobe wireguard
./lab.sh all                                     # Podman
CTR=docker COMPOSE="docker compose" ./lab.sh all # Docker
```

Từng bước: `./lab.sh secrets | download | up | wait | provision | test <tên> | patch-tls12 | down`
Chạy lệnh trên Windows: `./lab.sh win 'Get-Service MSSQL*'` · Xem màn hình: http://127.0.0.1:8006

Lần đầu Windows tự tải và cài mất khoảng 20–60 phút.

## CI

Workflow `lab` chạy trên `ubuntu-latest` (có KVM), các bước: `base` → `snapshot` (chỉ khi chưa có cache) → `provision` → `tests`.

- Lần đầu: ổ Windows đã cài xong (OpenSSH + .NET 3.5, **chưa có SQL**) được nén zstd và lưu vào Actions cache (`win10-base-v1-*`).
- Các lần sau: khôi phục ổ đĩa và boot thẳng, bỏ qua bước tải + cài Windows. SQL 2008 R2, các bước của đề xuất và toàn bộ test vẫn chạy lại từ đầu.
- Script, bộ cài và cấu hình WireGuard luôn được đồng bộ vào `C:\OEM` qua SSH mỗi lần chạy, nên sửa script không cần tạo lại cache.
- Sửa `oem/install.bat` sẽ tự tạo cache mới; muốn ép tạo lại thì đổi `v1` trong key.

## Ghi chú

- Khoá WireGuard, khoá SSH, mật khẩu SQL được sinh lúc chạy (`keys/`, `wg/`), không nằm trong repo.
- Bộ cài Microsoft được tải từ link chính thức lúc chạy (`scripts/download-installers.sh`), không phân phối lại trong repo.
- Lab chỉ phục vụ kiểm thử; mật khẩu Windows trong `compose.yaml` là mật khẩu lab.
