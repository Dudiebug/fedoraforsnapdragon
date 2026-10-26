# Fedora Kinoite for the Surface Laptop 7

A Fedora Atomic KDE (Kinoite) image for one machine: the Microsoft Surface Laptop 7,
13.8 inch, Snapdragon X Plus X1P64100 (SKU `Surface_Laptop_7th_Edition_2036`,
device tree `x1e80100-microsoft-romulus13-spi-touch`). It is a bootc image: it
updates atomically with `bootc upgrade` and the previous version stays in the boot
menu to roll back to.

**Status: built, not yet booted on the laptop.** See [docs/TESTING.md](docs/TESTING.md)
for the checklist and [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).

| Piece | Where | What |
|---|---|---|
| Kernel | [kernel/](kernel/) | Fedora's own kernel SRPM (7.3.0-65) rebuilt with the SL7 patch series and [config.fragment](kernel/config.fragment); release tag `.sl7` (`7.3.0-65.sl7.fc44.aarch64`) |
| Device tree | [kernel/patches/](kernel/patches/) | Fedora's dtbloader image (stubble) picks the tree by SMBIOS hardware ID; this SKU gets `romulus13-spi-touch`, never chosen on the laptop |
| Touchpad | [iptsd/](iptsd/) | alex-lentz's iptsd fork (haptic force click) as an RPM |
| Image | [image/](image/) | `FROM quay.io/fedora-ostree-desktops/kinoite:44`, kernel swapped, packages, initramfs, services |
| Firmware | [image/files/usr/libexec/sl7/sl7-firmware-setup](image/files/usr/libexec/sl7/sl7-firmware-setup) | Copies Microsoft's signed firmware from Windows (read-only) or the driver MSI on first boot; never shipped here |
| CI | [.github/workflows/build.yml](.github/workflows/build.yml) | Kernel and iptsd RPMs as GitHub releases, image to `ghcr.io/dudiebug/fedoraforsnapdragon`, raw USB image on request |

Install and test from USB: [docs/INSTALL.md](docs/INSTALL.md). Firmware:
[docs/FIRMWARE.md](docs/FIRMWARE.md).

## Kernel patches

`kernel/patches/series`, applied with `--fuzz=0` to the exact tree Fedora's spec
prepares (CI also checks it against kernel.org's 7.3):

| Patches | From | Purpose |
|---|---|---|
| 0001-0027 | [ItsLucas/surface-laptop-7-ubuntu-kernel](https://github.com/ItsLucas/surface-laptop-7-ubuntu-kernel) r15 (GPL-2.0) | ath12k rfkill workaround, the HID-over-SPI transport and its robustness fixes, GTCH SPI touchscreen, panel power, posture events, Iris on 15", QCE |
| 0100 | fQwQf (linux-input), via [1Martin11/surface-laptop-7-fedora](https://github.com/1Martin11/surface-laptop-7-fedora) | 13.8" I2C touchscreen (ITCH) |
| 0101 | [CouchLiteOS](https://github.com/Dudiebug/couchliteos) `arm64-sl7` | 13.8" touchpad wiring, the `romulus13-spi-touch` DTB |
| 0102 | this repo | Iris video codec on both 13.8" trees (drop it if Iris misbehaves) |
| 0103 | this repo | `microsoft,romulus13-spi-touch` as that tree's first compatible, so dtbloader can select it |

The speaker volume limit is upstream since 7.3; the kernel build fails if it ever
disappears. Firmware file list after bryce-hoehn's
[romulus-firmware-extract.sh](https://github.com/bryce-hoehn/linux-surface-laptop-7).

## Rules this repo keeps

No Microsoft/Qualcomm firmware, driver MSI or ACPI dump is ever committed (the MSDM
table holds the Windows product key). Nothing here touches the internal disk, Windows,
EFI variables or Secure Boot.
