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

本仓库提供集成增强功能的 Debian 内核自动构建：
- 使用 Linux Kernel 官方源码（6.12 / 6.18 / 7.1 系列，来自 [kernel.org](https://www.kernel.org/)）
- 集成 Debian 内核团队维护的补丁 (来自 [kernel-team/linux](https://salsa.debian.org/kernel-team/linux/))
- **BBR 拥塞控制算法更新!**
  - 更新来自 Google 的 **BBRv3 拥塞控制算法** (来自 [xanmod/linux-patches](https://gitlab.com/xanmod/linux-patches))
  - 保留原版 BBRv1 算法 （拥塞控制算法设置为 `bbr1` 使用）
  - 集成来自 dog250 & cx9208 的魔改 **BBRPlus** 拥塞控制算法 (修改自 [UJX6N/bbrplus-6.x_stable](https://github.com/UJX6N/bbrplus-6.x_stable))
- 内置 **TCP Brutal** 多路复用拥塞控制算法 (来自 [apernet/tcp-brutal](https://github.com/apernet/tcp-brutal))
- 使用上游 **EEVDF** 公平调度器，默认启用且不引入第三方 Scheduler 补丁
- 多架构支持 (x86_64 & arm64)，每日自动构建跟踪更新

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
| 支持架构           | x86_64 (amd64) 和 arm64 (aarch64)                                      |
| 构建频率           | 每日自动构建 + 支持手动触发                                              |

## 📥 安装指南

### 一键安装脚本

使用我们提供的一键安装脚本，可以按内核系列安装最新版本或指定的完整版本：

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/CloudPassenger/Cloud-Kernel-BBRv3/main/install-kernel.sh
chmod +x install-kernel.sh

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

### 预构建软件包

1. 从 [发布页面](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases) 下载最新构建包
   ```bash
   wget https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/releases/download/<版本>/linux-{image,headers}-<版本>_<架构>.deb
   ```

2. 安装软件包：
   ```bash
   sudo dpkg -i linux-*.deb
   ```

3. 更新启动引导：
   ```bash
   sudo update-grub && sudo reboot
   ```

### 验证安装
重启后执行：
```bash
uname -r   # 应显示安装的内核版本
modinfo tcp_bbr1 tcp_bbrplus tcp_brutal  # 确认模块已安装
sudo modprobe tcp_bbr1 tcp_bbrplus tcp_brutal  # 加载模块后再查看可用算法
sysctl net.ipv4.tcp_available_congestion_control  # 应包含 bbr、bbr1、bbrplus、brutal
```

## 🔧 自定义构建说明

通过 GitHub Actions 手动构建：
1. 进入仓库 **Actions** 标签页
2. 选择 **Build Debian Kernel** 工作流
3. 点击 **Run workflow**
4. 输入完整的内核版本（如 `6.18.15`），选择目标架构

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
