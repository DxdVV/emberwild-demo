@echo off
cd /d "%~dp0"
start "Emberwild animations" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." debug/ContentViewer.tscn
