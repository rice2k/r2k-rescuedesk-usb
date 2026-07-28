$kitRoot = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $PSScriptRoot "Manifests\Tool_Manifest.csv"

Clear-Host
Write-Host "=============================================================================="
Write-Host " R2K RESCUEDESK USB v7 - Official Download Pages"
Write-Host "=============================================================================="
Write-Host "This opens official vendor pages. It does not download files automatically."
Write-Host ""

if (-not (Test-Path -LiteralPath $manifest)) {
  Write-Host "Manifest not found: $manifest" -ForegroundColor Red
  pause
  exit 1
}

$rows = Import-Csv -LiteralPath $manifest
$priority = @(
  "Ventoy",
  "Windows ADK",
  "Windows PE Add-on",
  "Windows 11 Installation Media",
  "Rescuezilla",
  "Memtest86+",
  "Microsoft Safety Scanner",
  "Sysinternals Suite",
  "TestDisk and PhotoRec",
  "Snappy Driver Installer Origin"
)

$all = Read-Host "Open all pages? Type ALL, or press Enter for priority pages"
if ($all -eq "ALL") {
  $selected = $rows
} else {
  $selected = $rows | Where-Object { $priority -contains $_.ToolName }
}

$opened = @{}
foreach ($row in $selected) {
  if ($row.OfficialUrl -and -not $opened.ContainsKey($row.OfficialUrl)) {
    Write-Host "Opening $($row.ToolName): $($row.OfficialUrl)" -ForegroundColor Cyan
    Start-Process $row.OfficialUrl
    $opened[$row.OfficialUrl] = $true
    Start-Sleep -Milliseconds 250
  }
}

Write-Host ""
Write-Host "Opened $($opened.Count) page(s)." -ForegroundColor Green
pause
