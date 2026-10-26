#!/bin/bash
# Builds the iptsd RPM (iptsd.spec) in an aarch64 Fedora container, as root.
#   iptsd/build-rpm.sh [--install-deps]
# Output: iptsd/out/*.rpm and iptsd/out/SHA256SUMS.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT=${IPTSD_OUT:-$HERE/out}
TOP=$HERE/work/rpmbuild

for arg in "$@"; do
  case $arg in
    --install-deps) dnf -y install rpm-build rpmdevtools 'dnf-command(builddep)' ;;
    *) echo "usage: iptsd/build-rpm.sh [--install-deps]" >&2; exit 64 ;;
  esac
done

rm -rf "$TOP"
mkdir -p "$TOP"/{SOURCES,SPECS} "$OUT"
cp "$HERE/iptsd.spec" "$TOP/SPECS/"
spectool --get-files --sourcedir --define "_topdir $TOP" "$TOP/SPECS/iptsd.spec"
dnf -y builddep "$TOP/SPECS/iptsd.spec"
rpmbuild -ba --define "_topdir $TOP" "$TOP/SPECS/iptsd.spec"

rm -f "$OUT"/*.rpm "$OUT"/SHA256SUMS
find "$TOP/RPMS" "$TOP/SRPMS" -name '*.rpm' -exec cp -t "$OUT" '{}' +
(cd "$OUT" && sha256sum -- *.rpm > SHA256SUMS && cat SHA256SUMS)
