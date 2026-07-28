$kitRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $kitRoot "Reports\Hashes"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Clear-Host
Write-Host "=============================================================================="
Write-Host " R2K RESCUEDESK USB v7 - Hash Toolkit"
Write-Host "=============================================================================="
Write-Host "This creates a SHA256 manifest for the current toolkit files."
Write-Host ""

$out = Join-Path $outDir "R2K_RescueDesk_USB_Hashes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$skip = @("\Reports\Tickets\", "\Reports\Hashes\")
$files = Get-ChildItem -LiteralPath $kitRoot -Recurse -File | Where-Object {
  $path = $_.FullName
  -not ($skip | Where-Object { $path -like "*$_*" })
}

Write-Host "Hashing $($files.Count) file(s)..." -ForegroundColor Cyan
$results = foreach ($file in $files) {
  $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
  [pscustomobject]@{
    RelativePath = $file.FullName.Substring($kitRoot.Length + 1)
    SizeBytes = $file.Length
    SHA256 = $hash.Hash
  }
}

$results | Sort-Object RelativePath | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
Write-Host "Saved: $out" -ForegroundColor Green
pause
