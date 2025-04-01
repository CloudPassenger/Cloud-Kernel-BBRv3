# Cloud Kernel BBRv3

简体中文 | [English](README_en.md)

| 集成 BBR3 和 ECHO 调度器的 Debian 定制内核

当前内核版本: 6.12 (Mainline)

[![CI for x86_64](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions)
[![CI for arm64](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions/workflows/build-arm64.yml/badge.svg)](https://github.com/CloudPassenger/Cloud-Kernel-BBRv3/actions)

## 📦 项目概述

本仓库提供集成增强功能的 Debian 内核自动构建：
- 来自 Xanmod 的 **BBRv3 拥塞控制算法**
- **ECHO-CPU-Scheduler** 低延迟任务调度器
- 多架构支持 (x86_64 & arm64)
- 每日自动构建跟踪最新安全更新

## 🚀 核心特性

| 组件               | 详细信息                                                               |
|--------------------|-----------------------------------------------------------------------|
| 内核基础           | 最新稳定版 Debian 内核 (v6.12 系列)                                  |
| 网络优化           | BBRv3 拥塞控制算法                                                   |
| CPU 调度器         | ECHO 低延迟调度器                                                     |
| 支持架构           | x86_64 (amd64) 和 arm64 (aarch64)                                   |
| 构建频率           | 每日自动构建 + 支持手动触发                                           |

## 📥 安装指南

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
cat /sys/kernel/debug/sched_features  # 验证 ECHO 调度器特性
sysctl net.ipv4.tcp_congestion_control  # 应显示 'bbr'
```

## 🔧 自定义构建说明

通过 GitHub Actions 手动构建：
1. 进入仓库 **Actions** 标签页
2. 选择 **Build Debian Kernel** 工作流
3. 点击 **Run workflow**
4. 选择架构和强制重建选项

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


