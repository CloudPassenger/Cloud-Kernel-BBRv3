# AmneziaWG 内核模块集成

简体中文 | [English](README_en.md)

本目录负责将固定版本的 [AmneziaWG Linux 内核模块](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) 作为 in-tree 模块集成到 Cloud Kernel BBRv3 的共享内核构建和全部软件包中。

> [!NOTE]
> 内核软件包只包含 `amneziawg` 内核模块。创建和管理接口仍需单独安装兼容的 `awg`、`awg-quick` 用户态工具。

## 版本锁

[`source.env`](source.env) 是唯一版本锁，记录上游仓库、Tag、完整 Commit SHA 和模块版本。其他脚本和文档不复制这些值，避免升级后出现多份不一致的版本信息。

构建过程同时校验 Tag 对应的完整 Commit SHA 和上游 `version.h`，避免可移动 Tag 或元数据不一致破坏可复现性。

## 集成内容

- [`integrate.sh`](integrate.sh) 下载固定源码并导入 `drivers/net/amneziawg/`。
- [`Kconfig`](Kconfig) 将 `CONFIG_AMNEZIAWG=m` 接入内核配置系统。
- 集成脚本更新内核 `drivers/net/Kconfig` 和 `drivers/net/Makefile`，使模块参与正常的 in-tree 构建。
- 上游用于外置构建的 `tests/` 目录和构建残留不会写入准备后的内核源码树。
- [`manifest.sh`](manifest.sh) 返回声明式 JSON，供通用构建流程检查源码来源、配置要求、模块名称、版本、vermagic 和软件包路径。
- DEB、RPM、APK 和 Arch 软件包都从同一次共享内核编译中安装该模块。

## 内核系列兼容性

| 内核系列 | x86_64 | arm64 | 项目兼容处理 |
| --- | --- | --- | --- |
| `6.12` | 支持 | 支持 | 无系列专用补丁 |
| `6.18` | 支持 | 支持 | 无系列专用补丁 |
| `7.1` | 支持 | 支持 | `CONFIG_IPV6=y`；适配 UDP tunnel socket API |

补丁按作用范围存放：

```text
patches/
├── common/             # 应用于全部内核系列
└── <kernel-series>/    # 只应用于指定内核系列
```

当前 Linux 7.1 兼容补丁位于：

```text
patches/7.1/0001-compat-linux-7.1-udp-tunnel-sock-api.patch
```

Linux 7.1 将 `setup_udp_tunnel_sock()` 和 `udp_tunnel_sock_release()` 的参数从 `struct socket` 改为 `struct sock`。项目补丁在 7.1 及更高版本中传入 `socket->sk`，同时为较早内核保留原调用方式。

所有补丁均使用零 fuzz 模式应用。补丁上下文漂移时，源码准备或更新检查会直接失败。

## 更新上游版本

在仓库根目录运行：

```bash
bash external/amneziawg/update.sh v<version>
```

更新脚本会：

1. 从上游指定 Tag 克隆源码。
2. 解析并校验完整 Commit SHA。
3. 从上游 `src/version.h` 解析模块版本。
4. 确认 Tag 与模块版本一致。
5. 按内核系列依次验证 `patches/common/` 和 `patches/<series>/` 补丁栈，禁止 fuzz。
6. 更新 `source.env` 中的 Tag、Commit 和版本。

更新后必须重新验证 Linux 6.12、6.18、7.1 的 x86_64 和 arm64 构建矩阵，并确认四种软件包仍包含 manifest 声明的模块路径。若上游已合并某项兼容修复，应删除或重制对应补丁，而不是保留可被反向应用或依赖 fuzz 的旧补丁。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `source.env` | 固定上游仓库、Tag、Commit 和模块版本 |
| `Kconfig` | 定义 in-tree `CONFIG_AMNEZIAWG` 配置 |
| `integrate.sh` | 下载、校验、导入源码并接入内核构建系统 |
| `manifest.sh` | 返回通用构建流程消费的声明式模块信息 |
| `update.sh` | 更新源码锁并验证各内核系列补丁栈 |
| `patches/common/` | 全系列共享兼容补丁 |
| `patches/<series>/` | 指定内核系列兼容补丁 |
