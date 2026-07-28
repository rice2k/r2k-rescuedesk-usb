@echo off
wpeinit

set "R2KROOT="
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist "%%D:\R2K_RescueDesk_USB\Command_Center\R2K_WinPE_CommandCenter.cmd" set "R2KROOT=%%D:\R2K_RescueDesk_USB"
  if exist "%%D:\Command_Center\R2K_WinPE_CommandCenter.cmd" set "R2KROOT=%%D:\"
)

if defined R2KROOT (
  call "%R2KROOT%\Command_Center\R2K_WinPE_CommandCenter.cmd"
) else (
  echo R2K RescueDesk USB command center not found.
  echo Check that the USB data partition is visible.
  cmd
)
