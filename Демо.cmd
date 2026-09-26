@echo off
set "DEMO_DIR=%~dp0build\releases\20260926-134409-20ea02\Emberwild-Windows-x86_64"
if not exist "%DEMO_DIR%\Emberwild.exe" (
  echo Demo build not found. Extract the demo ZIP and run Emberwild.exe.
  pause
  exit /b 1
)
start "" /D "%DEMO_DIR%" "%DEMO_DIR%\Emberwild.exe"
