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

## 📦 Project overview

Maintained kernel series:

| Series | Track          | x86_64 | arm64 | Auto-update |
| --------| :--------------:| :------:| :-----:| :-----------:|
| `6.12` | LTS            | ✅      | ✅     | ✅           |
| `6.18` | LTS            | ✅      | ✅     | ✅           |
| `7.1`  | Current stable | ✅      | ✅     | ✅           |

Supported systems:

| System                          | Version         | Package format | x86_64 | arm64 | Validation / support                  |
| ---------------------------------| -----------------| :--------------:| :------:| :-----:| ---------------------------------------|
| Debian                          | 11+             | `.deb`         | ✅      | ✅     | ✅ Stable                              |
| Ubuntu                          | 20.04+          | `.deb`         | ✅      | ✅     | ✅ Stable                              |
| Fedora Linux                    | 43 / 44         | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (CI-tested)            |
| Red Hat Enterprise Linux (RHEL) | 9 / 10          | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (compatibility target) |
| Rocky Linux                     | 9 / 10          | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (CI-tested)            |
| AlmaLinux                       | 9 / 10          | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (compatibility target) |
| CentOS Stream                   | 9 / 10          | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (compatibility target) |
| Oracle Linux                    | 9 / 10          | `.rpm`         | ✅      | ✅     | ⚠️ Experimental (compatibility target) |
| Alpine Linux                    | 3.21-3.24       | `.apk`         | ✅      | ✅     | ⚠️ Experimental (CI-tested)            |
| Arch Linux                      | Rolling release | `.pkg.tar.zst` | ✅      | —     | ⚠️ Experimental (CI-tested)            |

RPM packages are available for Fedora, Red Hat Enterprise Linux, Rocky Linux, AlmaLinux, CentOS Stream, and Oracle Linux. CI runs installation and removal checks on Fedora and Rocky Linux; the other RPM distributions are experimental compatibility targets.

The installer selects `7.1` by default, but you can choose any maintained series. Each day, `check-upstream.yml` checks every series for a newer Debian upstream release and triggers a build only when that version has not yet been published for the target architecture.

> [!IMPORTANT]
> **Kernel suffix change**: recent releases carry a `-cloudy` suffix by default (`CONFIG_LOCALVERSION="-cloudy"`).
> As a result, `uname -r` reports a version such as `7.1.6-cloudy`, with files installed under `/boot/vmlinuz-<version>-cloudy` and `/lib/modules/<version>-cloudy/`.
> The suffix prevents file conflicts with a distribution kernel of the same version and keeps the stock kernel available as a fallback boot entry.
> Older releases without the suffix are unaffected. If you installed one previously, both kernels will remain after an upgrade; remove the old package only after confirming that the new kernel boots correctly.

This repository builds every package format from the same patched, fully configured kernel source tree:
- Uses official Linux kernel source for the 6.12, 6.18, and 7.1 series from [kernel.org](https://www.kernel.org/)
- Applies patches maintained by the Debian kernel team from [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/)
- **BBR congestion control options**
  - **BBRv3**: Google's next-generation congestion control algorithm, sourced from [xanmod/linux-patches](https://gitlab.com/xanmod/linux-patches), built in, and enabled by default
  - **BBRv1**: the original algorithm remains available as `bbr1`
  - **BBRPlus**: the dog250 and cx9208 variant, adapted from [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable)
- Includes **TCP Brutal** for multiplexed workloads, sourced from [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal)
- Uses the upstream **EEVDF** fair scheduler without third-party scheduler patches
- Builds for x86_64 and arm64, with daily upstream update checks
- Publishes distribution-native packages for Debian/Ubuntu, the Fedora/RHEL ecosystem, Alpine Linux, and Arch Linux, with major installation paths validated in containers

## 🚀 Key features

| Component | Details |
| --- | --- |
| Kernel base | 6.12 / 6.18 / 7.1 series with Debian kernel team patches |
| Networking | BBRv3 built in and enabled by default; BBRPlus, BBRv1, and Brutal as modules; `sch_fq` as the default qdisc |
| CPU scheduler | Upstream EEVDF fair scheduler |
| Memory policy | THP in `madvise` mode; autogroup and automatic NUMA balancing disabled |
| CPU capacity (x86) | `NR_CPUS=512`, with `MAXSMP` disabled for VPS-scale systems |
| Hardening | `LIST_HARDENED` retained; x86 CPU vulnerability mitigations disabled by project policy |
| ZRAM | LZO and ZSTD compression support |
| Driver footprint | Unused NIC vendor drivers removed to reduce kernel size |
| Kernel suffix | `-cloudy` by default through `CONFIG_LOCALVERSION`, avoiding conflicts with distribution kernels |
| Architectures | x86_64 (amd64) and arm64 (aarch64) |
| Package formats | Debian/Ubuntu `.deb`, Fedora/RHEL ecosystem `.rpm`, Alpine Linux `.apk`, and Arch Linux `.pkg.tar.zst` (x86_64 only) |
| Build schedule | Daily automated builds with manual runs available |
| Release signing | Native OpenPGP RPM signatures, native RSA APK signatures, detached OpenPGP Arch package signatures, and a signed SHA-256 manifest covering every release asset |

## 📥 Installation

### Installer script

The installer can install the latest kernel from a selected series or an exact version:

```bash
# Download the installation script
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

# Optional: pin the project's current full OpenPGP primary-key fingerprint (recommended)
export CLOUD_KERNEL_GPG_FINGERPRINT="AFD6BDBFEBB9105077C4CA41399953F30E337E5E"

# Interactive installation (recommended for new users)
./install-kernel.sh

# Automatically install the latest kernel from the default 7.1 series
./install-kernel.sh install

# Install the latest kernel from the 6.18 series with an English interface
./install-kernel.sh -l en install --series 6.18

# Install an exact version without rebooting (the series is inferred when omitted)
./install-kernel.sh install --version 6.12.21 --no-reboot

# If GitHub API access fails because of a shared-IP rate limit (HTTP 403),
# network policy, or a 10-second timeout, the installer races seven verified
# mirrors and automatically uses the fastest successful node.
./install-kernel.sh install --series 6.18

# Optionally add a trusted self-hosted mirror to the race.
export CLOUD_KERNEL_GITHUB_MIRROR="https://<your-trusted-github-proxy>"
./install-kernel.sh install --series 6.18
```

Options and commands:
- Global options
  - `-l, --language`: Set language (zh/en), defaults to Chinese
- Commands
  - `install`: Directly install the latest kernel in the selected series; defaults to 7.1
  - `help`: Display help information
- `install` options
  - `-s, --series, --kernel-series`: Select a kernel series (`6.12`, `6.18`, or `7.1`)
  - `-v, --version`: Specify a full kernel version; the series is inferred when omitted
  - `-a, --no-reboot`: Skip reboot after installation
  - `--signing-fingerprint`: Optional trusted full OpenPGP fingerprint; `CLOUD_KERNEL_GPG_FINGERPRINT` is also supported
  - `--github-mirror URL`: Add an HTTPS GitHub mirror proxy to the automatic race; `CLOUD_KERNEL_GITHUB_MIRROR` is also supported

The project's current OpenPGP primary-key fingerprint is:

```text
AFD6BDBFEBB9105077C4CA41399953F30E337E5E
```

If no fingerprint is set, the installer still verifies the release manifest, checksums, and package signatures, but it cannot pin the public key's identity. Verify the fingerprint through a trusted channel and set it to protect against simultaneous replacement of the release key and release artifacts.

> [!NOTE]
> The installer requests the official GitHub API by default. On failure, it automatically falls back to GitHub mirrors collected from the internet.

> [!WARNING]
> When a mirror is used, the installer forcibly verifies GPG signatures and file checksums. Files that fail verification are not installed.

On Alpine Linux, the installer detects and updates every supported bootloader configuration that is present. Extlinux uses `/etc/update-extlinux.conf` with `update-extlinux`, or updates an existing `/boot/extlinux.conf` or `/boot/syslinux/syslinux.cfg` directly when the source configuration is absent. GRUB BIOS and GRUB UEFI use `grub-mkconfig`; the installer parses the generated `cloud-bbrv3` menu-entry ID and writes it to `GRUB_DEFAULT` in `/etc/default/grub`. If no supported configuration is found, the new kernel is missing from the generated menu, or validation fails, the packages remain installed but automatic reboot is disabled. Limine, rEFInd, direct EFI Stub, provider-managed boot, and containers that share the host kernel still require manual handling.

### Prebuilt packages

x86_64 releases include DEB, RPM, APK, and Arch Linux packages; arm64 releases include DEB, RPM, and APK packages. RPMs target Fedora, RHEL, Rocky Linux, AlmaLinux, CentOS Stream, and Oracle Linux. APKs target Alpine Linux, while Arch Linux packages are built in the official `archlinux:base-devel` environment. RPMs carry native OpenPGP signatures, APKs use a persistent Alpine RSA key, and each Arch Linux package has a detached `.sig` from the release OpenPGP key. A signed `SHA256SUMS.asc` manifest covers every release asset, and the installer verifies all signatures and checksums before invoking the package manager.

Download the packages for your architecture from [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases), then install them:

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb

# Fedora / RHEL / Rocky Linux / AlmaLinux / CentOS Stream / Oracle Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux (install Bash before using the one-click installer)
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk

# Arch Linux (x86_64 only; fully upgrade the system first)
sudo pacman -Syu
sudo pacman -U ./linux-cloud-bbrv3-[0-9]*.pkg.tar.zst ./linux-cloud-bbrv3-headers-*.pkg.tar.zst
```

For a manual installation, first use `cloud-kernel-signing.asc` to verify `SHA256SUMS.asc`, then check every downloaded file against the manifest. You can also verify RPM signatures with `rpmkeys --checksig`; APK installs use the fixed-name `cloud-kernel-bbrv3.rsa.pub` key included in the release; and every Arch Linux `.pkg.tar.zst` must verify against its detached `.sig`. The installer performs all of these checks automatically.

> [!NOTE]
> This VPS-oriented configuration intentionally disables USB/HID. Arch Linux's default `mkinitcpio` `keyboard` hook may report a missing `usbhid` module. The initramfs is still generated, but this kernel is unsuitable for systems that require a USB keyboard to unlock encrypted disks or perform local recovery.

RPM, APK, and Arch Linux packages do not currently support Secure Boot. Keep the distribution kernel installed as a fallback. The installer never runs the unsafe partial-upgrade command `pacman -Sy`; if the system is not fully updated, run `sudo pacman -Syu` first.

### Verify the installation

After reboot:

```bash
uname -r                                # Should show the suffixed version, e.g. 7.1.6-cloudy
sysctl net.ipv4.tcp_congestion_control  # Should be bbr (BBRv3, built in and default)
sysctl net.core.default_qdisc           # Should be fq
```

BBRv3 is built into the kernel and enabled by default, so no extra configuration is required. The other algorithms are provided as modules and can be loaded when needed:

```bash
sudo modprobe tcp_bbr1 tcp_bbrplus tcp_brutal
sysctl net.ipv4.tcp_available_congestion_control  # Should then include bbr bbr1 bbrplus brutal
```

## 🔧 Custom builds

To start a build manually in GitHub Actions:
1. Open the repository's **Actions** tab
2. Select the **Build Cloud Kernel Packages** workflow
3. Click **Run workflow**
4. Enter a full kernel version, such as `6.18.15`, and select the target architecture
5. Optionally change the **Kernel suffix** input (default: `cloudy`; leave it empty to build without a suffix)
6. The workflow builds DEB, RPM, and APK packages, plus Arch Linux packages on x86_64. Compatibility checks reuse these artifacts rather than recompiling the kernel for each distribution.

### Release signing

Repository administrators should create a protected GitHub Environment named `release-signing`, restrict it to `main` and release tags, and enable Required reviewers and Prevent self-review where appropriate. Configure:

- Environment secret `PACKAGE_SIGNING_GPG_PRIVATE_KEY_B64`: Base64-encoded OpenPGP CI signing subkey
- Optional Environment secret `PACKAGE_SIGNING_GPG_PASSPHRASE`: signing-subkey passphrase
- Environment secret `APK_SIGNING_PRIVATE_KEY_B64`: Base64-encoded Alpine RSA private key
- Environment variable `PACKAGE_SIGNING_GPG_FINGERPRINT`: full OpenPGP primary-key fingerprint

Keep the OpenPGP primary key offline and export only a revocable, expiring signing subkey to CI. Alpine packages use a separate RSA key. If the persistent keys are unavailable, `main` builds fail instead of publishing unsigned or temporarily signed artifacts; non-`main` test builds may still use an ephemeral APK key.

## 🤝 Contributing

Contributions are welcome:
- Bug reports
- Pull requests
- Feature requests
- Documentation improvements

Please follow [GitHub Contribution Guidelines](https://github.com/github/docs/blob/main/CONTRIBUTING.md).

## 💖 Acknowledgements

This project draws inspiration from:
- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)

## ⚠️ Disclaimer

This project provides kernel build artifacts as-is, without warranty. You are responsible for evaluating the risks and keeping a known-good fallback kernel.

## 📜 License

This project is licensed under the [Unlicense](https://unlicense.org/).
