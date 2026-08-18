@echo off
REM Three Kelvin launcher. Double-click to play.
cd /d "%~dp0"

REM Prefer godot on PATH; fall back to the WinGet shim, which is version-independent.
set "GODOT="
where godot >nul 2>nul && set "GODOT=godot"
if not defined GODOT if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"

if not defined GODOT (
  echo.
  echo   Could not find Godot.
  echo   Install it with:  winget install GodotEngine.GodotEngine
  echo.
  pause
  exit /b 1
)

start "Three Kelvin" "%GODOT%" --path tkg
