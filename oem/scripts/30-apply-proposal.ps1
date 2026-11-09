# Ap dung dung cac buoc muc 3 + 4 cua file de xuat:
#   TCP/IP bat, IPAll cong co dinh 1433, Mixed Mode, audit dang nhap, restart,
#   Windows Firewall chi cho 10.80.0.1 vao 1433 (moi profile), tao DB mau + login CRUD.
param([Parameter(Mandatory)][string]$SqlPassword)
$ErrorActionPreference = 'Stop'
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\100\Tools\Binn\SQLCMD.EXE'
$base = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10_50.SQLEXPRESS\MSSQLServer'

Set-ItemProperty "$base\SuperSocketNetLib\Tcp" -Name Enabled -Value 1
Set-ItemProperty "$base\SuperSocketNetLib\Tcp\IPAll" -Name TcpDynamicPorts -Value ''
Set-ItemProperty "$base\SuperSocketNetLib\Tcp\IPAll" -Name TcpPort -Value '1433'
Set-ItemProperty $base -Name LoginMode -Value 2      # Mixed Mode
Set-ItemProperty $base -Name AuditLevel -Value 3     # Both failed and successful logins
Restart-Service 'MSSQL$SQLEXPRESS' -Force

Get-NetFirewallRule -DisplayName 'SQL 1433 - Linux ORS qua VPN' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'SQL 1433 - Linux ORS qua VPN' -Direction Inbound -Protocol TCP `
    -LocalPort 1433 -RemoteAddress 10.80.0.1 -Action Allow -Profile Any | Out-Null

& $sqlcmd -S .\SQLEXPRESS -E -b -f 65001 -i C:\OEM\scripts\factory-db.sql -v PW="$SqlPassword"
if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed: $LASTEXITCODE" }
'proposal config applied'
