# Known issues and open questions

The 13.8-inch laptop has booted once, from the installer ISO (kernel `.sl7`, no
Microsoft firmware). Rows marked "first boot" are what was seen there; the rest is
what is expected from the code and from other SL7 projects.

| Item | Expected | Notes |
|---|---|---|
| Boot, DTB | works | dtbloader picks `romulus13-spi-touch` by SMBIOS hardware ID (`11696377-327d-5ad1-b01d-02a7dbb9b99a`); the build checks the mapping |
| Display | framebuffer until the firmware is in, then msm | first boot: picture on the UEFI framebuffer, msm never took over (no modeset). `clk_ignore_unused pd_ignore_unused` keep the UEFI display alive until msm binds; why msm did not bind is open (see the report in [TESTING.md](TESTING.md)) |
| GPU | needs `qcdxkmsuc8380.mbn` | Adreno X1-85 (X1P64100) |
| Keyboard | works (first boot) | Surface aggregator; also in the initramfs |
| Touchpad, haptics | works (first boot); haptics untested | iptsd preset `045E:0C77` is the 15-inch calibration; recalibrate if contacts misbehave. Haptic feedback while dragging needs driver work |
| Touchscreen | **open** | first boot: dead. It was powered only when msm enabled the eDP panel (patches/0005), which never happened; patches/0104 powers it at probe on the 13.8-inch. Still unconfirmed: the reset pin (gpio48, copied from the 15-inch; ACPI lists only gpio64). See [TESTING.md](TESTING.md). The DT runs SPI at 20 MHz (ACPI: 40 MHz), which is fine |
| Wi-Fi | fixed, untested | first boot: adapter listed but hard-blocked (could not be switched on). The rfkill workaround in patches/0001 matched only the 15-inch; it now covers `microsoft,romulus13` too. Fedora's `board-2.bin` (the image now installs `atheros-firmware` explicitly and the build checks the WCN7850 files) has the `17cb:1107` board entry this card reports, so the old board-file hack is not needed. Factory MAC is not restored (random MAC per boot) |
| Bluetooth | adapter up | pairing untested by other projects |
| Speakers, mic | needs ADSP firmware | UCM profile is upstream (alsa-ucm 1.2.16); volume limit upstream since 7.3; keep under 70 % |
| Battery, USB-C | need ADSP firmware | pmic_glink lives on the ADSP; USB-C ports reset when it starts (boot from USB-A) |
| Suspend | untested | patches/0020 restores the touchpad after the lid; resume of touch devices is checklist item 11 |
| Video decode | Iris enabled (patches/0102) | needs `qcvss8380.mbn`; Moonlight may still pick software decode |
| Camera | no | the CAMSS nodes arrive with 7.4 (patch 0022 is held in `series`) |
| Fingerprint, TPM | no | |
| Secure Boot | must be off | the kernel is unsigned |
| Installer ISO | boots (first boot); install untested | built from this image (our kernel, offline payload). A bootc system installed by Anaconda fails `systemd-remount-fs.service` (known upstream, harmless) |
| Couch mode | Moonlight in gamescope | the full CouchLiteOS launcher is not ported yet |
