@echo off
setlocal

REM Run the PowerShell test runner with ExecutionPolicy bypassed.
REM This avoids needing Set-ExecutionPolicy (often blocked on Server 2008 R2 / PS2).

set SCRIPT_DIR=%~dp0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-test.ps1"

endlocal
