# Cai SQL Server 2008 R2 SP2 Express voi cau hinh MAC DINH (gia lap may nha may hien tai):
# Windows Authentication only, TCP/IP tat, cong dong.
$ErrorActionPreference = 'Stop'
$src = 'C:\OEM\installers\SQLEXPR_x64_ENU.exe'
$dst = 'C:\sqlsetup'
if (-not (Test-Path "$dst\setup.exe")) {
    Start-Process $src -ArgumentList "/q /x:$dst" -Wait
}
$p = Start-Process "$dst\setup.exe" -Wait -PassThru -ArgumentList @(
    '/Q', '/ACTION=Install', '/FEATURES=SQLENGINE', '/INSTANCENAME=SQLEXPRESS',
    '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"', '/SQLSYSADMINACCOUNTS="BUILTIN\ADMINISTRATORS"',
    '/IACCEPTSQLSERVERLICENSETERMS'
)
"setup exit code: $($p.ExitCode)"
Get-Service 'MSSQL$SQLEXPRESS' | Format-Table -AutoSize Name, Status
