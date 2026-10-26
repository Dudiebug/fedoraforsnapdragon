# Booting from USB, updating, rolling back

Everything here runs from a USB stick. Nothing touches the internal SSD or Windows.

## What you need

- A USB stick of 16 GB or more, and a USB-A port for it (see below).
- Secure Boot off. The kernel is not signed. In the Surface UEFI (hold Volume Up while
  pressing Power), Security > Secure Boot > None. Turn it back on to boot only Windows.

## 1. Get the image

Run the `build` workflow by hand with **disk** ticked (Actions > build > Run workflow).
The artifact `sl7-kinoite-raw` holds `sl7-kinoite-44-<date>-<commit>.raw.xz` and its
`.sha256`.

## 2. Write it to the stick

The `.raw.xz` is a whole-disk image. Any of these writes it raw:

- Fedora Media Writer: "Select .iso file", pick the `.raw.xz` (it decompresses).
- Rufus: pick the `.raw.xz`, and choose **DD image mode** when asked.
- Linux: `xz -dc sl7-kinoite-*.raw.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress`

## 3. Boot it

1. Put the stick in the **USB-A** port. The USB-C ports are run by the audio DSP: when
   its firmware starts, they reset, and a stick in USB-C vanishes under the running
   system.
2. Shut down. Hold **Volume Down**, press **Power**, release Volume Down when the
   Surface logo shows. It boots from USB.
3. GRUB shows one entry. Keep it.
4. First boot: the Plasma setup asks for a language, a user and a password.

The first boot has no Microsoft firmware yet, so the desktop runs on the UEFI
framebuffer (no GPU acceleration, no sound, no battery status). Wi-Fi works. The
firmware service then copies the firmware from Windows or downloads it, and a notice
asks for one restart. Details: [FIRMWARE.md](FIRMWARE.md).

## Updating and rolling back

The laptop follows `ghcr.io/dudiebug/fedoraforsnapdragon:44`, which CI rebuilds on
every push to `main` and every Monday.

```
sudo bootc upgrade        # fetch and stage the new image; applies on the next boot
sudo bootc status         # booted, staged and rollback versions
sudo bootc rollback       # make the previous version the default again
```

The previous version is also the second entry in the GRUB menu, so a version that does
not boot is rolled back by picking that entry once (and then `sudo bootc rollback`).

## Installing to the internal SSD

Not yet: only after the USB checklist in [TESTING.md](TESTING.md) passes, and only when
you decide. An installer ISO that boots this image's own kernel is a follow-up
(bootc-image-builder's Anaconda ISO boots Fedora's stock installer kernel, which cannot
start this laptop).
