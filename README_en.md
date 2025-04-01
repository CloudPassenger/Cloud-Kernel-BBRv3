# Cloud Kernel BBRv3

English | [简体中文](README_zh.md)

| Debian Custom Kernel with BBR3 and ECHO Scheduler

Current Kernel Version: 6.12 (Mainline)

[![CI for x86_64](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions)
[![CI for arm64](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build-arm64.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions)

## 📦 Project Overview

This repository provides automated daily builds of Debian kernel packages with enhanced networking and scheduling features:
- Integrated **BBRv3 congestion control** from Xanmod patches
- **ECHO-CPU-Scheduler** for improved task scheduling
- Multi-architecture support (x86_64 & arm64)
- Daily automatic builds tracking latest security patches

## 🚀 Key Features

| Component          | Details                                                                 |
|--------------------|-------------------------------------------------------------------------|
| Kernel Base        | Latest stable Debian kernel (v6.12 series)                             |
| Network Optimize   | BBRv3 congestion control algorithm                                    |
| CPU Scheduler      | ECHO low-latency scheduler                                             |
| Architecture       | x86_64 (amd64) & arm64 (aarch64)                                      |
| Build Frequency    | Daily automatic builds + manual trigger support                        |

## 📥 Installation Guide

### Pre-built Packages

1. Download the latest build from [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases)
   ```bash
   wget https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases/download/<version>/linux-{image,headers}-<version>_<arch>.deb
   ```

2. Install packages:
   ```bash
   sudo dpkg -i linux-*.deb
   ```

3. Update bootloader:
   ```bash
   sudo update-grub && sudo reboot
   ```

### Verify Installation
After reboot:
```bash
uname -r  # Should show installed kernel version
cat /sys/kernel/debug/sched_features  # Verify ECHO scheduler features
sysctl net.ipv4.tcp_congestion_control  # Should display 'bbr'
```

## 🔧 Custom Build Instructions

To build manually using GitHub Actions:
1. Go to Repository **Actions** tab
2. Select **Build Debian Kernel** workflow
3. Click **Run workflow**
4. Select architecture and force rebuild options

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