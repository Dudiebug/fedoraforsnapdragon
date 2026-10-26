# Known issues and open questions

Nothing has been booted on the 13.8-inch laptop yet; this list is what is expected
from the code and from other SL7 projects, per hardware item.

| Item | Expected | Notes |
|---|---|---|
| Boot, DTB | works | dtbloader picks `romulus13-spi-touch` by SMBIOS hardware ID (`11696377-327d-5ad1-b01d-02a7dbb9b99a`); the build checks the mapping |
| Display | framebuffer until the firmware is in, then msm | `clk_ignore_unused pd_ignore_unused` keep the UEFI display alive until msm binds |
| GPU | needs `qcdxkmsuc8380.mbn` | Adreno X1-85 (X1P64100) |
| Keyboard | works | Surface aggregator; also in the initramfs |
| Touchpad, haptics | works on the 15-inch and on 1Martin11's 13.8-inch | iptsd preset `045E:0C77` is the 15-inch calibration; recalibrate if contacts misbehave. Haptic feedback while dragging needs driver work |
| Touchscreen | **open** | the DT's reset pin (gpio48) is copied from the 15-inch; ACPI lists only gpio64. See [TESTING.md](TESTING.md). The DT runs SPI at 20 MHz (ACPI: 40 MHz), which is fine |
| Wi-Fi | works | Fedora's `board-2.bin` has the `17cb:1107` board entry this card reports, so the old board-file hack is not needed. Factory MAC is not restored (random MAC per boot) |
| Bluetooth | adapter up | pairing untested by other projects |
| Speakers, mic | needs ADSP firmware | UCM profile is upstream (alsa-ucm 1.2.16); volume limit upstream since 7.3; keep under 70 % |
| Battery, USB-C | need ADSP firmware | pmic_glink lives on the ADSP; USB-C ports reset when it starts (boot from USB-A) |
| Suspend | untested | patches/0020 restores the touchpad after the lid; resume of touch devices is checklist item 11 |
| Video decode | Iris enabled (patches/0102) | needs `qcvss8380.mbn`; Moonlight may still pick software decode |
| Camera | no | the CAMSS nodes arrive with 7.4 (patch 0022 is held in `series`) |
| Fingerprint, TPM | no | |
| Secure Boot | must be off | the kernel is unsigned |
| Installer ISO | not built | bootc-image-builder's Anaconda ISO uses Fedora's stock installer kernel, which cannot boot this laptop. Follow-up: an installer image built from this image (our kernel), or `bootc install` from the USB system |
| Couch mode | Moonlight in gamescope | the full CouchLiteOS launcher is not ported yet |
