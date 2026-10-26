# Test checklist (on the laptop, from USB)

"Done" means every row passes on the real laptop. Report each one with the command
output. Run as the desktop user unless `sudo` is shown.

First, what booted:

```
cat /sys/firmware/devicetree/base/model; echo     # Microsoft Surface Laptop 7 (13.8 inch, SPI touchscreen)
uname -r                                          # 7.3.0-65.sl7.fc44.aarch64
sudo bootc status
/usr/libexec/sl7/sl7-firmware-setup status        # complete (after the first restart)
```

| # | Item | Check | Pass |
|---|---|---|---|
| 1 | Plasma at native resolution | `kscreen-doctor -o` | 2304x1536 (13.8" panel), Plasma Wayland |
| 2 | GPU | `glxinfo -B \| grep -E 'renderer\|version'`; `vulkaninfo --summary \| grep -E 'deviceName\|driverName'` | freedreno / Adreno; turnip |
| 3 | Keyboard | type; Fn keys; `dmesg \| grep -i surface_aggregator` | all keys |
| 4 | Touchpad + haptics | `libinput list-devices \| grep -A3 -i 'iptsd\|touchpad'`; `systemctl status 'iptsd@*'`; press firmly | "IPTSD Virtual Touchpad", force click clicks and buzzes |
| 5 | Touchscreen | `dmesg \| grep -iE 'spi-hid\|spi_hid\|gtch'`; `libinput list-devices \| grep -i -A3 touch` | a touchscreen device; taps and gestures in Plasma |
| 6 | Wi-Fi | `nmcli device wifi list`; `dmesg \| grep ath12k` | connects, no "failed to fetch board data" |
| 7 | Bluetooth | `bluetoothctl show`; pair something | powered, pairs |
| 8 | Speakers, mic | `wpctl status`; play audio at under 70 %; record | sound out and in |
| 9 | Brightness | brightness keys, Plasma slider | changes |
| 10 | Battery | `upower -i $(upower -e \| grep BAT)` | percentage and charging state |
| 11 | Lid suspend/resume | close lid 30 s, open | resumes; touchpad and touchscreen still work |
| 12 | USB-C display | external monitor on USB-C | picture, `kscreen-doctor -o` shows it |
| 13 | Moonlight | Couch mode in SDDM, or Moonlight from the menu; stream from the PC; Moonlight's stats overlay (Ctrl+Alt+Shift+S) | stream runs; note "Hardware" or "Software" decoder |
| 14 | Update and rollback | `sudo bootc upgrade`, reboot, `sudo bootc status`; then pick the second GRUB entry (or `sudo bootc rollback`), reboot | both versions boot |

Speakers: keep the volume at 70 % or less and never pick PipeWire's "Pro Audio"
profile. The kernel limits the amplifier gain (upstream since 7.3), but there is no
active speaker protection on this chip under Linux.

Useful for every report:

```
dmesg | grep -iE 'spi-hid|spi_hid|i2c_hid|ath12k|adsp|cdsp|remoteproc|msm|iris|battmgr|pmic_glink|error' | head -80
journalctl -b -u sl7-firmware-setup -u sl7-flatpak-setup
```

## When the touchscreen stays silent

The device tree powers the GTCH panel with gpio64 (`regulator-gtch-power`) and resets
it on **gpio48**, copied from the 15-inch model. Windows' ACPI for this unit lists only
gpio64 as an output (GpioIo 64; interrupt gpio51, edge, active low). If `spi-hid`
probes but the panel never answers (timeouts, no report descriptor), the next step is
a kernel patch that moves the reset to gpio64 and checks what else powers the panel.
