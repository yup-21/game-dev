@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launcher.ps1" %*
set "WORKFLOW_STATUS=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %WORKFLOW_STATUS%
