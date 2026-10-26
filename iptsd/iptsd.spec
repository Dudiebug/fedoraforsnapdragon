# iptsd, alex-lentz's fork with the Surface Laptop 7 haptic touchpad: force click
# (frame 0x94 button bit -> BTN_LEFT), click debounce, palm-suppression fix, sleep hook.
# After the fork's own iptsd.spec and 1Martin11/surface-laptop-7-fedora's iptsd-sl7.spec.
# Built with Fedora's gcc toolchain (Fedora's aarch64 branch-protection flags).
%global commit 3663e96e758145801c3cb1ce7c72f362d0d4a5f5
%global shortcommit %(c=%{commit}; echo ${c:0:7})
%global commitdate 20260717

Name:           iptsd
Version:        3.1.0
Release:        0.1.%{commitdate}git%{shortcommit}.sl7%{?dist}
Summary:        Userspace daemon for Surface touch devices (Surface Laptop 7 haptic fork)
License:        GPL-2.0-or-later
URL:            https://github.com/alex-lentz/iptsd
Source0:        %{url}/archive/%{commit}/iptsd-%{shortcommit}.tar.gz

BuildRequires:  meson
BuildRequires:  gcc-c++
# Some dependencies only resolve through cmake
BuildRequires:  cmake
BuildRequires:  cmake(CLI11)
BuildRequires:  pkgconfig(eigen3)
BuildRequires:  pkgconfig(fmt)
BuildRequires:  pkgconfig(inih)
BuildRequires:  cmake(Microsoft.GSL)
BuildRequires:  pkgconfig(spdlog)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(udev)
BuildRequires:  systemd-rpm-macros
Requires:       systemd-udev

%description
iptsd processes the raw HID frames of Surface touch devices and feeds them back to
the kernel as uinput touchpad and touchscreen devices. This is alex-lentz's fork,
which adds the Surface Laptop 7 haptic touchpad's force click, click debouncing and
a sleep hook.

%prep
%autosetup -n iptsd-%{commit}

%build
# calibrate, dump and perf only: plot and show pull in cairomm and SDL2.
%meson --buildtype=release -Dservice_manager=systemd -Dsample_config=true \
    -Ddebug_tools=calibrate,dump,perf
%meson_build

%install
%meson_install

%check
%meson_test

%post
%udev_rules_update

%postun
%udev_rules_update

%files
%license LICENSE
%doc README.md
%config(noreplace) %{_sysconfdir}/iptsd.conf
%dir %{_sysconfdir}/iptsd.d
%dir %{_datadir}/iptsd
%{_datadir}/iptsd/*
%{_bindir}/iptsd
%{_bindir}/iptsd-*
%{_unitdir}/iptsd@.service
%{_udevrulesdir}/50-iptsd.rules
%{_prefix}/lib/systemd/system-sleep/iptsd

%changelog
* Sun Oct 25 2026 fedoraforsnapdragon <52586739+Dudiebug@users.noreply.github.com> - 3.1.0-0.1.20260717git3663e96.sl7
- alex-lentz/iptsd at 3663e96 (2026-07-17) for the Surface Laptop 7 Kinoite image
