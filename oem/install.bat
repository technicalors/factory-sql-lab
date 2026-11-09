@echo off
rem Chay 1 lan khi cai Windows xong (dockur copy thu muc nay vao C:\OEM).
rem Chi chuan bi kenh quan tri lab (OpenSSH) va .NET 3.5 cho SQL 2008 R2.
rem Cac buoc cua phuong an (SQL, WireGuard, Firewall) chay sau qua SSH bang C:\OEM\scripts\*.ps1
set LOG=C:\OEM\install.log
echo [%date% %time%] start >> %LOG%

msiexec /i C:\OEM\installers\OpenSSH-Win64.msi /qn /norestart >> %LOG% 2>&1
copy /y C:\OEM\administrators_authorized_keys C:\ProgramData\ssh\administrators_authorized_keys >> %LOG% 2>&1
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" >> %LOG% 2>&1
powershell -NoProfile -Command "New-NetFirewallRule -DisplayName 'LAB ssh quan tri' -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress 172.30.0.0/24 -Action Allow -Profile Any" >> %LOG% 2>&1
sc config sshd start= auto >> %LOG% 2>&1
net start sshd >> %LOG% 2>&1

DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet >> %LOG% 2>&1
echo [%date% %time%] done >> %LOG%
