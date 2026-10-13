@echo off
setlocal
set "SYNK_GODOT=%~dp0.tools\Godot_v4.5.1-stable_win64.exe"
if exist "%SYNK_GODOT%" (
  start "SYNK Editor" "%SYNK_GODOT%" --editor --path "%~dp0."
  exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
  godot --editor --path "%~dp0."
  exit /b
)
where godot4 >nul 2>nul
if not errorlevel 1 (
  godot4 --editor --path "%~dp0."
  exit /b
)
echo Install Godot 4.5.1 or newer and import project.godot in its Project Manager.
pause
