@echo off
setlocal EnableExtensions EnableDelayedExpansion
title R2K WinPE Command Center
color 0B

set "R2KROOT=%~dp0.."
for %%I in ("%R2KROOT%") do set "R2KROOT=%%~fI"
set "REPORTROOT=%R2KROOT%\Reports\Exports"
if not exist "%REPORTROOT%" mkdir "%REPORTROOT%" >nul 2>&1
set "REPORTDIR=%REPORTROOT%\WinPE_%COMPUTERNAME%_%RANDOM%"
mkdir "%REPORTDIR%" >nul 2>&1

call :FindWindows

:Menu
cls
echo ===============================================================================
echo                         R2K WINPE COMMAND CENTER
echo ===============================================================================
echo Service USB:    %R2KROOT%
echo Windows target: %WINDRIVE%
echo Reports folder: %REPORTDIR%
echo.
echo Use this before the internal Windows drive fully starts.
echo Safe order: report, unlock BitLocker if needed, backup, then repair.
echo.
echo  1 - Re-detect Windows installation
echo  2 - Capture offline report
echo  3 - BitLocker status / unlock drive
echo  4 - Backup user profiles with Robocopy
echo  5 - Offline SFC scan
echo  6 - Offline DISM ScanHealth
echo  7 - Disk and volume list
echo  8 - CHKDSK read-only check
echo  9 - Network initialize and IP info
echo 10 - What fixes what?
echo 11 - Command prompt
echo  Q - Quit
echo.
set /p "SEL=Select: "
if "%SEL%"=="1" goto Detect
if "%SEL%"=="2" goto Report
if "%SEL%"=="3" goto BitLocker
if "%SEL%"=="4" goto Backup
if "%SEL%"=="5" goto SFC
if "%SEL%"=="6" goto DISM
if "%SEL%"=="7" goto Disks
if "%SEL%"=="8" goto Chkdsk
if "%SEL%"=="9" goto Network
if "%SEL%"=="10" goto Help
if "%SEL%"=="11" goto Prompt
if /i "%SEL%"=="Q" goto Quit
goto Menu

:FindWindows
set "WINDRIVE=NOT FOUND"
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist "%%D:\Windows\System32\Config\SYSTEM" (
    set "WINDRIVE=%%D:"
    goto :eof
  )
)
goto :eof

:Detect
call :FindWindows
echo Windows target: %WINDRIVE%
pause
goto Menu

:Report
set "OUT=%REPORTDIR%\WinPE_Report.txt"
echo R2K WinPE Report>"%OUT%"
echo Date: %DATE% %TIME%>>"%OUT%"
echo Windows target: %WINDRIVE%>>"%OUT%"
echo.>>"%OUT%"
echo == IP CONFIG ==>>"%OUT%"
ipconfig /all>>"%OUT%" 2>&1
echo.>>"%OUT%"
echo == BITLOCKER ==>>"%OUT%"
manage-bde -status>>"%OUT%" 2>&1
echo.>>"%OUT%"
echo == BCDEDIT ==>>"%OUT%"
bcdedit /enum all>>"%OUT%" 2>&1
echo.>>"%OUT%"
echo == DISKPART ==>>"%OUT%"
set "DPS=%TEMP%\r2k_diskpart.txt"
echo list disk>"%DPS%"
echo list volume>>"%DPS%"
diskpart /s "%DPS%">>"%OUT%" 2>&1
echo Saved: %OUT%
pause
goto Menu

:BitLocker
if "%WINDRIVE%"=="NOT FOUND" echo No Windows install detected.& pause& goto Menu
manage-bde -status %WINDRIVE%
echo.
set /p "KEY=Enter customer BitLocker recovery key, or leave blank: "
if "%KEY%"=="" goto Menu
manage-bde -unlock %WINDRIVE% -RecoveryPassword %KEY%
pause
goto Menu

:Backup
if "%WINDRIVE%"=="NOT FOUND" echo No Windows install detected.& pause& goto Menu
echo Source: %WINDRIVE%\Users
set /p "DEST=Destination folder, for example E:\Backups\Ticket123: "
if "%DEST%"=="" goto Menu
set /p "GO=Type BACKUP to start: "
if /i not "%GO%"=="BACKUP" goto Menu
robocopy "%WINDRIVE%\Users" "%DEST%\Users" /E /XJ /R:1 /W:1 /TEE /LOG+:"%REPORTDIR%\Robocopy_Users.log"
pause
goto Menu

:SFC
if "%WINDRIVE%"=="NOT FOUND" echo No Windows install detected.& pause& goto Menu
echo Offline SFC repairs protected Windows files when possible.
set /p "GO=Type SFC to run: "
if /i not "%GO%"=="SFC" goto Menu
sfc /scannow /offbootdir=%WINDRIVE%\ /offwindir=%WINDRIVE%\Windows
pause
goto Menu

:DISM
if "%WINDRIVE%"=="NOT FOUND" echo No Windows install detected.& pause& goto Menu
echo DISM ScanHealth checks the offline Windows component store.
set /p "GO=Type DISM to run: "
if /i not "%GO%"=="DISM" goto Menu
dism /Image:%WINDRIVE%\ /Cleanup-Image /ScanHealth
pause
goto Menu

:Disks
set "DPS=%TEMP%\r2k_diskpart.txt"
echo list disk>"%DPS%"
echo list volume>>"%DPS%"
diskpart /s "%DPS%"
pause
goto Menu

:Chkdsk
if "%WINDRIVE%"=="NOT FOUND" echo No Windows install detected.& pause& goto Menu
echo Read-only check. This does not repair.
chkdsk %WINDRIVE%
pause
goto Menu

:Network
wpeinit
ipconfig /all
pause
goto Menu

:Help
cls
echo What fixes what:
echo.
echo No boot: report, BitLocker unlock, backup, offline SFC/DISM, Windows Startup Repair.
echo Bad drive symptoms: stop repairs, image or backup first.
echo Forgot password: Microsoft/local/work recovery paths only; no bypass tools.
echo Malware: backup first, scan from Windows or Defender Offline.
echo Partition issue: backup first, use GParted/Windows tools carefully.
echo.
pause
goto Menu

:Prompt
cmd
goto Menu

:Quit
cmd

