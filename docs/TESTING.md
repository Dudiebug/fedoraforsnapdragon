# Test checklist (on the laptop, from USB)

"Done" means every row passes on the real laptop. Report each one with the command
output. Run as the desktop user unless `sudo` is shown.

First, what booted:

```
cat /sys/firmware/devicetree/base/model; echo     # Microsoft Surface Laptop 7 (13.8 inch, SPI touchscreen)
uname -r                                          # 7.3.0-65.sl7.1.fc44.aarch64
sudo bootc status
/usr/libexec/sl7/sl7-firmware-setup status        # complete (after the first restart)
```

| # | Item | Check | Pass |
|---|---|---|---|
| 1 | Plasma at native resolution | `kscreen-doctor -o` | 2304x1536 (13.8" panel), Plasma Wayland |
| 2 | GPU | `glxinfo -B \| grep -E 'renderer\|version'`; `vulkaninfo --summary \| grep -E 'deviceName\|driverName'` | freedreno / Adreno; turnip |
| 3 | Keyboard | type; Fn keys; `dmesg \| grep -i surface_aggregator` | all keys |
| 4 | Touchpad + haptics | `libinput list-devices \| grep -A3 -i 'iptsd\|touchpad'`; `systemctl status 'iptsd@*'`; press firmly | "IPTSD Virtual Touchpad", force click clicks and buzzes |
| 5 | Touchscreen | `dmesg \| grep -iE 'spi-hid\|spi_hid\|gtch'`; `cat /sys/bus/spi/devices/*/power_state`; `libinput list-devices \| grep -i -A3 touch` | `panel_follower=0 supply=1` for the touchscreen; a touchscreen device; taps and gestures in Plasma |
| 6 | Wi-Fi | `rfkill list`; `nmcli device wifi list`; `dmesg \| grep ath12k` | no "Hard blocked: yes"; "applying Surface Laptop 7 rfkill workaround"; connects, no "failed to fetch board data" |
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

## Collecting a report

Plug a second USB stick (FAT, exFAT, NTFS or ext4) into a free port and run:

```
sudo /usr/libexec/sl7/sl7-report
```

It writes `sl7-report-<date>.tar.gz` to that stick (never to the one booted from) and
unmounts it again. `sudo /usr/libexec/sl7/sl7-report DIR` writes to a directory
instead. On the installer ISO, Ctrl+Alt+F2 opens a root shell to run it from. The
report has the kernel log and journal, drivers, rfkill and NetworkManager state, DRM
connectors, the spi-hid sysfs state, GPIO and pin configuration, and deferred probes.
It has no ACPI tables, but the kernel log does show MAC addresses and serial numbers.

Quick look without a stick:

```
dmesg | grep -iE 'spi-hid|spi_hid|i2c_hid|ath12k|adsp|cdsp|remoteproc|msm|iris|battmgr|pmic_glink|error' | head -80
journalctl -b -u sl7-firmware-setup -u sl7-flatpak-setup
```

## When the touchscreen stays silent

Since patches/0104 the 13.8-inch tree powers the GTCH at probe: spi-hid logs "SL7 power
on; waiting for HID enumeration" and `power_state` reads `supply=1 stopping=0
panel_follower=0`. (Before, it waited for the display driver to enable the eDP panel,
which never happened at the first boot: msm did not take over the display.)

The rail is gpio64 (`regulator-gtch-power`) and the reset is **gpio48**, copied from
the 15-inch model. Windows' ACPI for this unit lists only gpio64 as an output
(GpioIo 64; interrupt gpio51, edge, active low). If the power-on line is there but the
panel never answers (timeouts, no report descriptor, no interrupts for it in
`/proc/interrupts`), the report's `gpio.txt` and `pinconf-*.txt` show what gpio48, 51
and 64 are doing; the next step is then a kernel patch that moves the reset to gpio64
and checks what else powers the panel.
