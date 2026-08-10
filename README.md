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

| 系列 | 定位 | x86_64 | arm64 | 自动更新 |
|---|:---:|:---:|:---:|:---:|
| `6.12` | LTS | ✅ | ✅ | ✅ |
| `6.18` | LTS | ✅ | ✅ | ✅ |
| `7.1` | Active stable | ✅ | ✅ | ✅ |

安装脚本默认选择 `7.1`，也可指定任一维护系列。`check-upstream.yml` 每日检查各系列最新的 Debian 上游版本，仅在对应架构的 release tag 尚不存在时触发构建。

> [!IMPORTANT]
> **内核后缀变更提醒**：自最近一次更新起，本项目发布的内核默认带有 `-cloudy` 后缀（`CONFIG_LOCALVERSION="-cloudy"`）。
> 因此 `uname -r` 将显示为 `7.1.6-cloudy` 这样的形式，安装路径也随之变为 `/boot/vmlinuz-<版本>-cloudy`、`/lib/modules/<版本>-cloudy/`。
> 此变更用于避免与发行版官方同版本号内核发生文件冲突、互相覆盖，同时保证官方内核仍可作为回退启动项保留。
> 早期未带后缀的旧版本不受影响；若你之前安装过无后缀版本，升级后新旧内核会共存，可在确认新内核可正常启动后自行移除旧包。

本仓库提供基于同一份已打补丁、已解析配置源码的多格式内核自动构建：
- 使用 Linux Kernel 官方源码（6.12 / 6.18 / 7.1 系列，来自 [kernel.org](https://www.kernel.org/)）
- 集成 Debian 内核团队维护的补丁 (来自 [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/))
- **BBR 拥塞控制算法更新!**
  - 更新来自 Google 的 **BBRv3 拥塞控制算法** (来自 [xanmod/linux-patches](https://gitlab.com/xanmod/linux-patches))
  - 保留原版 BBRv1 算法 （拥塞控制算法设置为 `bbr1` 使用）
  - 集成来自 dog250 & cx9208 的魔改 **BBRPlus** 拥塞控制算法 (修改自 [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable))
- 内置 **TCP Brutal** 多路复用拥塞控制算法 (来自 [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal))
- 使用上游 **EEVDF** 公平调度器，默认启用且不引入第三方 Scheduler 补丁
- 多架构支持 (x86_64 & arm64)，每日自动构建跟踪更新
- 通用包支持：单次构建 generic RPM 与 generic APK，再通过多发行版容器矩阵验证安装和卸载生命周期

## 🚀 核心特性

| 组件               | 详细信息                                                               |
|--------------------|-----------------------------------------------------------------------|
| 内核基础           | 6.12 / 6.18 / 7.1 系列 + Debian 团队补丁                                |
| 网络优化           | BBRv3（内置默认）/ BBRPlus / BBRv1 / Brutal（模块）+ 默认 `sch_fq` qdisc |
| CPU 调度器         | 上游 EEVDF 公平调度器                                                    |
| 内存策略           | THP `madvise`、关闭 autogroup 与 NUMA 默认均衡                          |
| CPU 规模 (x86)     | `NR_CPUS=512`、关闭 `MAXSMP`，适配 VPS 规模                             |
| 安全加固           | 保留 `LIST_HARDENED`；x86 按策略关闭 CPU 漏洞缓解                       |
| ZRAM 交换          | 多压缩算法支持（LZO + ZSTD）                                            |
| 驱动精简           | 裁剪未用网卡厂商驱动，减小内核体积                                       |
| 内核后缀           | 默认 `-cloudy`（`CONFIG_LOCALVERSION`），避免与官方内核冲突               |
| 支持架构           | x86_64 (amd64) 和 arm64 (aarch64)                                      |
| 软件包格式         | Debian/Ubuntu `.deb`、Fedora/EL generic `.rpm`、Alpine generic `.apk`   |
| 构建频率           | 每日自动构建 + 支持手动触发                                              |
| 发行签名           | RPM 原生 OpenPGP、APK 原生 RSA、全部 Release assets 的签名 SHA-256 清单 |

## 📥 安装指南

### 一键安装脚本

使用我们提供的一键安装脚本，可以按内核系列安装最新版本或指定的完整版本：

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

# 设置从可信渠道获得的完整 OpenPGP 指纹
export CLOUD_KERNEL_GPG_FINGERPRINT="<FULL_OPENPGP_FINGERPRINT>"

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
  - `-l, --language`：设置语言 (zh/en)，默认为中文
- 命令
  - `install`：直接安装所选系列的最新内核；未指定系列时默认使用 7.1
  - `help`：显示帮助信息
- install 命令参数
  - `-s, --series, --kernel-series`：选择内核系列（`6.12`、`6.18` 或 `7.1`）
  - `-v, --version`：指定完整的内核版本；省略系列时会根据版本号自动推断
  - `-a, --no-reboot`：安装后不自动重启
  - `--signing-fingerprint`：指定可信 OpenPGP 完整指纹；也可设置 `CLOUD_KERNEL_GPG_FINGERPRINT`

### 预构建软件包

每个架构的 Release 同时提供三种软件包。generic RPM 由 Rocky Linux 9 构建，并原样验证于 Fedora 43/44 与 Enterprise Linux 9/10；generic APK 由 Alpine 3.21 构建，并原样验证于 Alpine 3.21-3.24。RPM 使用 OpenPGP 原生签名，APK 使用固定 Alpine RSA 密钥签名，所有 Release assets 同时由 `SHA256SUMS.asc` 覆盖。安装脚本在调用包管理器前强制验证签名和校验和。

| 系统 | 软件包 | 支持版本 |
|---|---|---|
| Debian / Ubuntu | `.deb` | Debian 11+、Ubuntu 20.04+ |
| Fedora / Enterprise Linux | generic `.rpm` | Fedora 43/44、EL 9/10 |
| Alpine Linux | generic `.apk` | Alpine 3.21/3.22/3.23/3.24 |

从 [发布页面](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases) 下载当前架构的软件包后安装：

```bash
# Debian / Ubuntu
sudo dpkg -i linux-image-*.deb linux-headers-*.deb

# Fedora / Enterprise Linux
sudo dnf install ./kernel-cloud-bbrv3-[0-9]*.rpm ./kernel-cloud-bbrv3-devel-*.rpm

# Alpine Linux（先安装 Bash 才能运行一键安装脚本）
sudo cp ./*.rsa.pub /etc/apk/keys/
sudo apk add ./linux-cloud-bbrv3-[0-9]*.apk ./linux-cloud-bbrv3-dev-*.apk
```

手动安装前应先使用 `cloud-kernel-signing.asc` 验证 `SHA256SUMS.asc`，再校验所下载文件。RPM 还可通过 `rpmkeys --checksig` 验证原生签名；APK 安装时会使用 Release 中固定名称的 `cloud-kernel-bbrv3.rsa.pub` 验证原生签名。一键安装脚本会自动执行这些步骤。

RPM 与 APK 当前不支持 Secure Boot；请保留发行版原有内核作为回退启动项。

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
6. 工作流只编译一套 generic RPM 和一套 generic APK；兼容性矩阵复用同一产物，不会为每个发行版重复编译内核

### 发行签名配置

仓库管理员需要创建受保护的 GitHub Environment `release-signing`，只允许 `main`/发行标签，并建议启用 Required reviewers 和 Prevent self-review。配置：

- Environment secret `PACKAGE_SIGNING_GPG_PRIVATE_KEY_B64`：Base64 编码的 OpenPGP CI signing subkey
- 可选 Environment secret `PACKAGE_SIGNING_GPG_PASSPHRASE`：signing subkey 密码
- Environment secret `APK_SIGNING_PRIVATE_KEY_B64`：Base64 编码的 Alpine RSA 私钥
- Environment variable `PACKAGE_SIGNING_GPG_FINGERPRINT`：OpenPGP 主密钥完整指纹

OpenPGP 主密钥应离线保存，只向 CI 导出可撤销、可过期的 signing subkey。Alpine 使用独立 RSA 密钥。`main` 上缺少持久私钥时工作流会失败，不会发布临时签名或未签名产物；非 `main` 测试构建仍可使用临时 APK 密钥。

## 🤝 参与贡献

欢迎通过以下方式参与贡献：
- 问题报告
- 代码提交
- 功能建议
- 文档改进

请遵循 [GitHub 贡献指南](https://github.com/github/docs/blob/main/CONTRIBUTING.md)。

## 💖 鸣谢

灵感来自以下相关项目
- [Zxilly/bbr-v3-pkg](https://github.com/Zxilly/bbr-v3-pkg)
- [byJoey/Actions-bbr-v3](https://github.com/byJoey/Actions-bbr-v3)
- [Naochen2799/Latest-Kernel-BBR3](https://github.com/Naochen2799/Latest-Kernel-BBR3)

## ⚠️ 免责声明

本项目仅提供内核构建服务，不承担任何责任。使用本项目构建的内核，请自行承担风险。

## 📜 许可证

本项目采用 [Unlicense](https://unlicense.org/) 许可证。
