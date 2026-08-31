@echo off
REM ============================================================
REM   BiliSpeakerAudioFixer  2 - Remux to M4A
REM   Lossless: audio stream is copied, only the container changes.
REM   For: phone / PC / music players
REM ============================================================
cd /d "%~dp0"

if not exist "%~dp0BiliAudioFixer.ps1" (
  echo.
  echo   [!] BiliAudioFixer.ps1 not found.
  echo       Keep this .bat in the same folder as the .ps1 file.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BiliAudioFixer.ps1" -Mode M4A
