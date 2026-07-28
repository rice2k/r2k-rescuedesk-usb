# Build The R2K WinPE Command Center

## Why WinPE

Use Windows PE instead of DOS. WinPE supports modern storage, NTFS, BitLocker tools, networking, DISM, SFC, scripts, and modern hardware better than DOS.

## Required Microsoft Tools

Install on a technician PC:

- Windows ADK.
- Windows PE add-on for the ADK.

## Build Flow

1. Install ADK and WinPE add-on.
2. Open Deployment and Imaging Tools Environment as Administrator.
3. Create a workspace:

```cmd
copype amd64 C:\R2K_WinPE_amd64
```

4. Mount and customize the image.
5. Copy `Boot\WinPE\startnet.cmd` into the WinPE image as `Windows\System32\startnet.cmd`.
6. Build the ISO:

```cmd
MakeWinPEMedia /ISO C:\R2K_WinPE_amd64 C:\R2K_WinPE_amd64\R2K_WinPE_CommandCenter.iso
```

7. Copy the ISO to `Boot\Ventoy_ISOs`.
8. Boot it from a Ventoy USB.

## Boot Flow

1. Customer PC powers on.
2. Tech opens one-time boot menu.
3. Tech chooses the USB.
4. Ventoy opens.
5. Tech selects `R2K_WinPE_CommandCenter.iso`.
6. WinPE launches the R2K pre-Windows menu.

