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

REM Import first. Running a project does not rescan scripts, so a class_name
REM added since the last editor session is missing from tkg\.godot and every
REM script that names it fails to parse. tkg\.godot is gitignored, so a fresh
REM clone has no cache at all. This pass rebuilds it; it costs ~2s once
REM everything is current.
echo   Importing project...
"%GODOT%" --headless --path tkg --import
if errorlevel 1 (
  echo.
  echo   Import failed. The errors above are the reason.
  echo.
  pause
  exit /b 1
)

start "Three Kelvin" "%GODOT%" --path tkg
