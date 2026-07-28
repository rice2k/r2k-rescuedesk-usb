param(
  [string]$Workspace = "C:\R2K_WinPE_amd64",
  [string]$IsoPath = "C:\R2K_WinPE_amd64\R2K_WinPE_CommandCenter.iso"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$kitRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$startnet = Join-Path $scriptRoot "startnet.cmd"

function Find-File($root, $name) {
  Get-ChildItem -Path $root -Filter $name -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}

Write-Host "R2K RescueDesk WinPE Builder" -ForegroundColor Cyan
Write-Host "Workspace: $Workspace"
Write-Host "ISO:       $IsoPath"

$adkRoot = "C:\Program Files (x86)\Windows Kits"
$copype = Find-File $adkRoot "copype.cmd"
$make = Find-File $adkRoot "MakeWinPEMedia.cmd"

if (-not $copype -or -not $make) {
  throw "Windows ADK and WinPE add-on tools were not found. Install them first."
}

if (-not (Test-Path -LiteralPath $startnet)) {
  throw "startnet.cmd not found: $startnet"
}

if (-not (Test-Path -LiteralPath $Workspace)) {
  Write-Host "Creating WinPE workspace..." -ForegroundColor Cyan
  cmd /c "`"$($copype.FullName)`" amd64 `"$Workspace`""
}

$bootWim = Join-Path $Workspace "media\sources\boot.wim"
$mount = Join-Path $Workspace "mount"
New-Item -ItemType Directory -Force -Path $mount | Out-Null

Write-Host "Mounting WinPE image..." -ForegroundColor Cyan
dism /Mount-Image /ImageFile:$bootWim /Index:1 /MountDir:$mount

try {
  $targetStartnet = Join-Path $mount "Windows\System32\startnet.cmd"
  Copy-Item -LiteralPath $startnet -Destination $targetStartnet -Force

  $targetKit = Join-Path $mount "R2K_RescueDesk_USB"
  if (Test-Path -LiteralPath $targetKit) {
    Remove-Item -LiteralPath $targetKit -Recurse -Force
  }
  Copy-Item -LiteralPath $kitRoot -Destination $targetKit -Recurse

  Write-Host "Committing WinPE image..." -ForegroundColor Cyan
  dism /Unmount-Image /MountDir:$mount /Commit
} catch {
  Write-Host "Build failed. Discarding mounted image changes..." -ForegroundColor Red
  dism /Unmount-Image /MountDir:$mount /Discard
  throw
}

Write-Host "Creating ISO..." -ForegroundColor Cyan
cmd /c "`"$($make.FullName)`" /ISO `"$Workspace`" `"$IsoPath`""
Write-Host "WinPE ISO created: $IsoPath" -ForegroundColor Green

