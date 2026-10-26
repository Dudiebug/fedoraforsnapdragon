#!/bin/bash
# Runs inside the image build (Containerfile, RUN): swaps Fedora's kernel for the
# Surface Laptop 7 one, adds the packages, builds the initramfs, enables the services.
# /tmp/rpms holds the kernel and iptsd RPMs from the kernel-* and iptsd-* releases.
# Build context is the repository root: podman build -f image/Containerfile .
set -Eeuo pipefail
shopt -s nullglob

rpms=/tmp/rpms
die() { echo "image/build.sh: $*" >&2; exit 1; }

# 1. Kernel. Fedora's packages out, ours in. kernel-core stays the package of record;
#    its vmlinuz is then replaced by the dtbloader image from kernel-uki-dtbloader
#    (the same kernel wrapped in stubble with every Snapdragon X device tree), which
#    picks this laptop's tree by SMBIOS hardware ID. ostree boots whatever is in
#    /usr/lib/modules/<ver>/vmlinuz, so nothing on the laptop chooses a DTB.
kernel=("$rpms"/kernel-[0-9]*.rpm "$rpms"/kernel-core-[0-9]*.rpm "$rpms"/kernel-modules-core-[0-9]*.rpm
  "$rpms"/kernel-modules-[0-9]*.rpm "$rpms"/kernel-modules-extra-[0-9]*.rpm)
dtbloader=("$rpms"/kernel-uki-dtbloader-[0-9]*.rpm)
((${#kernel[@]} == 5)) || die "expected 5 kernel RPMs in $rpms, found ${#kernel[@]}"
((${#dtbloader[@]} == 1)) || die "expected 1 kernel-uki-dtbloader RPM in $rpms"
kver=$(rpm -qp --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "${kernel[1]}")
[[ $kver == *.sl7* ]] || die "$kver is not an SL7 kernel"

dnf -y install cpio
mapfile -t stock < <(rpm -qa --qf '%{NAME}\n' kernel 'kernel-core' 'kernel-modules*' 'kernel-uki*' | sort -u)
echo "Removing Fedora's kernel: ${stock[*]}"
rpm -e --nodeps "${stock[@]}"
rm -rf /usr/lib/modules/*
# No scriptlets: they would run kernel-install for a host that is not there. depmod,
# the boot image and the initramfs are done explicitly below.
dnf -y install --setopt=tsflags=noscripts "${kernel[@]}"
rpm2cpio "${dtbloader[0]}" | (cd / && cpio -idm --quiet "./lib/modules/$kver/vmlinuz-dtbloader.efi" "./usr/lib/modules/$kver/vmlinuz-dtbloader.efi" 2> /dev/null) || true
mod=/usr/lib/modules/$kver
[[ -s $mod/vmlinuz-dtbloader.efi ]] || die "vmlinuz-dtbloader.efi not extracted from ${dtbloader[0]##*/}"
install -m 0755 "$mod/vmlinuz-dtbloader.efi" "$mod/vmlinuz"
[[ $(ls /usr/lib/modules) == "$kver" ]] || die "more than one kernel in /usr/lib/modules: $(ls /usr/lib/modules)"
depmod -a "$kver"

# 2. Packages. Moonlight and chiaki-ng come from Flathub on first boot
#    (sl7-flatpak-setup); Steam does not exist for aarch64.
dnf -y install "$rpms"/iptsd-[0-9]*.aarch64.rpm \
  mesa-dri-drivers mesa-vulkan-drivers vulkan-tools glx-utils \
  alsa-ucm iio-sensor-proxy plasma-keyboard plasma-setup \
  gamescope msitools kdialog libnotify
dnf clean all

# 3. Initramfs: generic (--no-hostonly), with the SL7 additions and omissions from
#    /usr/lib/dracut/dracut.conf.d/50-sl7.conf.
DRACUT_NO_XATTR=1 dracut --no-hostonly --add ostree --kver "$kver" --reproducible --zstd -f "$mod/initramfs.img"
chmod 0600 "$mod/initramfs.img"
initrd=$(lsinitrd "$mod/initramfs.img")
grep -q 'spi-hid' <<< "$initrd" || die 'spi-hid is not in the initramfs'
grep -q 'surface_aggregator' <<< "$initrd" || die 'the keyboard driver is not in the initramfs'
grep -qE 'qcom_q6v5_pas|/msm\.ko|qcom-iris|ath12k' <<< "$initrd" && die 'firmware-loading drivers ended up in the initramfs'

# 4. Services and file modes (COPY keeps the build host's modes).
chmod 0755 /usr/libexec/sl7/* /usr/bin/sl7-couch-session
systemctl enable sl7-firmware-setup.service sl7-flatpak-setup.service
# First-boot user creation for the raw image (Fedora's preset decides whether it runs).
systemctl preset plasma-setup.service
