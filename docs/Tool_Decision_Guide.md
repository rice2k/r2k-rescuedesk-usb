# Tool Decision Guide

## No Boot / Startup Loop

Use:

- Boot the R2K WinPE Command Center.
- Capture offline report.
- Unlock BitLocker if customer provides key.
- Back up data or image the drive.
- Run offline SFC/DISM.
- Use Windows installation media Startup Repair.

Fixes:

- Broken startup files, Windows corruption, failed updates, and data access from a non-booting system.

## Slow / Freezing PC

Use:

- Quick Triage Report.
- CrystalDiskInfo or smartmontools.
- HWiNFO for thermals.
- WizTree for disk space.
- Malware cleanup only after backup if data matters.

Fixes:

- Full drive, failing drive detection, overheating, startup load, and malware/PUP symptoms.

## Malware / Popups / Browser Hijacks

Use:

- AdwCleaner.
- Microsoft Safety Scanner.
- ESET Online Scanner.
- Defender Offline.

Fixes:

- Adware, PUPs, browser hijacks, and common malware.

## No Internet

Use:

- Network reset from the service console.
- OEM or SDIO network drivers.
- IP/DNS checks.
- Wireshark only for deeper authorized troubleshooting.

Fixes:

- DNS cache, Winsock/IP corruption, DHCP problems, and missing drivers.

## Forgot Password

Use:

- Microsoft account reset.
- Local security questions.
- Work/school self-service reset or admin reset.
- BitLocker key lookup.
- Backup plus reset/reinstall with approval.

Do not use:

- Password cracking.
- SAM editing.
- Account bypass tools.

