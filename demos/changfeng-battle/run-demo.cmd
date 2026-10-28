@echo off
setlocal DisableDelayedExpansion
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-demo.ps1" %*
exit /b %ERRORLEVEL%
