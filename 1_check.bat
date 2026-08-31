@echo off
REM ============================================================
REM   BiliSpeakerAudioFixer  1 - Check
REM   Scan only. Does not modify any file. Writes _check_report.csv
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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BiliAudioFixer.ps1" -Mode Check
