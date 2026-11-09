#!/bin/sh
# Tải bộ cài chính thức (Microsoft / WireGuard) vào oem/installers
set -e
mkdir -p "$(dirname "$0")/../oem/installers" && cd "$(dirname "$0")/../oem/installers"
[ -s SQLEXPR_x64_ENU.exe ] || curl -fsSL -o SQLEXPR_x64_ENU.exe          https://download.microsoft.com/download/0/4/b/04be03cd-eaf3-4797-9d8d-2e08e316c998/SQLEXPR_x64_ENU.exe
[ -s SQL2008R2SP3-KB2979597-x64.exe ] || curl -fsSL -o SQL2008R2SP3-KB2979597-x64.exe https://download.microsoft.com/download/d/7/a/d7a28b6c-fcfe-4f70-a902-b109388e01e9/ENU/SQLServer2008R2SP3-KB2979597-x64-ENU.exe
[ -s SQL2008R2SP3-KB4057113-x64.exe ] || curl -fsSL -o SQL2008R2SP3-KB4057113-x64.exe https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2018/02/sqlserver2008r2-kb4057113-x64_7b9e28a50fd475fa74e90d2c10c02ff5aa34087f.exe
[ -s wireguard-amd64.msi ] || curl -fsSL -o wireguard-amd64.msi           https://download.wireguard.com/windows-client/wireguard-amd64-1.1.1.msi
[ -s OpenSSH-Win64.msi ] || curl -fsSL -o OpenSSH-Win64.msi            https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.4.0.0p1-Preview/OpenSSH-Win64-v10.4.0.0.msi
ls -la
