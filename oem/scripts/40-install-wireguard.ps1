# Muc 3 de xuat: cai WireGuard for Windows, nap cau hinh ORS, chay tunnel nhu service tu khoi dong.
$ErrorActionPreference = 'Stop'
$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i', 'C:\OEM\installers\wireguard-amd64.msi', '/qn', 'DO_NOT_LAUNCH=1'
"msi exit code: $($p.ExitCode)"
$wg = 'C:\Program Files\WireGuard\wireguard.exe'
Copy-Item C:\OEM\factory.conf 'C:\ProgramData\factory.conf' -Force
& $wg /installtunnelservice 'C:\ProgramData\factory.conf'
Start-Sleep 5
Get-Service 'WireGuardTunnel$factory' | Format-Table -AutoSize Name, Status, StartType
Get-NetIPAddress -InterfaceAlias factory -AddressFamily IPv4 | Format-Table -AutoSize IPAddress, InterfaceAlias
Get-NetConnectionProfile | Format-Table -AutoSize InterfaceAlias, NetworkCategory
