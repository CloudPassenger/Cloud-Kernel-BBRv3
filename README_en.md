<div align="center">

<img src="Cloudy%20Kernel.png" alt="Cloud Kernel BBRv3" width="100%">

# Cloud Kernel BBRv3

**A Debian custom kernel with BBRv3 / BBRPlus / Brutal, based on Debian Cloud kernel configuration, optimized for VPS stable operation**

[![CI](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml)
[![Upstream Check](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml)
[![License](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org/)

![Kernel Series](https://img.shields.io/badge/kernel-6.12%20%7C%206.18%20%7C%207.1-blue)
![BBRv3](https://img.shields.io/badge/BBR-v3-brightgreen)
![BBRPlus](https://img.shields.io/badge/BBR-Plus-orange)
![TCP Brutal](https://img.shields.io/badge/TCP-Brutal-red)
![EEVDF](https://img.shields.io/badge/scheduler-EEVDF-blueviolet)
![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-yellow)

English | [简体中文](README.md)

</div>

## 📦 Project Overview

Maintained kernel series:

| Series | Track | x86_64 | arm64 | Auto-update |
|---|:---:|:---:|:---:|:---:|
| `6.12` | LTS | ✅ | ✅ | ✅ |
| `6.18` | LTS | ✅ | ✅ | ✅ |
| `7.1` | Active stable | ✅ | ✅ | ✅ |

The installer defaults to `7.1`, while every maintained series can be selected explicitly. `check-upstream.yml` checks the latest Debian upstream version for each series daily and only triggers a build when the matching architecture-specific release tag does not yet exist.

> [!IMPORTANT]
> **Kernel suffix change**: starting with the most recent update, kernels released by this project carry a `-cloudy` suffix by default (`CONFIG_LOCALVERSION="-cloudy"`).
> As a result `uname -r` now reports something like `7.1.6-cloudy`, and files install to `/boot/vmlinuz-<version>-cloudy` and `/lib/modules/<version>-cloudy/`.
> This prevents file conflicts with the distribution's own kernel of the same version and keeps the stock kernel available as a fallback boot entry.
> Older releases built without a suffix are unaffected; if you previously installed one, the old and new kernels will coexist after upgrading, and you can remove the old package once the new kernel boots correctly.

This repository builds multiple package formats from one identically patched and resolved kernel source tree:
- Using official Linux Kernel source (6.12 / 6.18 / 7.1 series, from [kernel.org](https://www.kernel.org/))
- Integrating patches maintained by the Debian kernel team (from [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/))
- **BBR Congestion Control Algorithm Updates!**
  - Updated **BBRv3 congestion control** from Google (using [xanmod/linux-patches](https://gitlab.com/xanmod/linux-patches))
  - Retained original BBRv1 algorithm (set congestion control to `bbr1` to use)
  - Integrated modified **BBRPlus** congestion control algorithm from dog250 & cx9208 (modified from [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable))
- Integrated **TCP Brutal** multiplexing (mux) congestion control algorithm from apernet (from [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal))
- Uses the upstream **EEVDF** fair scheduler by default without third-party Scheduler patches
- Multi-architecture support (x86_64 & arm64), daily automatic builds tracking updates
- Generic package support: build one RPM set and one APK set, add one Arch Linux pacman package set for x86_64, then validate install/remove lifecycles in containers

## 🚀 Key Features

| Component          | Details                                                                 |
|--------------------|-------------------------------------------------------------------------|
| Kernel Base        | 6.12 / 6.18 / 7.1 series + Debian team patches                        |
| Network Optimize   | BBRv3 (built-in default) / BBRPlus / BBRv1 / Brutal (modules) + `sch_fq` qdisc |
| CPU Scheduler      | Upstream EEVDF fair scheduler                                          |
| Memory Policy      | THP `madvise`, autogroup & default NUMA balancing disabled             |
| CPU Scale (x86)    | `NR_CPUS=512`, `MAXSMP` disabled, sized for VPS                       |
| Hardening          | `LIST_HARDENED` retained; x86 CPU mitigations disabled by policy       |
| ZRAM Swap          | Multi-compression support (LZO + ZSTD)                                |
| Driver Trim        | Unused NIC vendor drivers stripped to reduce kernel size              |
| Kernel Suffix      | `-cloudy` by default (`CONFIG_LOCALVERSION`) to avoid stock conflicts |
| Architecture       | x86_64 (amd64) & arm64 (aarch64)                                      |
| Package Formats    | Debian/Ubuntu `.deb`, generic Fedora/EL `.rpm`, generic Alpine `.apk`, Arch Linux `.pkg.tar.zst` (x86_64 only) |
| Build Frequency    | Daily automatic builds + manual trigger support                        |
| Release Signing    | Native OpenPGP RPM signatures, native RSA APK signatures, detached OpenPGP Arch package signatures, and a signed SHA-256 manifest for every release asset |

## 📥 Installation Guide

### One-click Installation Script

Use the one-click installer to install the latest kernel within a selected series or an exact full version:

```bash
# Download the installation script
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

# Set the full OpenPGP fingerprint obtained through a trusted channel
export CLOUD_KERNEL_GPG_FINGERPRINT="<FULL_OPENPGP_FINGERPRINT>"

# Interactive installation (recommended for new users)
./install-kernel.sh

# Automatically install the latest kernel from the default 7.1 series
./install-kernel.sh install

# Install the latest kernel from the 6.18 series with an English interface
./install-kernel.sh -l en install --series 6.18

# Install an exact version without rebooting (the series is inferred when omitted)
./install-kernel.sh install --version 6.12.21 --no-reboot
```

Script parameters:
- Global options
  - `-l, --language`: Set language (zh/en), defaults to Chinese
- Commands
  - `install`: Directly install the latest kernel in the selected series; defaults to 7.1
  - `help`: Display help information
- Install command options
  - `-s, --series, --kernel-series`: Select a kernel series (`6.12`, `6.18`, or `7.1`)
  - `-v, --version`: Specify a full kernel version; the series is inferred when omitted
  - `-a, --no-reboot`: Skip reboot after installation
  - `--signing-fingerprint`: Set the trusted full OpenPGP fingerprint; `CLOUD_KERNEL_GPG_FINGERPRINT` is also supported

### Pre-built Packages

x86_64 releases contain four package formats; arm64 releases contain DEB, RPM, and APK packages. The generic RPM is built once on Rocky Linux 9 and validated unchanged on Fedora 43/44 and Enterprise Linux 9/10. The generic APK is built once on Alpine 3.21 and validated unchanged on Alpine 3.21-3.24. Arch Linux packages are built and validated with the official `archlinux:base-devel` environment. RPMs carry native OpenPGP signatures, APKs use one persistent Alpine RSA key, each Arch package has a detached `.sig` from the release OpenPGP key, and `SHA256SUMS.asc` covers every release asset. The installer verifies signatures and checksums before invoking a package manager.

| System | Package | Supported releases |
|---|---|---|
| Debian / Ubuntu | `.deb` | Debian 11+, Ubuntu 20.04+ |
| Fedora / Enterprise Linux | generic `.rpm` | Fedora 43/44, EL 9/10 |
| Alpine Linux | generic `.apk` | Alpine 3.21/3.22/3.23/3.24 |
| Arch Linux | `.pkg.tar.zst` | Official Arch Linux x86_64 rolling release |

Download the packages for the current architecture from [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases), then install them:

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb

# Fedora / Enterprise Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux (install Bash before using the one-click installer)
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk

# Arch Linux (x86_64 only; fully upgrade the system first)
sudo pacman -Syu
sudo pacman -U ./linux-cloud-bbrv3-[0-9]*.pkg.tar.zst ./linux-cloud-bbrv3-headers-*.pkg.tar.zst
```

Before manual installation, verify `SHA256SUMS.asc` with `cloud-kernel-signing.asc`, then verify the downloaded files. RPM signatures can additionally be checked with `rpmkeys --checksig`; APK installs use the stable `cloud-kernel-bbrv3.rsa.pub` key published in the release; every Arch Linux `.pkg.tar.zst` must verify against its detached `.sig`. The one-click installer performs these checks automatically.

> [!NOTE]
> This VPS-oriented configuration intentionally disables USB/HID. Arch Linux's default `mkinitcpio` `keyboard` hook may report a missing `usbhid` module; the initramfs is still generated, but this kernel is unsuitable for machines that need a USB keyboard for disk-unlock input or local recovery.

RPM, APK, and Arch Linux packages do not currently support Secure Boot. Keep the distribution kernel installed as a recovery option. The Arch installer does not run an unsafe partial `pacman -Sy` upgrade; run `sudo pacman -Syu` first when the system is not fully current.

### Verify Installation

After reboot:

```bash
uname -r                                # Should show the suffixed version, e.g. 7.1.6-cloudy
sysctl net.ipv4.tcp_congestion_control  # Should be bbr (BBRv3, built in and default)
sysctl net.core.default_qdisc           # Should be fq
```

BBRv3 is built in and enabled by default, so no extra configuration is needed. The other algorithms ship as modules and can be loaded on demand:

```bash
sudo modprobe tcp_bbr1 tcp_bbrplus tcp_brutal
sysctl net.ipv4.tcp_available_congestion_control  # Should then include bbr bbr1 bbrplus brutal
```

## 🔧 Custom Build Instructions

To build manually using GitHub Actions:
1. Go to Repository **Actions** tab
2. Select the **Build Cloud Kernel Packages** workflow
3. Click **Run workflow**
4. Enter a full kernel version (e.g. `6.18.15`) and select the target architecture
5. Optional: adjust the **Kernel suffix** input to customize the suffix (defaults to `cloudy`; leave empty to build without one)
6. The workflow compiles one generic RPM set, one generic APK set, and one Arch Linux package set on x86_64; compatibility validation reuses those exact artifacts instead of rebuilding the kernel per distribution

### Release signing configuration

Repository administrators must create a protected GitHub Environment named `release-signing`, restrict it to `main`/release tags, and preferably enable Required reviewers and Prevent self-review. Configure:

- Environment secret `PACKAGE_SIGNING_GPG_PRIVATE_KEY_B64`: Base64-encoded OpenPGP CI signing subkey
- Optional Environment secret `PACKAGE_SIGNING_GPG_PASSPHRASE`: signing-subkey passphrase
- Environment secret `APK_SIGNING_PRIVATE_KEY_B64`: Base64-encoded Alpine RSA private key
- Environment variable `PACKAGE_SIGNING_GPG_FINGERPRINT`: full OpenPGP primary-key fingerprint

Keep the OpenPGP primary key offline and export only a revocable, expiring signing subkey to CI. Alpine uses a separate RSA key. A `main` build fails rather than publishing ephemeral or unsigned artifacts when persistent keys are unavailable; non-`main` test builds may still use an ephemeral APK key.

## 🤝 Contributing

We welcome contributions through:
- Issue reporting
- Pull requests
- Feature requests
- Documentation improvements

Please follow [GitHub Contribution Guidelines](https://github.com/github/docs/blob/main/CONTRIBUTING.md).

## 💖 Acknowledgements

Inspired by the following projects:
- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)

## ⚠️ Disclaimer

This project only provides kernel build services and does not assume any responsibility. Using the kernel built by this project, please bear the risks yourself.

## 📜 License

This project is licensed under [Unlicense](https://unlicense.org/).
