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
- Generic package support: build one RPM set and one APK set, then validate their install/remove lifecycle across distribution matrices

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
| Package Formats    | Debian/Ubuntu `.deb`, generic Fedora/EL `.rpm`, generic Alpine `.apk` |
| Build Frequency    | Daily automatic builds + manual trigger support                        |

## 📥 Installation Guide

### One-click Installation Script

Use the one-click installer to install the latest kernel within a selected series or an exact full version:

```bash
# Download the installation script
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

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

### Pre-built Packages

Every architecture-specific release contains three package formats. The generic RPM is built once on Rocky Linux 9 and validated unchanged on Fedora 43/44 and Enterprise Linux 9/10. The generic APK is built once on Alpine 3.21 and validated unchanged on Alpine 3.21-3.24.

| System | Package | Supported releases |
|---|---|---|
| Debian / Ubuntu | `.deb` | Debian 11+, Ubuntu 20.04+ |
| Fedora / Enterprise Linux | generic `.rpm` | Fedora 43/44, EL 9/10 |
| Alpine Linux | generic `.apk` | Alpine 3.21/3.22/3.23/3.24 |

Download the packages for the current architecture from [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases), then install them:

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb

# Fedora / Enterprise Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux (install Bash before using the one-click installer)
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk
```

RPM and APK packages do not currently support Secure Boot. Keep the distribution kernel installed as a recovery option.

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
6. The workflow compiles one generic RPM set and one generic APK set; compatibility matrices reuse those exact artifacts instead of rebuilding the kernel per distribution

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
