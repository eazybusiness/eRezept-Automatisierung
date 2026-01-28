@echo off
setlocal

REM Tool installer launcher for older Windows / PowerShell 2.0
REM Uses ExecutionPolicy Bypass to avoid policy restrictions.

set SCRIPT_DIR=%~dp0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\setup-tools.ps1"

endlocal
