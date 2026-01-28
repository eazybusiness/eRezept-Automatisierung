@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell wurde nicht gefunden: "%PS_EXE%"
  pause
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%diagnose.ps1"

endlocal
