<div align="center">

<img src="Cloudy%20Kernel.png" alt="Cloud Kernel BBRv3" width="100%">

# Cloud Kernel BBRv3

**集成 BBRv3 / BBRPlus / Brutal，基于 Debian Cloud 内核配置，专为 VPS 健壮运行优化的定制内核**

[![CI](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml)
[![Upstream Check](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/check-upstream.yml)
[![License](https://img.shields.io/badge/license-Unlicense-blue.svg)](https://unlicense.org/)

![Kernel Series](https://img.shields.io/badge/kernel-6.12%20%7C%206.18%20%7C%207.1-blue)
![BBRv3](https://img.shields.io/badge/BBR-v3-brightgreen)
![BBRPlus](https://img.shields.io/badge/BBR-Plus-orange)
![TCP Brutal](https://img.shields.io/badge/TCP-Brutal-red)
![EEVDF](https://img.shields.io/badge/scheduler-EEVDF-blueviolet)
![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-yellow)

简体中文 | [English](README_en.md)

</div>

## 📦 项目概述

维护的内核系列：

| 系列　 | 定位 | x86_64 | arm64 | 自动更新 |
| --------| :----:| :------:| :-----:| :--------:|
| `6.12` | LTS　| ✅      | ✅     | ✅　　　　|
| `6.18` | LTS　| ✅      | ✅     | ✅　　　　|
| `7.1`　| 主线 | ✅      | ✅     | ✅　　　　|

支持的系统：

| 系统　　　　　　　　　　　　　　| 版本　　　| 软件包格式　　 | x86_64 | arm64 | 测试 / 支持状态　　　　 |
| ---------------------------------| -----------| :--------------:| :------:| :-----:| -------------------------|
| Debian　　　　　　　　　　　　　| 11+　　　 | `.deb`　　　　 | ✅      | ✅     | ✅ 稳定　　　　　　　　　|
| Ubuntu　　　　　　　　　　　　　| 20.04+　　| `.deb`　　　　 | ✅      | ✅     | ✅ 稳定　　　　　　　　　|
| Fedora Linux　　　　　　　　　　| 43 / 44　 | `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（CI 安装测试） |
| Red Hat Enterprise Linux (RHEL) | 9 / 10　　| `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（兼容性目标）　|
| Rocky Linux　　　　　　　　　　 | 9 / 10　　| `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（CI 安装测试） |
| AlmaLinux　　　　　　　　　　　 | 9 / 10　　| `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（兼容性目标）　|
| CentOS Stream　　　　　　　　　 | 9 / 10　　| `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（兼容性目标）　|
| Oracle Linux　　　　　　　　　　| 9 / 10　　| `.rpm`　　　　 | ✅      | ✅     | ⚠️ 实验性（兼容性目标）　|
| Alpine Linux　　　　　　　　　　| 3.21-3.24 | `.apk`　　　　 | ✅      | ✅     | ⚠️ 实验性（CI 安装测试） |
| Arch Linux　　　　　　　　　　　| 滚动更新　| `.pkg.tar.zst` | ✅      | —     | ⚠️ 实验性（CI 安装测试） |

RPM 软件包面向主流的 DNF/RPM 生态，覆盖 Fedora、Red Hat Enterprise Linux、Rocky Linux、AlmaLinux、CentOS Stream 与 Oracle Linux。CI 以 Fedora 和 Rocky Linux 作为代表环境执行安装/卸载测试；其余 RPM 发行版按兼容性目标提供实验性支持。

安装脚本默认选择 `7.1` 系列，也可指定任一受维护系列。`check-upstream.yml` 每日检查各系列是否有新的 Debian 上游版本，仅当对应架构尚未发布该版本时才触发构建。

> [!IMPORTANT]
> **内核后缀变更提醒**：自最近一次发布起，本项目的内核默认带 `-cloudy` 后缀（`CONFIG_LOCALVERSION="-cloudy"`）。
> 因此 `uname -r` 会显示为 `7.1.6-cloudy` 之类的版本号，安装路径也相应变为 `/boot/vmlinuz-<版本>-cloudy`、`/lib/modules/<版本>-cloudy/`。
> 这样设计是为了避免与发行版自带的同版本号内核产生文件冲突或相互覆盖，同时保留官方内核作为回退启动项。
> 早期未带后缀的旧版本不受影响；若之前安装过无后缀版本，升级后新旧内核会共存，确认新内核可正常启动后，可自行移除旧包。

本仓库基于同一份打过补丁、完成配置解析的源码，自动构建多种格式的内核软件包：
- 采用 Linux 内核官方源码（6.12 / 6.18 / 7.1 系列，来自 [kernel.org](https://www.kernel.org/)）
- 集成 Debian 内核团队维护的补丁（来自 [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/)）
- **BBR 拥塞控制算法增强**
  - **BBRv3**：Google 的新一代拥塞控制算法（来自 [xanmod/linux-patches](https://gitlab.com/xanmod/linux-patches)），已内置并设为默认
  - **BBRv1**：保留原版算法，将拥塞控制算法设为 `bbr1` 即可使用
  - **BBRPlus**：dog250 与 cx9208 的魔改版本（修改自 [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable)）
- 内置 **TCP Brutal** 拥塞控制算法，面向多路复用场景（来自 [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal)）
- 采用上游 **EEVDF** 公平调度器，不引入第三方调度器补丁
- 支持多架构（x86_64 与 arm64），每日自动构建并跟踪上游更新
- 支持多发行版：为 Debian/Ubuntu、Fedora/RHEL 生态、Alpine Linux 与 Arch Linux 提供对应格式的软件包，并通过容器验证主要安装路径

## 🚀 核心特性

| 组件 | 详细信息 |
| --- | --- |
| 内核基础 | 6.12 / 6.18 / 7.1 系列，并集成 Debian 团队补丁 |
| 网络优化 | BBRv3（内置并设为默认）/ BBRPlus / BBRv1 / Brutal（模块形式），默认使用 `sch_fq` qdisc |
| CPU 调度器 | 上游 EEVDF 公平调度器 |
| 内存策略 | THP 使用 `madvise` 模式；禁用 autogroup，关闭 NUMA 默认均衡 |
| CPU 规模（x86） | `NR_CPUS=512`，关闭 `MAXSMP`，适配 VPS 规模 |
| 安全加固 | 保留 `LIST_HARDENED`；x86 按项目策略关闭 CPU 漏洞缓解 |
| ZRAM 交换 | 支持多种压缩算法（LZO + ZSTD） |
| 驱动精简 | 裁剪未使用的网卡厂商驱动，减小内核体积 |
| 内核后缀 | 默认 `-cloudy`（通过 `CONFIG_LOCALVERSION` 设置），避免与官方内核冲突 |
| 支持架构 | x86_64（amd64）与 arm64（aarch64） |
| 软件包格式 | Debian/Ubuntu `.deb`、Fedora/RHEL 生态 `.rpm`、Alpine Linux `.apk`、Arch Linux `.pkg.tar.zst`（仅 x86_64） |
| 构建频率 | 每日自动构建，也支持手动触发 |
| 发行签名 | RPM 原生 OpenPGP 签名、APK 原生 RSA 签名、Arch 独立 OpenPGP 签名，以及覆盖全部 Release 产物的签名版 SHA-256 清单 |

## 📥 安装指南

### 一键安装脚本

项目提供一键安装脚本，可按内核系列安装最新版本，也可指定完整版本号精确安装：

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

# 可选：钉扎项目当前的 OpenPGP 主密钥完整指纹（推荐）
export CLOUD_KERNEL_GPG_FINGERPRINT="AFD6BDBFEBB9105077C4CA41399953F30E337E5E"

# 交互式安装（推荐新用户使用）
./install-kernel.sh

# 自动安装默认 7.1 系列的最新内核
./install-kernel.sh install

# 安装 6.18 系列的最新内核，并使用英文界面
./install-kernel.sh -l en install --series 6.18

# 安装指定版本的内核且安装后不重启（未指定系列时会从版本号推断）
./install-kernel.sh install --version 6.12.21 --no-reboot
```

脚本支持的参数：
- 全局参数
  - `-l, --language`：设置语言（zh/en），默认为中文
- 命令
  - `install`：直接安装所选系列的最新内核；未指定系列时默认使用 7.1
  - `help`：显示帮助信息
- `install` 命令参数
  - `-s, --series, --kernel-series`：选择内核系列（`6.12`、`6.18` 或 `7.1`）
  - `-v, --version`：指定完整的内核版本；未指定系列时自动从版本号推断
  - `-a, --no-reboot`：安装后不自动重启
  - `--signing-fingerprint`：可选；指定可信 OpenPGP 完整指纹，也可设置 `CLOUD_KERNEL_GPG_FINGERPRINT`

项目当前默认的 OpenPGP 主密钥完整指纹为：

```text
AFD6BDBFEBB9105077C4CA41399953F30E337E5E
```

若不设置指纹，安装脚本仍会验证 Release manifest、校验和与软件包签名，但不会钉扎公钥身份；建议通过可信渠道核对并设置上述指纹，防止 Release 公钥与发布产物被同时替换。

### 预构建软件包

x86_64 Release 提供 DEB、RPM、APK 和 Arch Linux 软件包，arm64 Release 提供 DEB、RPM 和 APK。RPM 包适用于 Fedora、RHEL、Rocky Linux、AlmaLinux、CentOS Stream 与 Oracle Linux；APK 包适用于 Alpine Linux；Arch Linux 包使用官方 `archlinux:base-devel` 环境构建。RPM 使用 OpenPGP 原生签名，APK 使用固定的 Alpine RSA 密钥签名，Arch Linux 软件包使用同一 OpenPGP 发布密钥生成独立的 `.sig` 签名，所有 Release 产物均附有 `SHA256SUMS.asc` 校验清单。安装脚本在调用包管理器前会验证签名和校验和。

从 [发布页面](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases) 下载当前架构的软件包后安装：

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb

# Fedora / RHEL / Rocky Linux / AlmaLinux / CentOS Stream / Oracle Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux（使用一键安装脚本前需先安装 Bash）
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk

# Arch Linux（仅 x86_64；安装前建议先完整升级系统）
sudo pacman -Syu
sudo pacman -U ./linux-cloud-bbrv3-[0-9]*.pkg.tar.zst ./linux-cloud-bbrv3-headers-*.pkg.tar.zst
```

手动安装前，请先使用 `cloud-kernel-signing.asc` 验证 `SHA256SUMS.asc`，再核对下载的文件。RPM 还可通过 `rpmkeys --checksig` 验证原生签名；APK 安装时会使用 Release 中固定名称的 `cloud-kernel-bbrv3.rsa.pub` 验证原生签名；Arch Linux 的每个 `.pkg.tar.zst` 必须通过对应的 `.sig` 独立签名验证。一键安装脚本会自动完成以上所有步骤。

> [!NOTE]
> 本项目面向 VPS 场景，配置中特意禁用了 USB/HID。Arch Linux 默认 `mkinitcpio` 的 `keyboard` hook 可能提示缺少 `usbhid`；initramfs 仍会生成，但需要 USB 键盘输入磁盘解锁密码或进行本地恢复的机器不应使用此内核。

RPM、APK 与 Arch Linux 软件包当前不支持 Secure Boot；请保留发行版原有内核作为回退启动项。安装脚本不会执行不安全的 `pacman -Sy` 部分升级；如果系统尚未完全更新，请先手动执行 `sudo pacman -Syu`。

### 验证安装

重启后执行：

```bash
uname -r                                # 应显示带后缀的内核版本，如 7.1.6-cloudy
sysctl net.ipv4.tcp_congestion_control  # 应为 bbr（即 BBRv3，已内置并设为默认）
sysctl net.core.default_qdisc           # 应为 fq
```

BBRv3 已内置且默认启用，无需额外配置。其余算法以模块形式提供，按需加载：

```bash
sudo modprobe tcp_bbr1 tcp_bbrplus tcp_brutal
sysctl net.ipv4.tcp_available_congestion_control  # 加载后应包含 bbr bbr1 bbrplus brutal
```

## 🔧 自定义构建说明

通过 GitHub Actions 手动构建：
1. 进入仓库 **Actions** 标签页
2. 选择 **Build Cloud Kernel Packages** 工作流
3. 点击 **Run workflow**
4. 输入完整的内核版本（如 `6.18.15`），选择目标架构
5. 可选：修改 **Kernel suffix** 参数自定义内核后缀（默认 `cloudy`，留空则构建无后缀内核）
6. 工作流会构建 DEB、RPM、APK 软件包，并在 x86_64 上额外构建 Arch Linux 软件包；兼容性验证直接复用同一批产物，不会为各发行版重复编译内核

### 发行签名配置

仓库管理员需创建受保护的 GitHub Environment（环境）`release-signing`，仅限 `main` 分支与发布标签使用，并建议启用 Required reviewers（必需审阅人）与 Prevent self-review（禁止自我审阅）。配置：

- Environment secret `PACKAGE_SIGNING_GPG_PRIVATE_KEY_B64`：Base64 编码的 OpenPGP CI 签名子密钥
- 可选 Environment secret `PACKAGE_SIGNING_GPG_PASSPHRASE`：签名子密钥的密码
- Environment secret `APK_SIGNING_PRIVATE_KEY_B64`：Base64 编码的 Alpine RSA 私钥
- Environment variable `PACKAGE_SIGNING_GPG_FINGERPRINT`：OpenPGP 主密钥完整指纹

OpenPGP 主密钥应离线保管，仅向 CI 导出可撤销、可过期的签名子密钥。Alpine 使用独立的 RSA 密钥。缺少持久私钥时，`main` 分支的工作流会直接失败，而不会发布临时签名或未签名产物；非 `main` 分支的测试构建仍可使用临时 APK 密钥。

## 🤝 参与贡献

欢迎通过以下方式参与贡献：
- 问题报告
- 代码提交
- 功能建议
- 文档改进

请遵循 [GitHub 贡献指南](https://github.com/github/docs/blob/main/CONTRIBUTING.md)。

## 💖 鸣谢

项目灵感源自以下相关项目：
- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)

## ⚠️ 免责声明

本项目仅提供内核构建服务，不对任何使用后果承担责任；使用本项目构建的内核，请自行承担风险。

## 📜 许可证

本项目采用 [Unlicense](https://unlicense.org/) 许可证。
