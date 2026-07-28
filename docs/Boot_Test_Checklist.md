# Boot Test Checklist

Test before calling the USB shop-ready.

## Devices

- Dell laptop: F12 boot menu.
- HP laptop: Esc, then F9.
- Lenovo laptop: F12 or Novo button.
- Surface: hold Volume Down while pressing Power.
- One consumer laptop with Secure Boot enabled.

## Checks

- Ventoy menu appears.
- R2K WinPE ISO boots.
- Internal NVMe/SSD is visible.
- BitLocker status can be checked.
- Reports can write to the USB.
- Robocopy backup can write to external storage.
- Offline SFC menu detects Windows correctly.
- Reboot returns to the customer drive when USB is removed.

