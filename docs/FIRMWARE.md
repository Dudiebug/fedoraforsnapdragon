# Firmware

The Surface Laptop 7 needs firmware that Microsoft and Qualcomm sign for this machine.
Fedora cannot ship it and neither does this repository. `sl7-firmware-setup` installs
it on the laptop, under `/var/lib/firmware` (the kernel looks there first:
`firmware_class.path=/var/lib/firmware`). `/usr` stays read-only.

| File (under `qcom/x1e80100/microsoft/`) | For | Without it |
|---|---|---|
| `qcdxkmsuc8380.mbn` | GPU zap shader | no GPU acceleration (framebuffer only) |
| `Romulus/qcadsp8380.mbn`, `adsp_dtbs.elf` | audio DSP | no speakers, microphones, battery status, USB-C |
| `Romulus/qccdsp8380.mbn`, `cdsp_dtbs.elf` | compute DSP | nothing visible |
| `Romulus/qcvss8380.mbn` | Iris video decoder | software video decode only |
| `Romulus/*.jsn` | userspace pd-mapper | nothing (the kernel's pd-mapper is used) |

Wi-Fi and Bluetooth firmware (`ath12k/WCN7850`, `qca/`) and the Adreno GPU microcode
come from Fedora's own firmware packages. The list of files is
[firmware.list](../image/files/usr/share/sl7/firmware.list), after bryce-hoehn's
`romulus-firmware-extract.sh`.

## How it gets there

On every boot, `sl7-firmware-setup.service` runs `sl7-firmware-setup auto`, which
does nothing once the files are present. Otherwise, in order:

1. **Windows partition.** Every NTFS partition with the Windows data GUID is mounted
   read-only and its `Windows/System32/DriverStore/FileRepository` searched by file
   name (the newest copy wins when several driver versions sit side by side). A
   BitLocker-encrypted partition cannot be read and is skipped; Windows 11 encrypts the
   system drive on many Surface units ("Device encryption").
2. **Microsoft's driver MSI**, only when a network is up and not metered: the current
   `SurfaceLaptop7_ARM_Win11_*.msi` linked from
   <https://www.microsoft.com/en-us/download/details.aspx?id=106120> (about 500 MB),
   unpacked with `msiextract`.

Then it writes `/var/lib/sl7/firmware.status`, and a notice in Plasma asks for one
restart: the DSPs and the GPU request their firmware once, early in boot.

## By hand

```
/usr/libexec/sl7/sl7-firmware-setup status             # complete, or what is missing
sudo /usr/libexec/sl7/sl7-firmware-setup windows       # copy from Windows now
sudo /usr/libexec/sl7/sl7-firmware-setup download      # download the MSI now (metered too)
sudo /usr/libexec/sl7/sl7-firmware-setup msi FILE.msi  # an MSI you downloaded elsewhere
journalctl -b -u sl7-firmware-setup                    # what the boot service did
```

No network on the laptop: connect a phone by USB and turn on USB tethering, or use a
USB Ethernet adapter, or download the MSI on another computer and copy it over on a
second stick. On a phone connection the boot service does not download by itself
(metered); run `download` by hand.

Never copy firmware into this repository or attach it to issues.
