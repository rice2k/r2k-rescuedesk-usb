param(
  [string]$Ticket = ""
)

$ErrorActionPreference = "Continue"
$Script:ConsoleRoot = $PSScriptRoot
$Script:KitRoot = Split-Path -Parent $Script:ConsoleRoot
$Script:ReportsRoot = Join-Path $Script:KitRoot "Reports\Tickets"
$Script:CurrentTicket = $Ticket
$Script:ProjectUrl = "https://github.com/rice2k/r2k-rescuedesk-usb"

function Write-R2KBanner {
  param(
    [string]$Title = "Service Console",
    [string]$Subtitle = "One powerful workflow for intake, triage, backup, repair, closeout, and handoff."
  )

  Clear-Host
  $line = "=" * 86
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host " R2K RESCUEDESK USB v7" -ForegroundColor Cyan
  Write-Host " $Title" -ForegroundColor White
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host " $Subtitle" -ForegroundColor Gray
  Write-Host " Source : $Script:ProjectUrl" -ForegroundColor DarkGray
  Write-Host " Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host ""
}

function Write-R2KSection { param([string]$Text) Write-Host ""; Write-Host "-- $Text" -ForegroundColor Cyan }
function Write-R2KInfo { param([string]$Text) Write-Host "[INFO] $Text" -ForegroundColor Gray }
function Write-R2KOk { param([string]$Text) Write-Host "[OK]   $Text" -ForegroundColor Green }
function Write-R2KWarn { param([string]$Text) Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Write-R2KFail { param([string]$Text) Write-Host "[FAIL] $Text" -ForegroundColor Red }
function Pause-R2K { Write-Host ""; Read-Host "Press Enter to continue" | Out-Null }

function Test-R2KAdmin {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function ConvertTo-R2KSafeName {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return "NoTicket_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }
  return ($Value.Trim() -replace '[^A-Za-z0-9._-]', '_')
}

function Get-R2KTicket {
  if ([string]::IsNullOrWhiteSpace($Script:CurrentTicket)) {
    $Script:CurrentTicket = ConvertTo-R2KSafeName (Read-Host "Ticket number")
  } else {
    $Script:CurrentTicket = ConvertTo-R2KSafeName $Script:CurrentTicket
  }
  return $Script:CurrentTicket
}

function Set-R2KTicket {
  $Script:CurrentTicket = ConvertTo-R2KSafeName (Read-Host "Ticket number")
  $dir = Get-R2KTicketDirectory
  Write-R2KOk "Active ticket: $Script:CurrentTicket"
  Write-R2KInfo "Ticket folder: $dir"
}

function Get-R2KTicketDirectory {
  $ticket = Get-R2KTicket
  $dir = Join-Path $Script:ReportsRoot $ticket
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

function New-R2KToolLog {
  param([string]$Tool)
  $dir = Join-Path (Get-R2KTicketDirectory) (ConvertTo-R2KSafeName $Tool)
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  return Join-Path $dir "$($Tool)_$stamp.log"
}

function Confirm-R2K {
  param([string]$Prompt, [string]$Word = "YES")
  Write-Host ""
  Write-R2KWarn $Prompt
  $answer = Read-Host "Type $Word to continue"
  return ($answer -ceq $Word)
}

function Invoke-R2KLoggedCommand {
  param(
    [string]$Name,
    [string]$Command,
    [string[]]$Arguments,
    [string]$Log,
    [int[]]$SuccessExitCodes = @(0)
  )

  Write-R2KInfo "Running: $Name"
  "`r`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Name" | Out-File -LiteralPath $Log -Append -Encoding UTF8
  "Command: $Command $($Arguments -join ' ')" | Out-File -LiteralPath $Log -Append -Encoding UTF8
  & $Command @Arguments 2>&1 | Tee-Object -FilePath $Log -Append
  $code = $LASTEXITCODE
  if ($null -eq $code) { $code = 0 }
  if ($SuccessExitCodes -contains $code) { Write-R2KOk "$Name completed. Exit code: $code" } else { Write-R2KWarn "$Name finished with exit code $code. Review the log." }
  return $code
}

function Open-R2KPath {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) { Start-Process $Path } else { Write-R2KFail "Path not found: $Path"; Pause-R2K }
}

function Get-R2KDriveScore {
  $score = "OK"
  $notes = New-Object System.Collections.Generic.List[string]
  try {
    $disks = Get-PhysicalDisk -ErrorAction Stop
    foreach ($disk in $disks) {
      $health = [string]$disk.HealthStatus
      $op = [string]$disk.OperationalStatus
      $line = "$($disk.FriendlyName): Health=$health Operational=$op Media=$($disk.MediaType)"
      $notes.Add($line)
      if ($health -match 'Unhealthy|Warning|Unknown' -or $op -notmatch 'OK') { $score = "STOP" }
    }
  } catch {
    $score = "CAUTION"
    $notes.Add("Could not read Get-PhysicalDisk: $($_.Exception.Message)")
  }
  return [pscustomobject]@{ Score = $score; Notes = $notes }
}

function New-DeviceSummary {
  Write-R2KBanner "Automatic Device Summary" "Creates a clean summary of the customer PC."
  $log = New-R2KToolLog "Device_Summary"
  $drive = Get-R2KDriveScore

  $summary = [ordered]@{
    Ticket = $Script:CurrentTicket
    ComputerName = $env:COMPUTERNAME
    User = $env:USERNAME
    Date = (Get-Date)
    Manufacturer = ""
    Model = ""
    Serial = ""
    Windows = ""
    RAM_GB = ""
    DriveScore = $drive.Score
  }

  try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $os = Get-CimInstance Win32_OperatingSystem
    $summary.Manufacturer = $cs.Manufacturer
    $summary.Model = $cs.Model
    $summary.Serial = $bios.SerialNumber
    $summary.Windows = "$($os.Caption) $($os.Version)"
    $summary.RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
  } catch {
    Write-R2KWarn "Some device details could not be read."
  }

  "R2K RescueDesk Device Summary" | Out-File -LiteralPath $log -Encoding UTF8
  foreach ($key in $summary.Keys) { "{0}: {1}" -f $key, $summary[$key] | Out-File -LiteralPath $log -Append -Encoding UTF8 }
  "`r`nDrive health notes:" | Out-File -LiteralPath $log -Append -Encoding UTF8
  $drive.Notes | Out-File -LiteralPath $log -Append -Encoding UTF8

  Write-R2KSection "Summary"
  foreach ($key in $summary.Keys) { Write-Host ("{0,-14} {1}" -f ($key + ":"), $summary[$key]) -ForegroundColor Gray }
  if ($drive.Score -eq "STOP") { Write-R2KFail "Drive score is STOP. Back up/image before repair." }
  elseif ($drive.Score -eq "CAUTION") { Write-R2KWarn "Drive score is CAUTION. Review details before repair." }
  else { Write-R2KOk "Drive score is OK." }
  Write-R2KInfo "Saved: $log"
  Pause-R2K
}

function New-IntakeForm {
  Write-R2KBanner "Customer Intake Form" "Creates a professional intake form for the active ticket."
  $dir = Join-Path (Get-R2KTicketDirectory) "Intake"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $out = Join-Path $dir "Intake_Form_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

  $customer = Read-Host "Customer name"
  $phone = Read-Host "Phone/email"
  $device = Read-Host "Device make/model"
  $serial = Read-Host "Serial number"
  $issue = Read-Host "Customer-reported issue"
  $data = Read-Host "Is customer data important? yes/no"
  $bitlocker = Read-Host "BitLocker key available? yes/no/unknown"

  $html = @"
<!doctype html><html><head><meta charset="utf-8"><title>R2K Intake - $Script:CurrentTicket</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;background:#f6f8fc;color:#172033;margin:0}.page{max-width:900px;margin:28px auto;background:#fff;border:1px solid #d8deea;padding:28px}h1{margin:0 0 14px;border-bottom:3px solid #2563eb;padding-bottom:10px}.grid{display:grid;grid-template-columns:180px 1fr;gap:8px}.label{font-weight:700;color:#374151}.box{min-height:70px;border:1px solid #d1d5db;padding:10px;background:#fafafa}.sig{height:44px;border-bottom:1px solid #111;margin-top:24px}</style></head>
<body><div class="page"><h1>R2K RescueDesk Intake</h1><div class="grid">
<div class="label">Ticket</div><div>$Script:CurrentTicket</div>
<div class="label">Customer</div><div>$customer</div>
<div class="label">Phone/Email</div><div>$phone</div>
<div class="label">Device</div><div>$device</div>
<div class="label">Serial</div><div>$serial</div>
<div class="label">Data Important</div><div>$data</div>
<div class="label">BitLocker Key</div><div>$bitlocker</div>
</div><h2>Reported Issue</h2><div class="box">$issue</div>
<h2>Approvals</h2><p>Customer approval is required before backup, malware removal, app removal, reset, reinstall, partition work, firmware updates, or account recovery escalation.</p>
<div class="sig"></div><p>Customer signature / approval</p></div></body></html>
"@
  $html | Out-File -LiteralPath $out -Encoding UTF8
  Write-R2KOk "Intake form created."
  Write-R2KInfo $out
  Start-Process $out
  Pause-R2K
}

function Run-QuickTriage {
  Write-R2KBanner "Quick Triage Report" "Read-only evidence collection and automatic drive score."
  if (-not (Test-R2KAdmin)) { Write-R2KWarn "Administrator rights are recommended for full results." }
  $log = New-R2KToolLog "Quick_Triage"
  $drive = Get-R2KDriveScore
  "R2K Quick Triage Report" | Out-File -LiteralPath $log -Encoding UTF8
  "Date: $(Get-Date)" | Out-File -LiteralPath $log -Append -Encoding UTF8
  "Computer: $env:COMPUTERNAME" | Out-File -LiteralPath $log -Append -Encoding UTF8
  "Ticket: $Script:CurrentTicket" | Out-File -LiteralPath $log -Append -Encoding UTF8
  "DriveScore: $($drive.Score)" | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== DRIVE NOTES ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  $drive.Notes | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== SYSTEMINFO ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  systeminfo | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== IP CONFIG ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  ipconfig /all | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== HOTFIXES ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  Get-HotFix | Format-Table -AutoSize | Out-String | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== VOLUMES ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  Get-Volume | Format-Table -AutoSize | Out-String | Out-File -LiteralPath $log -Append -Encoding UTF8
  "`r`n== BITLOCKER ==" | Out-File -LiteralPath $log -Append -Encoding UTF8
  try { Get-BitLockerVolume | Format-Table -AutoSize | Out-String | Out-File -LiteralPath $log -Append -Encoding UTF8 } catch { "BitLocker unavailable: $_" | Out-File -LiteralPath $log -Append -Encoding UTF8 }
  Write-R2KOk "Triage report complete."
  Write-R2KInfo "Drive score: $($drive.Score)"
  Write-R2KInfo $log
  Pause-R2K
}

function Invoke-BackupGate {
  param([string]$Operation)
  $drive = Get-R2KDriveScore
  if ($drive.Score -eq "STOP") {
    Write-R2KFail "Drive score is STOP. Back up or image before $Operation."
    return (Confirm-R2K "Override backup gate for $Operation? Use only if customer approved risk." "OVERRIDE")
  }
  Write-R2KWarn "Before $Operation, confirm customer data is backed up or not needed."
  return (Confirm-R2K "Continue with $Operation?" "CONTINUE")
}

function Run-UserBackup {
  Write-R2KBanner "One-Click User Profile Backup" "Guided Robocopy backup before risky work."
  $defaultSource = "C:\Users"
  $source = Read-Host "Source folder [$defaultSource]"
  if ([string]::IsNullOrWhiteSpace($source)) { $source = $defaultSource }
  if (-not (Test-Path -LiteralPath $source)) { Write-R2KFail "Source not found: $source"; Pause-R2K; return }
  $dest = Read-Host "Destination folder, for example E:\Backups\$(Get-R2KTicket)"
  if ([string]::IsNullOrWhiteSpace($dest)) { Write-R2KFail "Destination is required."; Pause-R2K; return }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $target = Join-Path $dest "Users"
  $log = New-R2KToolLog "User_Backup"
  Write-R2KInfo "Source: $source"
  Write-R2KInfo "Destination: $target"
  Write-R2KInfo "Log: $log"
  if (-not (Confirm-R2K "Start customer data backup?" "BACKUP")) { return }
  $code = Invoke-R2KLoggedCommand -Name "Robocopy user backup" -Command "robocopy.exe" -Arguments @($source, $target, "/E", "/XJ", "/R:1", "/W:1", "/TEE", "/LOG+:$log") -Log $log -SuccessExitCodes @(0,1,2,3,4,5,6,7)
  if ($code -le 7) { Write-R2KOk "Backup completed with acceptable Robocopy status." } else { Write-R2KFail "Backup reported errors. Review the log." }
  Pause-R2K
}

function Run-WindowsRepair {
  Write-R2KBanner "Windows Repair" "DISM RestoreHealth followed by SFC ScanNow."
  if (-not (Invoke-BackupGate "Windows repair")) { Write-R2KWarn "Cancelled by backup gate."; Pause-R2K; return }
  if (-not (Confirm-R2K "Run Windows repair sequence now?" "REPAIR")) { return }
  $log = New-R2KToolLog "Windows_Repair"
  Invoke-R2KLoggedCommand -Name "DISM RestoreHealth" -Command "DISM.exe" -Arguments @("/Online","/Cleanup-Image","/RestoreHealth") -Log $log | Out-Null
  Invoke-R2KLoggedCommand -Name "SFC ScanNow" -Command "sfc.exe" -Arguments @("/scannow") -Log $log | Out-Null
  Write-R2KOk "Windows repair sequence finished."
  Write-R2KInfo "Log: $log"
  Pause-R2K
}

function Run-NetworkReset {
  Write-R2KBanner "Network Reset" "Reset DNS, DHCP, Winsock, and TCP/IP."
  Write-R2KWarn "Active network connections will drop. Reboot after completion."
  if (-not (Confirm-R2K "Reset networking components now?" "RESET")) { return }
  $log = New-R2KToolLog "Network_Reset"
  Invoke-R2KLoggedCommand -Name "Flush DNS" -Command "ipconfig.exe" -Arguments @("/flushdns") -Log $log | Out-Null
  Invoke-R2KLoggedCommand -Name "Release DHCP" -Command "ipconfig.exe" -Arguments @("/release") -Log $log -SuccessExitCodes @(0,1) | Out-Null
  Invoke-R2KLoggedCommand -Name "Renew DHCP" -Command "ipconfig.exe" -Arguments @("/renew") -Log $log -SuccessExitCodes @(0,1) | Out-Null
  Invoke-R2KLoggedCommand -Name "Reset Winsock" -Command "netsh.exe" -Arguments @("winsock","reset") -Log $log | Out-Null
  Invoke-R2KLoggedCommand -Name "Reset TCP/IP" -Command "netsh.exe" -Arguments @("int","ip","reset") -Log $log -SuccessExitCodes @(0,1) | Out-Null
  Write-R2KOk "Network reset complete. Reboot recommended."
  Pause-R2K
}

function Run-AppCleanup {
  Write-R2KBanner "Optional App Cleanup" "Prompted cleanup of common preinstalled apps for the current user."
  Write-R2KWarn "Use only with customer approval. Do not use on managed work/school PCs unless policy allows it."
  if (-not (Invoke-BackupGate "app cleanup")) { Write-R2KWarn "Cancelled by backup gate."; Pause-R2K; return }
  $apps = @("Microsoft.BingNews","Microsoft.BingWeather","Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.MicrosoftSolitaireCollection","Microsoft.People","Microsoft.SkypeApp","Microsoft.Todos","Microsoft.Xbox.TCUI","Microsoft.XboxApp","Microsoft.XboxGamingOverlay","Microsoft.XboxSpeechToTextOverlay","Microsoft.ZuneMusic","Microsoft.ZuneVideo","MicrosoftTeams") | Sort-Object -Unique
  $log = New-R2KToolLog "App_Cleanup"
  foreach ($app in $apps) {
    $installed = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
    if ($installed) { Write-Host "  [installed] $app" -ForegroundColor White } else { Write-Host "  [missing]   $app" -ForegroundColor DarkGray }
  }
  if (-not (Confirm-R2K "Remove installed apps from this list for the current user?" "REMOVE")) { return }
  "R2K App Cleanup - $(Get-Date)" | Out-File -LiteralPath $log -Encoding UTF8
  foreach ($app in $apps) {
    $packages = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
    foreach ($package in $packages) {
      try {
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
        "Removed: $($package.PackageFullName)" | Out-File -LiteralPath $log -Append -Encoding UTF8
        Write-R2KOk "Removed $app"
      } catch {
        "Failed: $app - $($_.Exception.Message)" | Out-File -LiteralPath $log -Append -Encoding UTF8
        Write-R2KWarn "Could not remove $app."
      }
    }
  }
  Write-R2KInfo "Log: $log"
  Pause-R2K
}

function Start-WorkflowLog {
  param([string]$Name, [string]$Doc)
  $log = New-R2KToolLog $Name
  "R2K workflow checkpoint: $Name" | Out-File -LiteralPath $log -Encoding UTF8
  "Date: $(Get-Date)" | Out-File -LiteralPath $log -Append -Encoding UTF8
  "Ticket: $Script:CurrentTicket" | Out-File -LiteralPath $log -Append -Encoding UTF8
  if ($Doc) { Start-Process $Doc }
  Write-R2KOk "$Name workflow checkpoint created."
  Write-R2KInfo "Log: $log"
  Pause-R2K
}

function New-CustomerReport {
  Write-R2KBanner "Customer Handoff Report" "Create branded HTML and Markdown report with QR/link section."
  $dir = Join-Path (Get-R2KTicketDirectory) "Customer_Report"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $md = Join-Path $dir "Customer_Report_$stamp.md"
  $html = Join-Path $dir "Customer_Report_$stamp.html"
  $customer = Read-Host "Customer name"
  $tech = Read-Host "Technician"
  $device = Read-Host "Device make/model"
  $serial = Read-Host "Serial number"
  $issue = Read-Host "Reported issue"
  $work = Read-Host "Work performed"
  $backup = Read-Host "Backup performed/location"
  $next = Read-Host "Recommended next steps"
  $link = Read-Host "Customer link or QR destination (optional)"
  $content = @"
# R2K RescueDesk Customer Report

- Ticket: $Script:CurrentTicket
- Customer: $customer
- Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- Technician: $tech
- Device: $device
- Serial: $serial
- Customer link / QR destination: $link

## Reported Issue
$issue

## Work Performed
$work

## Backup
$backup

## Recommended Next Steps
$next
"@
  $content | Out-File -LiteralPath $md -Encoding UTF8
  $encoded = [System.Net.WebUtility]::HtmlEncode($content) -replace "`r?`n","<br>"
  $linkHtml = if ($link) { "<a href='$link'>$link</a><div class='qr'>QR / LINK</div>" } else { "<div class='qr'>Add customer QR or link here</div>" }
  "<!doctype html><html><head><meta charset='utf-8'><title>R2K RescueDesk Report</title><style>body{font-family:Segoe UI,Arial,sans-serif;background:#f6f8fc;margin:0;color:#172033}.page{max-width:940px;margin:28px auto;background:#fff;border:1px solid #d1d7e3;padding:30px}.brand{color:#2563eb;font-weight:800;letter-spacing:.08em;text-transform:uppercase}h1{border-bottom:3px solid #2563eb;padding-bottom:10px}.qr{width:130px;height:130px;border:2px dashed #2563eb;display:flex;align-items:center;justify-content:center;color:#2563eb;font-weight:700;margin-top:12px;background:#eef6ff}.content{line-height:1.55}</style></head><body><div class='page'><div class='brand'>R2K RescueDesk USB</div><h1>Customer Handoff Report</h1><div class='content'>$encoded</div><h2>Customer Link / QR</h2>$linkHtml</div></body></html>" | Out-File -LiteralPath $html -Encoding UTF8
  Write-R2KOk "Report created."
  Write-R2KInfo "Markdown: $md"
  Write-R2KInfo "HTML: $html"
  Start-Process $html
  Pause-R2K
}

function Test-ToolInventory {
  Write-R2KBanner "Missing Tool Dashboard" "Checks manifest folders for downloaded files."
  $manifest = Join-Path $Script:KitRoot "Admin\Manifests\Tool_Manifest.csv"
  $rows = Import-Csv -LiteralPath $manifest
  $missing = @()
  foreach ($row in $rows) {
    $folder = Join-Path $Script:KitRoot $row.Folder
    $hasFile = (Test-Path -LiteralPath $folder) -and (Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^README' } | Select-Object -First 1)
    if (-not $hasFile) { $missing += $row }
  }
  if ($missing.Count -eq 0) { Write-R2KOk "No missing tool folders detected." }
  else {
    Write-R2KWarn "$($missing.Count) manifest item(s) have empty target folders."
    $missing | Select-Object ToolName, Folder, RiskLevel, OfficialUrl | Format-Table -AutoSize
    $open = Read-Host "Open missing tool official pages? y/N"
    if ($open -match '^(y|Y)') { foreach ($row in $missing) { Start-Process $row.OfficialUrl; Start-Sleep -Milliseconds 200 } }
  }
  Pause-R2K
}

function Open-DownloadPages {
  Write-R2KBanner "Official Download Pages" "Open official vendor pages from the manifest."
  $manifest = Join-Path $Script:KitRoot "Admin\Manifests\Tool_Manifest.csv"
  $rows = Import-Csv -LiteralPath $manifest
  $priority = @("Ventoy","Windows ADK","Windows PE Add-on","Windows 11 Installation Media","Rescuezilla","Memtest86+","Microsoft Safety Scanner","Sysinternals Suite","TestDisk and PhotoRec","Snappy Driver Installer Origin")
  $choice = Read-Host "Open priority only? Y/n"
  if ($choice -match '^(n|N)') { $selected = $rows } else { $selected = $rows | Where-Object { $priority -contains $_.ToolName } }
  $opened = @{}
  foreach ($row in $selected) {
    if ($row.OfficialUrl -and -not $opened.ContainsKey($row.OfficialUrl)) {
      Write-R2KInfo "Opening $($row.ToolName)"
      Start-Process $row.OfficialUrl
      $opened[$row.OfficialUrl] = $true
      Start-Sleep -Milliseconds 200
    }
  }
  Write-R2KOk "Opened $($opened.Count) page(s)."
  Pause-R2K
}

function New-HashManifest {
  Write-R2KBanner "Hash Toolkit" "Generate SHA256 hash manifest."
  $outDir = Join-Path $Script:KitRoot "Reports\Hashes"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $out = Join-Path $outDir "R2K_RescueDesk_Hashes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
  $skip = @("\Reports\Tickets\", "\Reports\Hashes\")
  $files = Get-ChildItem -LiteralPath $Script:KitRoot -Recurse -File | Where-Object {
    $path = $_.FullName
    -not ($skip | Where-Object { $path -like "*$_*" })
  }
  $results = foreach ($file in $files) {
    $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
    [pscustomobject]@{ RelativePath = $file.FullName.Substring($Script:KitRoot.Length + 1); SizeBytes = $file.Length; SHA256 = $hash.Hash }
  }
  $results | Sort-Object RelativePath | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
  Write-R2KOk "Hash manifest saved."
  Write-R2KInfo $out
  Pause-R2K
}

function Close-R2KTicket {
  Write-R2KBanner "Close Ticket" "Gather ticket artifacts, create index, and package closeout zip."
  $ticketDir = Get-R2KTicketDirectory
  $closeDir = Join-Path $ticketDir "_Closeout"
  New-Item -ItemType Directory -Force -Path $closeDir | Out-Null
  $index = Join-Path $closeDir "Closeout_Index.html"
  $files = Get-ChildItem -LiteralPath $ticketDir -Recurse -File | Where-Object { $_.FullName -notlike "$closeDir*" }
  $items = ($files | ForEach-Object { "<li>$($_.FullName.Substring($ticketDir.Length + 1))</li>" }) -join "`r`n"
  "<!doctype html><html><head><meta charset='utf-8'><title>R2K Closeout $Script:CurrentTicket</title><style>body{font-family:Segoe UI,Arial,sans-serif;margin:28px;color:#172033}h1{border-bottom:3px solid #2563eb;padding-bottom:10px}</style></head><body><h1>R2K Ticket Closeout: $Script:CurrentTicket</h1><p>Created: $(Get-Date)</p><h2>Artifacts</h2><ul>$items</ul></body></html>" | Out-File -LiteralPath $index -Encoding UTF8
  $exportDir = Join-Path $Script:KitRoot "Reports\Exports"
  New-Item -ItemType Directory -Force -Path $exportDir | Out-Null
  $zip = Join-Path $exportDir "$($Script:CurrentTicket)_Closeout_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
  Compress-Archive -LiteralPath $ticketDir -DestinationPath $zip -Force
  Write-R2KOk "Ticket closeout package created."
  Write-R2KInfo "Index: $index"
  Write-R2KInfo "Zip:   $zip"
  Pause-R2K
}

function Show-MainMenu {
  if ([string]::IsNullOrWhiteSpace($Script:CurrentTicket)) { Set-R2KTicket }
  while ($true) {
    Write-R2KBanner
    if (Test-R2KAdmin) { Write-R2KOk "Running as Administrator." } else { Write-R2KWarn "Not running as Administrator." }
    Write-R2KInfo "Active ticket: $Script:CurrentTicket"
    Write-Host ""
    Write-Host " 1. Set/change ticket number" -ForegroundColor White
    Write-Host " 2. Create customer intake form" -ForegroundColor White
    Write-Host " 3. Automatic device summary + drive score" -ForegroundColor White
    Write-Host " 4. Quick triage report" -ForegroundColor White
    Write-Host " 5. One-click user profile backup" -ForegroundColor White
    Write-Host " 6. Repair Windows (backup-gated DISM + SFC)" -ForegroundColor White
    Write-Host " 7. Reset network stack" -ForegroundColor White
    Write-Host " 8. Optional app cleanup (backup-gated)" -ForegroundColor White
    Write-Host " 9. Malware cleanup workflow" -ForegroundColor White
    Write-Host "10. Post-repair checklist" -ForegroundColor White
    Write-Host "11. Create customer report with QR/link section" -ForegroundColor White
    Write-Host "12. Check missing tools / open download dashboard" -ForegroundColor White
    Write-Host "13. Open official download pages" -ForegroundColor White
    Write-Host "14. Generate hash manifest" -ForegroundColor White
    Write-Host "15. Close ticket and package artifacts" -ForegroundColor White
    Write-Host "16. Open GUI launchpad" -ForegroundColor White
    Write-Host "17. Open Tools folder" -ForegroundColor White
    Write-Host "18. Open Reports folder" -ForegroundColor White
    Write-Host " Q. Quit" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Select"
    switch -Regex ($choice) {
      '^1$' { Set-R2KTicket; Pause-R2K }
      '^2$' { New-IntakeForm }
      '^3$' { New-DeviceSummary }
      '^4$' { Run-QuickTriage }
      '^5$' { Run-UserBackup }
      '^6$' { Run-WindowsRepair }
      '^7$' { Run-NetworkReset }
      '^8$' { Run-AppCleanup }
      '^9$' { Start-WorkflowLog -Name "Malware_Workflow" -Doc (Join-Path $Script:KitRoot "Docs\Malware_Workflow.md") }
      '^10$' { Start-WorkflowLog -Name "Post_Repair_Checklist" -Doc (Join-Path $Script:KitRoot "Docs\Post_Repair_Checklist.md") }
      '^11$' { New-CustomerReport }
      '^12$' { Test-ToolInventory; Open-R2KPath (Join-Path $Script:KitRoot "Admin\Download_Dashboard.html") }
      '^13$' { Open-DownloadPages }
      '^14$' { New-HashManifest }
      '^15$' { Close-R2KTicket }
      '^16$' { Open-R2KPath (Join-Path $Script:KitRoot "START_HERE.html") }
      '^17$' { Open-R2KPath (Join-Path $Script:KitRoot "Tools") }
      '^18$' { Open-R2KPath (Join-Path $Script:KitRoot "Reports") }
      '^(Q|q)$' { return }
      default { Write-R2KWarn "Invalid selection."; Pause-R2K }
    }
  }
}

Show-MainMenu
