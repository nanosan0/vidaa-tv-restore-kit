@echo off
chcp 65001 >nul
title TV 恢复工具 - 海信 VIDAA
echo ================================================
echo   电视一键恢复（去膨胀 + 自制桌面 + 应用重装）
echo ================================================
echo.
echo   需要先做：电视上重新打开「开发者选项 - USB 调试 / 网络调试」
echo   并确认电脑和电视在同一个局域网。
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1" %*
echo.
echo 按任意键关闭窗口...
pause >nul
