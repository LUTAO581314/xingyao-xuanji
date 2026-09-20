@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0cli.ps1" %*
exit /b %errorlevel%
