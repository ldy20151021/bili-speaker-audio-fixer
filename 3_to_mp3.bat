@echo off
REM ============================================================
REM   BiliSpeakerAudioFixer  3 - Transcode to MP3 (320k)
REM   Real transcoding, audio quality is slightly reduced.
REM   For: video editing / legacy devices / anything needing .mp3
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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BiliAudioFixer.ps1" -Mode MP3
