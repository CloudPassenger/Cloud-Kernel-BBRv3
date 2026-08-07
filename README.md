# Cloud Kernel BBRv3

<!-- README-I18N:START -->

[English](./README_en.md) | **简体中文**

<!-- README-I18N:END -->

[![Build](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml)
[![Kernel Updates](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml)

> 面向多种云端 Linux 发行版的多版本 Debian Cloud 配置内核构建项目。默认使用 BBRv3 + `sch_fq`，支持 x86_64 与 arm64，并自动跟踪 Debian 上游内核更新。

## 维护的内核系列

| 系列 | 定位 | x86_64 | arm64 | 自动更新 |
|---|---|---:|---:|---:|
| `6.12` | LTS | 是 | 是 | 是 |
| `6.18` | LTS | 是 | 是 | 是 |
| `7.1` | Active stable | 是 | 是 | 是 |

`check-upstream.yml` 每天检查各系列最新的 Debian `debian/<version>-1` tag。只有对应架构的 release tag 尚不存在时，才会触发统一的 `build.yml` 工作流。安装脚本默认选择 `7.1`，也可以明确指定任一维护系列。

## 项目概述

每次构建按以下顺序组合内核来源：

1. 从 [kernel.org](https://www.kernel.org/) 下载指定版本的官方 Linux 源码。
2. 应用 Debian [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/) 对应版本的完整补丁集。
3. 应用 [XanMod network patches](https://gitlab.com/xanmod/linux-patches)；已进入 EOL 目录的系列会自动回退查找。
4. 应用本仓库 `kernel_patches/<series>/net/` 中的自定义网络补丁。
5. 通过 `.github/scripts/apply_config.sh` 合并 Debian cloud 配置与 `custom_configs/<series>/<arch>.config`。
6. 将同一份已打补丁、已解析配置的源码交给独立 adapter，生成 Debian/Ubuntu `.deb`、Fedora 43/44 与 Enterprise Linux 9/10 `.rpm`，以及 Alpine Linux 3.24 `.apk`。

CPU 调度器为 Linux 上游 **EEVDF**。本项目不引入第三方 scheduler patch，并在默认配置中关闭 `sched_ext`。

## 网络与拥塞控制

| 算法/组件 | 构建方式 | 默认状态 | 用途 |
|---|---|---|---|
| BBRv3 (`bbr`) | built-in (`y`) | 默认 TCP 拥塞控制 | 通用 VPS/server 流量 |
| BBRv1 (`bbr1`) | module (`m`) | 按需加载 | 对比测试与兼容性 |
| TCP Brutal (`brutal`) | module (`m`) | 按需加载 | 明确配置目标速率的专用应用 |
| BBRPlus | 补丁保留，默认配置未启用 | 不构建 | 需要时可在自定义 fragment 中启用 |
| `sch_fq` | built-in (`y`) | 默认 qdisc | 直接消费 TCP EDT pacing，配合 BBR/BBRv3 |

默认配置为：

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

对于 router、NAT、VPN 或 software shaper 等转发/整形场景，可以在运行时将相关接口改为 `fq_codel`。`fq_pie` 不是 `sch_fq` 的 EDT pacing 等价替代品。

## VPS 配置策略

当前 fragment 面向资源受限的通用 VPS，而不是超大规模裸金属或不可信多租户宿主机：

- THP 默认使用 `madvise`，避免 `always` 在混合负载上的不可控内存开销。
- 关闭 `SCHED_AUTOGROUP`、自动 NUMA balancing 默认启用项和 `DEBUG_LIST`，保留 `LIST_HARDENED=y`。
- 使用 `HZ_250`、PSI、完整 cgroup v2 和 ZRAM 多压缩算法支持。
- x86 使用 `MAXSMP=n`、`NR_CPUS=512`、`NODES_SHIFT=6`；超过 512 CPU 的机器需要独立的 `MAXSMP=y` kernel flavour。
- x86 按项目策略在编译时关闭 CPU vulnerability mitigations，运行时无法重新启用。
- arm64 的 `CPU_MITIGATIONS` 仍由上游 Kconfig 保持启用；需要关闭时使用 kernel command line `mitigations=off`。
- 6.18/7.1 启用 `VIRTIO_RTC=m`；arm64 提供 `pvpanic`，7.1 arm64 还保留 pKVM protected guest 所需配置。

> [!WARNING]
> x86 构建不适合运行不可信多租户 workload。512 CPU 上限也是硬兼容边界；面向大型云实例或共享宿主机时，应维护单独的兼容性/安全 flavour。

## 安装

安装脚本支持 Debian 11+、Ubuntu 20.04+、Fedora 43/44、Enterprise Linux 9/10、Alpine Linux 3.24，以及 amd64/arm64。自动安装模式默认在完成后重启；使用 `--no-reboot` 可以跳过。

```bash
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

./install-kernel.sh
./install-kernel.sh install
./install-kernel.sh -l en install --series 6.18
./install-kernel.sh install --version 6.12.21 --no-reboot
```

主要参数：

- `-l, --language`：界面语言，支持 `zh` / `en`。
- `-s, --series, --kernel-series`：选择 `6.12`、`6.18` 或 `7.1`。
- `-v, --version`：安装指定的完整 `x.y.z` 版本；未指定系列时自动推断。
- `-a, --no-reboot`：安装后不自动重启。

Release tag 约定：

- amd64：`<version>`，例如 `7.1.6`
- arm64：`<version>-arm64`，例如 `7.1.6-arm64`

也可以从 [Releases](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases) 下载匹配发行版与架构的软件包后手动安装：

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
> 当前按要求保留 `CONFIG_LOCALVERSION=""`，因此 `uname -r` 仍是裸版本号（例如 `7.1.6`）。请保留发行版原有内核作为回退；RPM/APK 的真实 VM 启动验证仍需按目标发行版完成。Secure Boot 当前不受支持。

## 验证安装

```bash
uname -r
sysctl net.ipv4.tcp_congestion_control
tc qdisc show

modinfo tcp_bbr1 tcp_brutal
sudo modprobe tcp_bbr1 tcp_brutal
sysctl net.ipv4.tcp_available_congestion_control
```

默认应看到 `bbr` 与 `fq`。加载模块后，可用算法列表还应包含 `bbr1` 和 `brutal`。TCP Brutal 面向显式配置其参数的应用，不建议直接设为通用系统默认值。

## 手动构建

1. 打开仓库的 **Actions** 页面。
2. 选择 **Build Cloud Kernel Packages**。
3. 点击 **Run workflow**。
4. 输入完整的 `kernel_version`，例如 `6.18.15`。
5. 选择 `x86_64` 或 `arm64`。

工作流会根据版本号选择 `kernel_patches/<series>/` 和 `custom_configs/<series>/`，生成共享 prepared source，随后并行构建 `.deb`、各 Fedora/EL target 的 `.rpm` 与 Alpine `.apk`，并创建对应架构的 GitHub Release。

启用 `diagnostic_build` 后，DEB、每个 Fedora/EL RPM target 和 Alpine APK lane 都会使用详细构建输出，并上传保留 7 天的独立诊断 artifact；失败时 Workflow 日志仍会直接显示关键错误和末尾 500 行。

## 仓库结构

| 路径 | 作用 |
|---|---|
| `.github/workflows/build.yml` | x86_64/arm64 统一构建与发布入口 |
| `.github/workflows/check-upstream.yml` | 每日检查 6.12/6.18/7.1 Debian 上游版本 |
| `.github/scripts/apply_config.sh` | 按系列和架构合并 Debian cloud 配置 |
| `.github/scripts/prepare_kernel_source.sh` | 生成所有包格式共享的补丁与配置源码 |
| `.github/scripts/build_{rpm,apk}.sh` | 在目标发行版容器中构建 RPM/APK |
| `packaging/{rpm,apk}/` | Fedora/EL spec 与 Alpine APKBUILD adapter |
| `kernel_patches/<series>/net/` | 按内核系列维护的自定义网络补丁 |
| `custom_configs/<series>/<arch>.config` | 每个系列/架构的最小配置 override |
| `xanmod_patch_fixes/<series>/` | 针对 XanMod patch checkout 的兼容性修复 |
| `install-kernel.sh` | 双语交互式/自动安装脚本 |

增加新系列时，需要同时添加 `kernel_patches/<series>/`、`custom_configs/<series>/`，并更新 `check-upstream.yml` 的 series matrix 与安装脚本的支持列表。

## 参与贡献

欢迎提交 bug report、兼容性修复、配置改进和文档更新。涉及新内核系列时，请同时验证 x86_64 与 arm64，并确保 custom patch 可以按既定顺序通过 `quilt push -a`。

## 鸣谢

- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)
- [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable)
- [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal)

## 免责声明

本项目提供自动化内核构建与安装工具。自定义内核可能影响启动、安全边界、驱动兼容性与网络行为；部署前请准备可用的旧内核和恢复入口，并自行承担使用风险。

## 许可证

本项目采用 [Unlicense](https://unlicense.org/) 许可证。

最后核对：2026-08-07
