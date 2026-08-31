@echo off
REM ============================================================
REM   BiliSpeakerAudioFixer  4 - Speaker-safe MP3   <== USE THIS
REM   192k CBR / 44100 Hz / stereo / ID3v2.3 / Xing header
REM   Flattened into "speaker" folder as 001_title.mp3
REM   For: Bluetooth speakers / TF card / car stereo
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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BiliAudioFixer.ps1" -Mode SPK
