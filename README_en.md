# Cloud Kernel BBRv3

<!-- README-I18N:START -->

**English** | [简体中文](./README.md)

<!-- README-I18N:END -->

[![Build](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml)
[![Kernel Updates](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml)

> Multi-series Debian Cloud-configured kernel builds for multiple cloud Linux distributions. BBRv3 with `sch_fq` is the default, x86_64 and arm64 are supported, and Debian upstream kernel updates are tracked automatically.

## Maintained Kernel Series

| Series | Track | x86_64 | arm64 | Automatic updates |
|---|---|---:|---:|---:|
| `6.12` | LTS | Yes | Yes | Yes |
| `6.18` | LTS | Yes | Yes | Yes |
| `7.1` | Active stable | Yes | Yes | Yes |

`check-upstream.yml` checks the latest Debian `debian/<version>-1` tag for every series each day. It triggers the unified `build.yml` workflow only when the corresponding architecture-specific release tag does not exist. The installer defaults to `7.1`, while every maintained series can be selected explicitly.

## Overview

Each build combines the kernel sources in this order:

1. Download the requested official Linux source from [kernel.org](https://www.kernel.org/).
2. Apply the complete matching Debian patch series from [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/).
3. Apply [XanMod network patches](https://gitlab.com/xanmod/linux-patches), with an automatic fallback for series moved into its EOL directory.
4. Apply this repository's custom network patches from `kernel_patches/<series>/net/`.
5. Merge Debian's cloud configuration with `custom_configs/<series>/<arch>.config` through `.github/scripts/apply_config.sh`.
6. Feed the same patched, resolved source tree into independent adapters for Debian/Ubuntu `.deb`, Fedora 43/44 and Enterprise Linux 9/10 `.rpm`, and Alpine Linux 3.24 `.apk` packages.

The CPU scheduler is upstream Linux **EEVDF**. No third-party scheduler patch is applied, and `sched_ext` is disabled in the default configuration.

## Networking and Congestion Control

| Algorithm/component | Build mode | Default state | Intended use |
|---|---|---|---|
| BBRv3 (`bbr`) | built-in (`y`) | Default TCP congestion control | General VPS/server traffic |
| BBRv1 (`bbr1`) | module (`m`) | Loaded on demand | Comparison testing and compatibility |
| TCP Brutal (`brutal`) | module (`m`) | Loaded on demand | Specialized applications with an explicit target rate |
| BBRPlus | Patch retained, disabled in default configs | Not built | Enable in a custom fragment when required |
| `sch_fq` | built-in (`y`) | Default qdisc | Consumes TCP EDT pacing directly for BBR/BBRv3 |

The default configuration is:

```text
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_BBR1=m
CONFIG_TCP_CONG_BRUTAL=m
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_FQ=y
CONFIG_DEFAULT_NET_SCH="fq"
```

For forwarding or shaping workloads such as routers, NAT gateways, VPN appliances, or software shapers, the relevant interfaces can be switched to `fq_codel` at runtime. `fq_pie` is not an EDT-pacing-equivalent replacement for `sch_fq`.

## VPS Configuration Policy

The current fragments target resource-constrained general-purpose VPS guests, not very large bare-metal systems or untrusted multi-tenant hosts:

- THP defaults to `madvise`, avoiding the unpredictable memory cost of `always` on mixed workloads.
- `SCHED_AUTOGROUP`, automatic NUMA balancing by default, and `DEBUG_LIST` are disabled; `LIST_HARDENED=y` remains enabled.
- `HZ_250`, PSI, full cgroup v2 support, and multiple ZRAM compression algorithms remain available.
- x86 uses `MAXSMP=n`, `NR_CPUS=512`, and `NODES_SHIFT=6`. Systems above 512 CPUs require a separate `MAXSMP=y` kernel flavour.
- CPU vulnerability mitigations are compiled out on x86 by project policy and cannot be re-enabled at runtime.
- The upstream arm64 `CPU_MITIGATIONS` default remains enabled. Use the `mitigations=off` kernel command-line option when the deployment policy requires disabling it.
- `VIRTIO_RTC=m` is enabled for 6.18/7.1; arm64 includes `pvpanic`, and 7.1 arm64 retains the configuration required by pKVM protected guests.

> [!WARNING]
> The x86 build is not intended for untrusted multi-tenant workloads. The 512-CPU ceiling is also a hard compatibility boundary. Large cloud instances and shared hosts should use a separate compatibility/security flavour.

## Installation

The installer supports Debian 11+, Ubuntu 20.04+, Fedora 43/44, Enterprise Linux 9/10, Alpine Linux 3.24, amd64, and arm64. Automatic installation reboots by default; pass `--no-reboot` to skip it.

```bash
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

./install-kernel.sh
./install-kernel.sh install
./install-kernel.sh -l en install --series 6.18
./install-kernel.sh install --version 6.12.21 --no-reboot
```

Main options:

- `-l, --language`: select the `zh` or `en` interface.
- `-s, --series, --kernel-series`: select `6.12`, `6.18`, or `7.1`.
- `-v, --version`: install an exact `x.y.z` version; the series is inferred when omitted.
- `-a, --no-reboot`: skip the automatic reboot.

Release tag convention:

- amd64: `<version>`, for example `7.1.6`
- arm64: `<version>-arm64`, for example `7.1.6-arm64`

You can also download packages matching the distribution and architecture from [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases) and install them manually:

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb
sudo update-grub

# Fedora / Enterprise Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk
```

> [!CAUTION]
> `CONFIG_LOCALVERSION=""` is intentionally retained for now, so `uname -r` remains the bare version, such as `7.1.6`. Keep the distribution kernel as a fallback; real-VM boot validation is still required for each RPM/APK target. Secure Boot is not currently supported.

## Verify the Installation

```bash
uname -r
sysctl net.ipv4.tcp_congestion_control
tc qdisc show

modinfo tcp_bbr1 tcp_brutal
sudo modprobe tcp_bbr1 tcp_brutal
sysctl net.ipv4.tcp_available_congestion_control
```

The default output should show `bbr` and `fq`. After loading the modules, the available congestion-control list should also contain `bbr1` and `brutal`. TCP Brutal is intended for applications that explicitly configure its parameters and is not recommended as a general system default.

## Manual Builds

1. Open the repository's **Actions** page.
2. Select **Build Cloud Kernel Packages**.
3. Click **Run workflow**.
4. Enter a complete `kernel_version`, such as `6.18.15`.
5. Select `x86_64` or `arm64`.

The workflow selects `kernel_patches/<series>/` and `custom_configs/<series>/`, creates one shared prepared source tree, then builds `.deb`, Fedora/EL-specific `.rpm`, and Alpine `.apk` packages before creating the architecture-specific GitHub Release.

When `diagnostic_build` is enabled, the DEB lane, every Fedora/EL RPM target, and the Alpine APK lane use verbose build output and upload separate diagnostic artifacts retained for seven days. On failure, the workflow log also prints matched errors and the final 500 lines.

When run manually from a branch other than `main`, the workflow still uploads the prepared source, DEB, RPM, APK, and diagnostic artifacts, but skips the `create-release` job and creates no Git tag or GitHub Release. Only `main` branch builds perform a formal release.

## Repository Layout

| Path | Purpose |
|---|---|
| `.github/workflows/build.yml` | Unified x86_64/arm64 build and release entry point |
| `.github/workflows/check-upstream.yml` | Daily Debian upstream checks for 6.12/6.18/7.1 |
| `.github/scripts/apply_config.sh` | Merges Debian cloud configs by series and architecture |
| `.github/scripts/prepare_kernel_source.sh` | Creates the patched and configured source shared by all package formats |
| `.github/scripts/build_{rpm,apk}.sh` | Builds RPM/APK packages inside target-distribution containers |
| `packaging/{rpm,apk}/` | Fedora/EL spec and Alpine APKBUILD adapters |
| `kernel_patches/<series>/net/` | Custom network patches maintained per kernel series |
| `custom_configs/<series>/<arch>.config` | Minimal configuration overrides per series and architecture |
| `xanmod_patch_fixes/<series>/` | Compatibility fixes applied to the XanMod patch checkout |
| `install-kernel.sh` | Bilingual interactive/automatic installer |

To add a new series, create both `kernel_patches/<series>/` and `custom_configs/<series>/`, then update the series matrix in `check-upstream.yml` and the installer's supported-series list.

## Contributing

Bug reports, compatibility fixes, configuration improvements, and documentation updates are welcome. New kernel-series changes should be verified on both x86_64 and arm64, and the custom patch stack must apply successfully through `quilt push -a` in its defined order.

## Acknowledgements

- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)
- [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable)
- [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal)

## Disclaimer

This project provides automated kernel builds and installation tooling. A custom kernel can affect bootability, security boundaries, driver compatibility, and network behavior. Keep a known-good kernel and a recovery path available before deployment, and use the project at your own risk.

## License

This project is licensed under the [Unlicense](https://unlicense.org/).

Last reviewed: 2026-08-07
