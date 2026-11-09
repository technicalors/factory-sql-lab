# Cai ban va SQL Server 2008 R2.
#   sp3   : Service Pack 3 (KB2979597) -> build 10.50.6000, CHUA co TLS 1.2
#   tls12 : KB4057113 (SP3 GDR/CU)     -> build 10.50.6560, CO TLS 1.2
param([Parameter(Mandatory)][ValidateSet('sp3', 'tls12')][string]$Patch)
$ErrorActionPreference = 'Stop'
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\100\Tools\Binn\SQLCMD.EXE'
$file = @{ sp3 = 'SQL2008R2SP3-KB2979597-x64.exe'; tls12 = 'SQL2008R2SP3-KB4057113-x64.exe' }[$Patch]
$p = Start-Process "C:\OEM\installers\$file" -Wait -PassThru -ArgumentList '/quiet', '/IAcceptSQLServerLicenseTerms', '/Action=Patch', '/AllInstances'
"patch $Patch exit code: $($p.ExitCode)"
Start-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
& $sqlcmd -S .\SQLEXPRESS -E -h -1 -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + ' ' + CAST(SERVERPROPERTY('ProductLevel') AS varchar(10)) + ' ' + CAST(SERVERPROPERTY('Edition') AS varchar(40))"
