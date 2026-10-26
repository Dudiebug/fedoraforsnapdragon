#!/bin/bash
# Builds the Surface Laptop 7 kernel RPMs from Fedora's kernel SRPM.
#   kernel/build-rpm.sh [--install-deps]
# Runs as root in an aarch64 fedora:$FEDORA_RELEASE container (the kernel workflow:
# GitHub's ubuntu-24.04-arm runner). Steps:
#   1. fetch $KERNEL_SRPM from Koji, check its SHA-256, install it into a private topdir
#   2. spec: release tag $SL7_BUILDID, no Secure Boot signing (our kernel is unsigned),
#      dtbloader hardware IDs that send the 13.8-inch SKU to $SL7_ROMULUS13_TOUCH
#   3. rpmbuild -bp, then apply patches/series to that exact tree with --fuzz=0 and
#      turn the result into the spec's linux-kernel-test.patch (Fedora's hook for local
#      patches); config.fragment becomes kernel-local
#   4. rpmbuild -bb: only the stock aarch64 kernel (no debug, 16k/64k, rt, tools)
#   5. check the result: every fragment line in the shipped config, the 13.8-inch DTBs,
#      Iris enabled, the dtbloader image carrying the spi-touch tree and our hardware IDs
# Output: kernel/out/*.rpm and kernel/out/SHA256SUMS.
# Environment: KERNEL_WORK (default kernel/work), KERNEL_OUT (default kernel/out).
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
WORK=${KERNEL_WORK:-$ROOT/kernel/work}
OUT=${KERNEL_OUT:-$ROOT/kernel/out}
# shellcheck source=kernel/version.conf
source "$HERE/version.conf"
TOP=$WORK/rpmbuild

die() { echo "build-rpm.sh: $*" >&2; exit 1; }

install_deps=0
for arg in "$@"; do
  case $arg in
    --install-deps) install_deps=1 ;;
    *) echo "usage: kernel/build-rpm.sh [--install-deps]" >&2; exit 64 ;;
  esac
done

[[ $(uname -m) == aarch64 ]] || die 'runs on aarch64 only'
[[ ${EUID:-$(id -u)} -eq 0 ]] || die 'run as root (dnf builddep)'

if ((install_deps)); then
  dnf -y install rpm-build rpmdevtools 'dnf-command(builddep)' patch git-core curl python3 \
    dtc binutils cpio ccache stubble systemd-ukify
fi

# 1. SRPM. NVR kernel-<version>-<release>; Koji keeps it under packages/kernel/<v>/<r>/src.
nvr=${KERNEL_SRPM#kernel-}
srpm_version=${nvr%-*}
srpm_release=${nvr##*-}
srpm=$WORK/$KERNEL_SRPM.src.rpm
mkdir -p "$WORK" "$OUT"
if [[ ! -f $srpm ]] || ! sha256sum --check --status <<< "$KERNEL_SRPM_SHA256  $srpm"; then
  curl --fail --location --retry 4 --output "$srpm" \
    "https://kojipkgs.fedoraproject.org/packages/kernel/$srpm_version/$srpm_release/src/$KERNEL_SRPM.src.rpm"
  sha256sum --check --status <<< "$KERNEL_SRPM_SHA256  $srpm" || die "$KERNEL_SRPM.src.rpm does not match KERNEL_SRPM_SHA256"
fi
rm -rf "$TOP"
mkdir -p "$TOP"
rpm -i --define "_topdir $TOP" "$srpm"
spec=$TOP/SPECS/kernel.spec
sources=$TOP/SOURCES

# 2. Spec edits. Each one is checked: a spec change upstream must stop the build, not
#    silently produce a stock-named or wrongly configured kernel.
sed -i "s/^# define buildid .local$/%define buildid $SL7_BUILDID/" "$spec"
grep -qx "%define buildid $SL7_BUILDID" "$spec" || die 'could not set buildid in kernel.spec'
sed -i 's/^%global signkernel 1$/%global signkernel 0/' "$spec"
grep -qx '%global signkernel 1' "$spec" && die 'could not disable signkernel'

# dtbloader: Fedora bundles every Snapdragon X DTB into vmlinuz-dtbloader.efi and lets
# stubble pick one by SMBIOS hardware ID (CHID). Stock hwids map this SKU to
# "microsoft,romulus13", the I2C-touchscreen tree. Our copy maps it to the variant set in
# version.conf; patches/0103 gives the spi-touch tree that first compatible.
hwids_src=/usr/share/stubble/hwids
[[ -d $hwids_src ]] || die "$hwids_src missing (install stubble)"
grep -q -- "--hwids=$hwids_src" "$spec" || die "kernel.spec no longer passes --hwids=$hwids_src"
cp -a "$hwids_src" "$sources/sl7-hwids"
case $SL7_ROMULUS13_TOUCH in
  spi-touch) romulus13_compat=microsoft,romulus13-spi-touch ;;
  i2c) romulus13_compat=microsoft,romulus13 ;;
  *) die "SL7_ROMULUS13_TOUCH must be spi-touch or i2c, not $SL7_ROMULUS13_TOUCH" ;;
esac
romulus13_json=$(find "$sources/sl7-hwids" -name 'x1e80100-microsoft-romulus13.json' | head -n 1)
[[ -n $romulus13_json ]] || die 'no x1e80100-microsoft-romulus13.json in the stubble hwids'
python3 -I - "$romulus13_json" "$romulus13_compat" <<'PY'
import json, sys
path, compat = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as f:
    entry = json.load(f)
if entry.get('compatible') != 'microsoft,romulus13':
    sys.exit(f'{path}: expected compatible microsoft,romulus13, found {entry.get("compatible")!r}')
entry['compatible'] = compat
with open(path, 'w', encoding='utf-8') as f:
    json.dump(entry, f, indent=4)
    f.write('\n')
print(f'hwids: {len(entry["hwids"])} Romulus13 hardware IDs -> {compat}')
PY
sed -i "s|--hwids=$hwids_src|--hwids=%{_sourcedir}/sl7-hwids|" "$spec"

cp "$HERE/config.fragment" "$sources/kernel-local"

dnf -y builddep "$spec"

# Only the stock aarch64 kernel. Unknown --without switches are harmless no-ops.
rpmbuild_opts=(
  --target aarch64 --define "_topdir $TOP"
  --without debug --without debuginfo --without doc --without perf --without libperf
  --without tools --without ynl --without selftests --without bpftool
  --without arm64_16k --without arm64_64k --without realtime --without realtime_arm64_64k
  --without automotive --without efiuki --without kabichk --without kabidwchk
  --without kernel_abi_stablelists --without cross_headers --without headers
  --without configchecks
)

# 3. Patches against the exact tree rpmbuild prepares (Fedora's tarball + redhat patch).
echo "Preparing the Fedora tree"
rpmbuild -bp "${rpmbuild_opts[@]}" "$spec" > "$WORK/prep.log" 2>&1 || { tail -n 50 "$WORK/prep.log"; die 'rpmbuild -bp failed'; }
tree=$(find "$TOP/BUILD" -mindepth 1 -maxdepth 4 -type d -name 'linux-*' -exec test -f '{}/Makefile' ';' -print | head -n 1)
[[ -n $tree ]] || die 'no prepared linux-* tree under BUILD'
echo "Fedora tree: $tree"
(
  cd "$tree"
  git init -q
  git add -A
  git -c user.name=build -c user.email=build@localhost commit -qm fedora
  while read -r patch; do
    [[ -z $patch || $patch == \#* ]] && continue
    echo "Applying $patch"
    patch --batch --forward --fuzz=0 --no-backup-if-mismatch -p1 -i "$HERE/patches/$patch"
  done < "$HERE/patches/series"
  git add -A
  git diff --cached --binary > "$sources/linux-kernel-test.patch"
  # Speaker protection: upstream limits the WSA amplifier volumes since 7.3. Without
  # it, full volume can destroy the speakers (there is no active protection on X1E).
  grep -q 'snd_soc_limit_volume(card, "SpkrLeft PA Volume", 6)' sound/soc/qcom/x1e80100.c \
    || die 'the X1E speaker volume limit is gone from sound/soc/qcom/x1e80100.c'
)
[[ $(wc -l < "$sources/linux-kernel-test.patch") -gt 9 ]] || die 'linux-kernel-test.patch is empty'
rm -rf "$TOP/BUILD"

# 4. Build. ccache through its compiler symlinks when present (the workflow caches it).
[[ -d /usr/lib64/ccache ]] && export PATH=/usr/lib64/ccache:$PATH
echo "Building $KERNEL_SRPM with $SL7_BUILDID"
rpmbuild -bb "${rpmbuild_opts[@]}" "$spec"
command -v ccache > /dev/null && ccache --show-stats || true

# 5. Checks on what was built, then the packages and sums.
rm -f "$OUT"/*.rpm "$OUT"/SHA256SUMS
find "$TOP/RPMS" -name '*.rpm' -exec mv -t "$OUT" '{}' +
core=$(ls "$OUT"/kernel-core-[0-9]*.rpm 2> /dev/null | head -n 1)
dtbloader=$(ls "$OUT"/kernel-uki-dtbloader-[0-9]*.rpm 2> /dev/null | head -n 1)
[[ -n $core ]] || die 'no kernel-core RPM'
[[ -n $dtbloader ]] || die 'no kernel-uki-dtbloader RPM (is stubble installed?)'
check=$WORK/check
rm -rf "$check"
mkdir -p "$check"
(cd "$check" && rpm2cpio "$core" | cpio -idm --quiet && rpm2cpio "$dtbloader" | cpio -idm --quiet)
kver=$(ls "$check/lib/modules" | head -n 1)
[[ $kver == *"${SL7_BUILDID}."* ]] || die "kernel release $kver does not carry $SL7_BUILDID"
mod=$check/lib/modules/$kver

missing=()
while read -r line; do
  [[ $line =~ ^CONFIG_[A-Z0-9_]+=(y|m|[0-9]+|\"[^\"]*\")$ ]] || continue
  grep -qxF "$line" "$mod/config" || missing+=("$line")
done < "$HERE/config.fragment"
if ((${#missing[@]})); then
  printf 'Not in the shipped config (%s):\n' "$kver" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

qcom=$mod/dtb/qcom
for dtb in x1e80100-microsoft-romulus13 x1e80100-microsoft-romulus13-spi-touch x1e80100-microsoft-romulus15; do
  [[ -s $qcom/$dtb.dtb ]] || die "$dtb.dtb is not in kernel-core"
done
[[ $(fdtget "$qcom/x1e80100-microsoft-romulus13-spi-touch.dtb" / compatible) == "microsoft,romulus13-spi-touch microsoft,romulus13 qcom,x1e80100" ]] \
  || die 'romulus13-spi-touch.dtb has the wrong compatible (patches/0103)'
for dtb in x1e80100-microsoft-romulus13 x1e80100-microsoft-romulus13-spi-touch; do
  [[ $(fdtget "$qcom/$dtb.dtb" /soc@0/video-codec@aa00000 status) == okay ]] \
    || die "Iris is not enabled in $dtb.dtb (patches/0102)"
done

efi=$mod/vmlinuz-dtbloader.efi
[[ -s $efi ]] || die 'no vmlinuz-dtbloader.efi'
# This laptop's CHID (Manufacturer + Family + ProductName + ProductSku), as stubble
# computes it from SMBIOS: it must select the tree version.conf asks for.
python3 -I "$HERE/check-dtbloader.py" "$efi" "$SL7_CHID" "$romulus13_compat"
echo "Checked $kver: config fragment, DTBs, Iris, dtbloader"

(cd "$OUT" && sha256sum -- *.rpm > SHA256SUMS && cat SHA256SUMS)
