@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell wurde nicht gefunden: "%PS_EXE%"
  echo Bitte stelle sicher, dass PowerShell 2.0 installiert ist.
  pause
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-test.ps1"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo [ERROR] run-test.ps1 wurde mit ExitCode %EXITCODE% beendet.
  pause
)

endlocal
