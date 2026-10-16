@echo off
setlocal
set "SYNK_GODOT=%~dp0.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
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
echo Install Godot 4.7 and import project.godot in its Project Manager.
pause
