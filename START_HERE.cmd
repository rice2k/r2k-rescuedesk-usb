@echo off
setlocal
title R2K RescueDesk USB Launcher
set "ROOT=%~dp0"
set "GUI=%ROOT%Command_Center\R2K_RescueDesk.hta"
set "CONSOLE=%ROOT%Command_Center\R2K_ServiceConsole.ps1"

if exist "%GUI%" (
  echo Launching R2K RescueDesk Command Center...
  start "" mshta.exe "%GUI%"
  exit /b 0
)

if not exist "%CONSOLE%" (
  echo R2K Service Console was not found:
  echo %CONSOLE%
  pause
  exit /b 1
)

echo GUI launcher not found. Opening PowerShell console with Administrator rights...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%CONSOLE%""'"
exit /b 0

