@echo off
title DeepSeek Harness Installer
echo.
echo DeepSeek Harness one-click installer
echo This script downloads and runs install.ps1 from the public CDN.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1' | iex"
echo.
pause
