@echo off
chcp 65001 > nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_r18_ko_steam.ps1"
if errorlevel 1 pause
