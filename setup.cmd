@echo off
rem Double-click launcher for setup.ps1 (bypasses the PowerShell execution policy for this run only).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
pause
