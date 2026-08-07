# Debian Cloud 内核自定义配置优化调研

调研日期：2026-08-06

## 结论摘要

Debian 的 `cloud-amd64` / `cloud-arm64` 配置已经完成了大部分高收益裁剪：禁用 USB、音频、无线、蓝牙、媒体、DRM、FireWire、传统文件系统和大量物理平台驱动，同时保留 Virtio、Xen、Hyper-V、VMware、NVMe、云厂商虚拟网卡及容器基础设施。因此，继续批量删除物理驱动的边际收益较小，且主要减少 `.deb` / `/lib/modules` 体积，不会明显降低稳态 RAM 或 CPU，因为未加载的模块不驻留内存。

当前更值得优先处理的是：

1. 让 BBR 默认搭配 `sch_fq`，避免退回每个 TCP socket 一个高精度定时器的软件 pacing。
2. 修正当前 fragment 中若干“反优化”项：`IDPF_SINGLEQ`、legacy fbcon acceleration、vDPA simulator、Xen backend/eventfd、部分 host-side VFIO/target 功能。
3. 将 VMware、MSR、CPUID 等非启动关键功能恢复为 module，而不是强制 built-in。
4. 将通用 VPS 的 THP 默认策略从 `always` 改为 `madvise`，并关闭面向桌面负载的 scheduler autogroup。
5. 保留安全加固，但移除明确位于 hot path 的调试 instrumentation；特别是 `DEBUG_LIST` 可由 `LIST_HARDENED` 替代。
6. x86 按项目策略保持 compile-time CPU vulnerability mitigations 关闭；arm64 的通用 `CPU_MITIGATIONS` 是不可交互的 `def_bool y`，如需同等策略必须使用运行时 `mitigations=off`。
7. 6.18/7.1 增加 `VIRTIO_RTC=m`；arm64 可补齐 QEMU `pvpanic`，改善虚拟时钟与 panic 上报兼容性。

## 调研范围与依据

- 当前配置：`custom_configs/{6.12,6.18,7.1}/{x86_64,arm64}.config`
- Debian 官方 cloud 配置：
  - [Debian 6.12.101 `config.cloud`](https://salsa.debian.org/kernel-team/linux/-/raw/debian/6.12.101-1/debian/config/config.cloud)
  - [Debian 6.18.15 `config.cloud`](https://salsa.debian.org/kernel-team/linux/-/raw/debian/6.18.15-1/debian/config/config.cloud)
  - [Debian 7.1.6 `config.cloud`](https://salsa.debian.org/kernel-team/linux/-/raw/debian/7.1.6-1/debian/config/config.cloud)
  - [Debian 7.1.6 amd64 cloud overlay](https://salsa.debian.org/kernel-team/linux/-/raw/debian/7.1.6-1/debian/config/amd64/config.cloud-amd64)
  - [Debian 7.1.6 arm64 cloud overlay](https://salsa.debian.org/kernel-team/linux/-/raw/debian/7.1.6-1/debian/config/arm64/config.cloud-arm64)
- Linux upstream Kconfig、源代码与文档；本文所有性能收益均按源码语义分类，没有虚构百分比。
- 本地验证：分别使用 Linux 6.12.101、6.18.34、7.1.6 Kconfig，将对应 Debian cloud 层与六个最终 fragment 合并后运行 `olddefconfig`；所有非补丁自定义符号均按预期解析。该验证只证明 Kconfig 合法，不等同于完整 kernel build 或性能 benchmark。

## 当前配置的关键发现

### 已经做得正确的部分

- Debian cloud flavour 已经大范围裁掉物理桌面/笔记本子系统，不应重新维护第二套大规模 denylist。
- Virtio balloon/mem/pmem、memory hotplug、page reporting、Xen balloon、Hyper-V balloon、vsock、主流云 NIC 等基础能力由 Debian 层提供。
- `CONFIG_VMGENID=y` 由 Debian/上游默认保留，可在 VM clone、rollback、snapshot 后重新注入 RNG entropy。上游明确推荐 built-in：[`drivers/virt/Kconfig`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/virt/Kconfig?h=v6.18.34)。
- `CONFIG_HZ_250`、tickless idle、dynamic/lazy preemption、PSI 和完整 cgroup v2 能力适合作为通用 VPS 基线，不应为微基准盲目改成 `HZ_1000`、`NO_HZ_FULL` 或关闭 PSI。

### Final decision: x86 `MAXSMP` and `NR_CPUS`

#### Verified facts

- Upstream x86 Kconfig makes this a production **two-way choice**, not a freely selectable 512–8192 range. `MAXSMP=y` selects `CPUMASK_OFFSTACK`, forces `NR_CPUS=8192`, and defaults `NODES_SHIFT=10` (up to 1024 NUMA nodes). With `MAXSMP=n` and a normal production debug policy, `CPUMASK_OFFSTACK` has no visible prompt because its prompt is conditional on `DEBUG_PER_CPU_MAPS=y`; therefore the x86 `NR_CPUS` range ends at 512. A fragment that requests `MAXSMP=n`, `CPUMASK_OFFSTACK=y`, and `NR_CPUS=1024/2048` does not create a supported middle point: Kconfig drops the hidden user request and resolves the ceiling to 512. Sources: [Linux 6.18 x86 Kconfig: `MAXSMP`/`NR_CPUS`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/x86/Kconfig?h=v6.18.34), [Linux 6.18 x86 Kconfig: `NODES_SHIFT`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/x86/Kconfig?h=v6.18.34), and [`CPUMASK_OFFSTACK` Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/lib/Kconfig?h=v6.18.34).
- Enabling `DEBUG_PER_CPU_MAPS` merely to expose the `CPUMASK_OFFSTACK` prompt is not a production workaround. Upstream says it “adds a fair amount of code to kernel memory and decreases performance” and says to disable it when unsure. Source: [`DEBUG_PER_CPU_MAPS` Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/lib/Kconfig.debug?h=v6.18.34).
- Upstream's sizing guidance is approximately 8 KB of kernel image for every supported CPU. Current official x86 instance specifications establish these public-cloud ceilings as of the research date:

| Provider | Largest documented offering | Maximum logical CPUs |
|---|---|---:|
| AWS EC2 | `u7inh-32tb.480xlarge` | 1,920 vCPUs |
| Microsoft Azure | `Standard_M832s_12_v3` / `Standard_M832is_16_v3` | 832 vCPUs |
| Google Compute Engine | `x4-1920-32t-metal` | 1,920 vCPUs |

Sources: [AWS EC2 memory-optimized instance specifications](https://docs.aws.amazon.com/ec2/latest/instancetypes/mo.html#mo_hardware), [Azure Msv3 High Memory sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/memory-optimized/msv3-hm-series), and [Google Compute Engine X4 machine types](https://cloud.google.com/compute/docs/memory-optimized-machines#x4_machine_types). The GCP X4 entry is bare metal; AWS independently establishes the same 1,920-thread ceiling for an EC2 instance.

#### Decision and sizing inference

For this project's **single, memory-conscious small-VPS/server flavour**, use **`MAXSMP=n` and `NR_CPUS=512`**. Do not retain a 1024/2048 recommendation: it is not realizable under the upstream production Kconfig policy without either `MAXSMP` or an inappropriate debug option.

- Applying upstream's approximate 8-KB-per-CPU guidance, the image-cost budget falls from about 64 MB at 8192 CPUs to about 4 MB at 512 CPUs, an estimated reduction of about 60 MB. This is an **inference from Kconfig guidance**, not a measured artifact delta, and it is an image/static-memory saving rather than a throughput optimization.
- This choice deliberately excludes oversized current offerings: AWS `u7i-12tb.224xlarge` and related U7i/U7in sizes expose 896 vCPUs, AWS `u7inh-32tb.480xlarge` exposes 1,920, Azure Msv3 HM exposes 832, and GCP X4 exposes 960–1,920. The kernel cannot boot or hotplug CPUs beyond its compiled ceiling.
- Disabling `MAXSMP` also stops forcing the 1024-node NUMA maximum; x86-64 defaults to `NODES_SHIFT=6` (64 NUMA nodes) unless separately configured.

For a genuinely **broad public-cloud or ultra-large bare-metal flavour**, retain **`MAXSMP=y` and `NR_CPUS=8192`**. Upstream offers no production-safe 1024/2048 compromise in these kernel versions. Supporting both goals requires two kernel flavours or an upstream-quality Kconfig change, neither of which belongs in this single small-VPS profile.

**Confidence: high** for the Kconfig resolution and current provider limits. **Risk:** the 512 choice is a hard compatibility cutoff, so image documentation must not claim universal AWS/Azure/GCP coverage; future growth below 512 is harmless, but any target above 512 requires the separate `MAXSMP` flavour before deployment.

### 7.1 stale crypto symbols 已完成迁移

对照 upstream 7.1.6 Kconfig，旧 fragment 中以下架构专用 crypto symbols 已删除：

- x86_64：`CONFIG_CRYPTO_POLYVAL_CLMUL_NI`、`CONFIG_CRYPTO_SM3_AVX_X86_64`
- arm64：`CONFIG_CRYPTO_SM3_NEON`、`CONFIG_CRYPTO_SM3_ARM64_CE`、`CONFIG_CRYPTO_AES_ARM64`

7.1 改为 `CONFIG_CRYPTO_SM3=m`。该符号选择 `CRYPTO_LIB_SM3`，而 `CRYPTO_LIB_SM3_ARCH` 在 x86_64 与 arm64 自动默认启用；POLYVAL/GHASH 的架构加速由 `CRYPTO_LIB_GF128HASH_ARCH` 自动选择。arm64 AES 的现行 `CRYPTO_AES_ARM64_CE_BLK=m` 与 `CRYPTO_AES_ARM64_BS=m` 已由 Debian 配置提供，无需增加替代 override。六个最终 config 的 `olddefconfig` 验证确认旧符号消失且新 SM3 符号生效。来源：[7.1 generic crypto Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/crypto/Kconfig?h=v7.1.6)、[7.1 crypto library Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/lib/crypto/Kconfig?h=v7.1.6)、[7.1 x86 crypto Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/x86/crypto/Kconfig?h=v7.1.6)、[7.1 arm64 crypto Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/arm64/crypto/Kconfig?h=v7.1.6)。

### 当前 fragment 中值得回退或删除的项目

| 项目 | 发现 | 建议 |
|---|---|---|
| `CONFIG_IDPF_SINGLEQ=y` | 上游说明其仅用于需要 legacy single queue 的硬件，并明确指出会增加 driver size 和 hot-path runtime checks。来源：[6.12 IDPF Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/net/ethernet/intel/idpf/Kconfig?h=v6.12.101)。 | 默认设为 `n`；只有确认云平台暴露需要 singleq 的 IDPF VF 时再开启。 |
| `CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION=y` | 上游明确称现代 x86-64/发行版通常不使用 legacy fbdev driver，建议禁用。来源：[6.12 fbcon Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/video/console/Kconfig?h=v6.12.101)。 | x86_64 设为 `n`。保留 `SYSFB_SIMPLEFB` 和现代虚拟 framebuffer console。 |
| `CONFIG_VDPA_SIM=m` | 上游定义为 testing、prototyping、development simulator。来源：[6.12 vDPA Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/vdpa/Kconfig?h=v6.12.101)。 | 生产 guest profile 设为 `n`。 |
| `CONFIG_VP_VDPA=m` | 将 virtio PCI device bridge 到 vDPA bus，偏 host/DPU dataplane，不是普通 guest 使用 virtio-net/blk 所必需。 | 普通 VPS 设为 `n`；仅 vDPA/VDUSE host profile 开启。 |
| `CONFIG_XEN_PRIVCMD_EVENTFD=y` | `XEN_PRIVCMD` 面向 Dom0、driver domain 或 privileged userspace；eventfd 用于 userspace virtio backend 加速 guest interrupt。来源：[6.12 Xen Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/xen/Kconfig?h=v6.12.101)。 | 普通 Xen guest 设为 `n`；保留 Xen frontend、balloon、grant 等 guest 功能。 |
| `CONFIG_VIRTIO_VFIO_PCI=m` | 用于 Virtio NET/BLOCK PCI VF 的 VFIO migration，依赖 SR-IOV PF extension、IOMMU dirty tracking 和 IOMMUFD；普通 guest 无收益。来源：[6.18 Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/vfio/pci/virtio/Kconfig?h=v6.18.34)。 | 仅 nested virtualization / VFIO live migration host profile 开启。 |
| `CONFIG_REMOTE_TARGET=m` | TCM virtual remote target 用于 cluster peer 的 TPG/ACL/LUN 配置，不是普通云磁盘 initiator。来源：[6.18 Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/target/tcm_remote/Kconfig?h=v6.18.34)。 | 普通 VPS 设为 `n`。 |
| `CONFIG_DM_MULTIPATH_HST/IOA=m` | 是特定 dm-multipath path selector；只有实际使用对应 selector 才有价值。 | 移到 storage profile；通用 VPS 不主动开启。 |
| `CONFIG_VMWARE_VMCI=y` | Debian 基线为 module；VMCI 只在 VMware guest 中使用。来源：[VMCI Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/misc/vmw_vmci/Kconfig?h=v6.18.34)。 | 恢复 `m`，保留 VMware compatibility，避免所有 x86 guest 常驻。 |
| `CONFIG_PTP_1588_CLOCK_VMW=y` | 只在 VMware VM 有用，Kconfig 支持 module；并且明确 `depends on X86`。来源：[PTP Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/ptp/Kconfig?h=v6.18.34)。 | x86_64 改为 `m`；arm64 删除该无效配置。 |
| `CONFIG_X86_MSR/CPUID=y` | Debian 基线为 module；一般诊断工具并不要求其在早期启动阶段 built-in。 | 恢复 `m`，除非 initramfs/early userspace 有明确依赖。 |
| `CONFIG_NXP_CBTX_PHY=m`、`CONFIG_HW_RANDOM_CCTRNG=m`（arm64） | 分别是物理 PHY 和 Arm CryptoCell TRNG，不是通用虚拟 guest device。 | 普通 arm64 cloud profile 设为 `n`。 |
| `CONFIG_SCHED_CLASS_EXT=y` | 只在实际加载 BPF sched_ext scheduler 时提供价值；项目默认 scheduler 是 upstream EEVDF。6.18 Debian 基线已开启时，fragment 中重复设置也没有意义。 | 不使用 sched_ext 时可禁用以减小代码/状态；至少删除 6.18/7.1 的冗余 override。需要先 benchmark 和确认运维工具依赖。 |

## 分级优化建议

### P0：建议作为通用 cloud 默认值

#### 1. Final qdisc decision for BBR/BBRv3

#### Verified pacing behavior

`sch_fq` is the only one of the three qdiscs that implements TCP EDT pacing at the qdisc layer. It copies `skb->tstamp` into its per-packet `time_to_send`, places future packets/flows on time-ordered red-black trees, and arms a qdisc watchdog for the next eligible departure. Its Kconfig and `tc-fq(8)` documentation explicitly describe locally generated TCP pacing, `sk_pacing_rate`, EDT, and `SO_MAX_PACING_RATE`. Sources: [Linux `sch_fq.c`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/sched/sch_fq.c?h=v6.18.34), [scheduler Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/sched/Kconfig?h=v6.18.34), and [`tc-fq(8)`](https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/plain/man/man8/tc-fq.8).

`fq_pie` **does not honor TCP EDT or `SO_MAX_PACING_RATE` equivalently to `sch_fq`**. Its dequeue path is work-conserving DRR and contains no EDT-based delayed-flow tree or watchdog. The timestamp used by Linux FQ-PIE by default is a PIE queue-sojourn timestamp stored for AQM delay estimation; it is not the `skb->tstamp` earliest-departure timestamp. `fq_codel` likewise timestamps enqueue time for CoDel but does not schedule departures from EDT. Sources: [Linux `sch_fq_pie.c`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/sched/sch_fq_pie.c?h=v6.18.34), [`tc-fq_pie(8)`](https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/plain/man/man8/tc-fq_pie.8), [Linux `sch_fq_codel.c`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/sched/sch_fq_codel.c?h=v6.18.34), and [`tc-fq_codel(8)`](https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/plain/man/man8/tc-fq_codel.8).

Both upstream BBR and Google's BBRv3 source carry the same explicit note: use the `fq` qdisc with pacing enabled; otherwise TCP falls back to internal pacing with one high-resolution timer per TCP socket and may consume more resources. Thus `fq_codel` and `fq_pie` do not break BBR's rate selection or `SO_MAX_PACING_RATE` cap, but enforcement occurs through TCP's per-socket fallback rather than equivalent qdisc EDT handling. Sources: [upstream BBR](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/ipv4/tcp_bbr.c?h=v6.18.34), [Google BBRv3 `tcp_bbr.c`](https://github.com/google/bbr/blob/v3/net/ipv4/tcp_bbr.c), and the algorithm-owner paper [“BBR: Congestion-Based Congestion Control”](https://research.google/pubs/bbr-congestion-based-congestion-control/).

#### Latency, fairness, AQM, and implementation cost

| Property | `sch_fq` | `fq_codel` | `fq_pie` |
|---|---|---|---|
| Primary control | Per-socket/per-flow fair scheduling plus non-work-conserving EDT pacing. | Stochastic 5-tuple flow queues plus CoDel on each queue. | Stochastic 5-tuple flow queues plus PIE on each queue. |
| Queue-delay control | Not a general AQM. It has hard limits and an optional fixed CE threshold, but no adaptive delay controller. Low host-side delay comes mainly from pacing, flow isolation, and priority bands. | AQM detects persistent minimum sojourn delay; Linux defaults are 5 ms target, 100 ms interval, and ECN enabled. It favors sparse/new flows and protects interactive traffic from bulk-flow head-of-line blocking. | AQM randomly drops/marks on enqueue from current and previous queue-delay error; Linux defaults are 15 ms target/update and ECN disabled. It controls average delay rather than CoDel's persistent minimum delay. |
| Fairness and traffic origin | Fast path keys locally generated traffic by `skb->sk`, so all packets from one socket are one flow. Forwarded/orphan traffic falls back to packet hash and is capped by the orphan mask; the source explicitly says it is meant mostly for local traffic. | Hash-based classification does not require a local socket, so it is suitable for local and forwarded/router traffic, subject to hash collisions. | Same forwarding-friendly stochastic flow classification and collision tradeoff as FQ-CoDel. |
| Fixed scheduler state | 1024 red-black-tree roots by default; per-flow objects are allocated dynamically for active/recent socket flows and garbage-collected. | 1024 fixed flow records by default; upstream documents less than 64 bytes per queue on 64-bit systems, plus Linux's separate backlog array. | 1024 fixed flow records with per-flow PIE controller state. A periodic timer scans up to 2048 slots per callback; at the default 1024 flows it updates all slots every 15 ms after startup. |
| Packet-path CPU implications | Socket-pointer classification, EDT ordering, and one qdisc watchdog; for BBR it avoids the documented per-socket hrtimer fallback. | Hashing, per-packet enqueue timestamping, and CoDel work on dequeue; BBR still uses TCP internal pacing. The over-limit path scans the flow backlog table but batch-drops to amortize it. | Hashing, PIE early-drop logic on enqueue, dequeue-delay processing, plus the periodic controller scan; BBR still uses TCP internal pacing. |

Algorithm-owner/first-party references: [RFC 8289 (CoDel)](https://www.rfc-editor.org/rfc/rfc8289), [RFC 8290 (FQ-CoDel)](https://www.rfc-editor.org/rfc/rfc8290), and [RFC 8033 (PIE)](https://www.rfc-editor.org/rfc/rfc8033). RFC 8290 describes FQ-CoDel as memory- and CPU-efficient and documents its sparse-flow isolation; RFC 8033 describes PIE's lightweight controller, while the Linux FQ-PIE implementation adds an independent PIE state machine per flow and a periodic table scan.

#### Default and operator overrides

Use **`sch_fq` as the default qdisc** for this BBR/BBRv3 Debian cloud kernel. This is an inference from the verified workload contract: a VPS/server kernel predominantly emits local TCP, BBR is pacing-centric, both BBR implementations explicitly name `fq`, and `fq` uniquely consumes TCP EDT without the per-socket timer fallback.

Operators should override the default as follows:

- Use **`fq_codel`** on router/NAT/VPN/forwarding interfaces, or below a software shaper where the Linux qdisc is the actual bottleneck and adaptive bufferbloat control is more important than qdisc-level TCP EDT. It is the preferred general override because it has mature, parameter-light AQM, ECN enabled by default, and first-party evidence for sparse-flow latency isolation.
- Use **`fq_pie`** only when PIE behavior is an explicit deployment requirement (for example, interoperability experiments or an operator policy standardized around PIE), and configure ECN/target parameters deliberately. It is not a pacing-equivalent substitute for `sch_fq`, and Linux's periodic per-flow controller work gives it no clear default advantage for a memory- and CPU-conscious VPS host.
- Keep `sch_fq` but configure its CE threshold only for a known shallow-ECN environment; a fixed threshold is not a replacement for a general AQM on an unknown bottleneck.

**Risks:** `sch_fq` does not cure bufferbloat at a real software bottleneck, forwarded traffic loses its socket-keyed fast path, and cloud-provider/hypervisor queues remain outside the guest qdisc's direct control. Conversely, selecting either AQM qdisc globally restores TCP's per-socket pacing timers for local BBR flows. These tradeoffs make role-specific runtime overrides preferable to weakening the host default.

**Confidence: high** that `fq_pie`/`fq_codel` are not EDT-equivalent and that both BBR and BBRv3 explicitly prefer `fq`; **medium-high** that `sch_fq` is the best universal image default because router-heavy or shaped appliances have a different bottleneck model.

#### 2. CPU vulnerability mitigations 按项目策略处理

x86 fragment 继续使用：

```text
# CONFIG_CPU_MITIGATIONS is not set
```

这会在编译时永久移除 x86 mitigations，运行时不能重新开启。该项目明确接受此安全边界，以换取可信、小型 VPS guest 的性能与代码路径简化；镜像不应宣称适合运行不可信多租户 workload。来源：[x86 Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/x86/Kconfig?h=v6.18.34)、[hardware vulnerability docs](https://docs.kernel.org/admin-guide/hw-vuln/index.html)。

arm64 的通用 `CPU_MITIGATIONS` 在这些版本中是不可交互的 `def_bool y`，fragment 中写 `# CONFIG_CPU_MITIGATIONS is not set` 会被 `olddefconfig` 丢弃。因此 arm64 保持 Kconfig 默认 `y`；若部署策略要求关闭 mitigations，必须通过 kernel command line `mitigations=off` 实现。来源：[generic arch Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/Kconfig?h=v7.1.6)、[kernel parameters](https://docs.kernel.org/admin-guide/kernel-parameters.html)。

- 置信度：高；六个最终 config 已验证 x86=`n`、arm64=`y`。
- 风险：x86 编译时关闭不可逆，后续若扩大到共享或不可信 tenancy，必须重新构建启用 mitigations 的独立 flavour。

#### 3. THP 默认从 `always` 改为 `madvise`

上游 Kconfig 明确说明 `always` 可能增加 application memory footprint 而没有确定收益；`madvise` 只为主动请求 `MADV_HUGEPAGE` 的 workload 提供 THP。来源：[Transparent Hugepage documentation](https://docs.kernel.org/admin-guide/mm/transhuge.html)、[6.12 mm/Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/mm/Kconfig?h=v6.12.101)、[7.1 mm/Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/mm/Kconfig?h=v7.1.6)。

建议：

```text
# CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS is not set
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
```

适合作为混合用途、小内存 VPS 默认值。数据库、JVM、OLAP 等 workload 仍可通过 `madvise` 或 sysfs 显式启用更激进策略。

#### 4. 关闭 scheduler autogroup

上游将 `SCHED_AUTOGROUP` 描述为优化常见 desktop workloads，通过 session 自动分组。服务器、容器和 systemd slice 已使用 cgroup scheduler，不需要第二套 session-based grouping。来源：[6.12 init/Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/init/Kconfig?h=v6.12.101)。

建议：

```text
# CONFIG_SCHED_AUTOGROUP is not set
```

影响：减少桌面交互公平性逻辑；不影响标准 cgroup CPU controller。置信度：高，前提是内核定位明确为 headless server/VPS。

#### 5. 用 `LIST_HARDENED` 替代 `DEBUG_LIST`

上游说明 `DEBUG_LIST` 以性能换取更详细的 debugging report；关心性能时应仅启用 `LIST_HARDENED`。来源：[6.18 `lib/Kconfig.debug`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/lib/Kconfig.debug?h=v6.18.34)。

建议：

```text
# CONFIG_DEBUG_LIST is not set
CONFIG_LIST_HARDENED=y
```

这样保留 production hardening，移除扩展链表检查的 hot-path 成本。

### P1：高价值清理，但按 profile 决定

#### 6. 清除 test/benchmark modules

若发布镜像不承担 kernel testing/benchmark 职责，可考虑：

```text
# CONFIG_VDPA_SIM is not set
# CONFIG_BLK_DEV_NULL_BLK is not set
# CONFIG_SCSI_DEBUG is not set
# CONFIG_DM_DELAY is not set
# CONFIG_NET_PKTGEN is not set
```

收益主要是 module package、initramfs 和 build artifact 体积，不是稳态 CPU/RAM。`pktgen` 若用于网络回归测试，应保留在测试 profile。

#### 7. 评估关闭 UBSAN instrumentation

Debian 基线启用了 UBSAN bounds/shift instrumentation。上游说明 UBSAN 使用 compile-time instrumentation 在运行时检查 undefined behavior；sanitizer failure path 还会增加约 5% kernel size。来源：[6.12 UBSAN Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/lib/Kconfig.ubsan?h=v6.12.101)。

候选：

```text
# CONFIG_UBSAN is not set
```

这可能减少 code size 和运行时检查，但失去 bug detection。必须通过 kernel build、network、filesystem、container workload benchmark 后再决定。置信度：中；不建议未经实测直接进入所有 release。

#### 8. `SLUB_DEBUG` 与 `KALLSYMS_ALL` 只做体积 profile

- `SLUB_DEBUG` 默认 runtime debug capability 关闭，禁用主要节省 code size。上游明确称可有显著 code-size savings：[SLUB Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/mm/Kconfig.debug?h=v6.18.34)。
- `KALLSYMS_ALL` 增加约 300 KiB kernel image，但 x86 livepatch 等功能可能需要。来源：[init/Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/init/Kconfig?h=v6.18.34)。

建议只在 `lean` profile 使用：

```text
# CONFIG_SLUB_DEBUG is not set
# CONFIG_KALLSYMS_ALL is not set
```

保留 `CONFIG_KALLSYMS=y`，确保 Oops/backtrace 仍有 function symbol。启用 livepatch 时不要关闭 `KALLSYMS_ALL`。

#### 9. module compression 从 XZ 改为 ZSTD

Debian 当前选择 XZ module compression。ZSTD 通常更快解压，但 module 体积可能更大；initramfs 内部 module 更适合压缩整个 ramdisk。上游说明：[module Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/kernel/module/Kconfig?h=v6.12.101)。

候选：

```text
# CONFIG_MODULE_COMPRESS_XZ is not set
CONFIG_MODULE_COMPRESS_ZSTD=y
```

只在测量 boot、module load time 和 `.deb` size 后采用。置信度：中。

### P2：兼容性增强，不是纯性能优化

#### 10. 6.18/7.1 增加 Virtio RTC

`VIRTIO_RTC` 在 6.18/7.1 存在，Kconfig 对不确定场景建议 `m`；6.12 不存在。它可通过 PTP/RTC interface 暴露 hypervisor-provided virtual clock。来源：[7.1 Virtio Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/virtio/Kconfig?h=v7.1.6)、[6.12 Virtio Kconfig（无该符号）](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/virtio/Kconfig?h=v6.12.101)。

```text
CONFIG_VIRTIO_RTC=m
```

适用：6.18、7.1；x86_64、arm64。

#### 11. arm64 补齐 QEMU pvpanic

`pvpanic` 允许 QEMU guest 把 panic event 通知给 host。来源：[pvpanic Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/misc/pvpanic/Kconfig?h=v6.18.34)。

```text
CONFIG_PVPANIC=y
CONFIG_PVPANIC_MMIO=m
CONFIG_PVPANIC_PCI=m
```

这提升 QEMU/KVM 运维可观测性，不提升 throughput。

#### 12. 可选 SR-IOV compatibility profile

Debian cloud 已覆盖 ENA、gVNIC、MANA/netvsc、VMXNET3、Virtio、Xen、mlx4/mlx5、ixgbevf、IDPF 等主流路径。若目标还包括 OpenStack/private cloud 的 Intel/Broadcom SR-IOV VF，可单独评估：

```text
CONFIG_I40EVF=m
CONFIG_NET_VENDOR_BROADCOM=y
CONFIG_BNXT=m
```

不要因此启用 Intel `ICE` PF 或整套物理 NIC driver；guest 通常只需要 VF driver。该项必须通过实际 provider device inventory 决定。

## 不建议作为通用默认值

| 选项/策略 | 原因 |
|---|---|
| `CONFIG_NO_HZ_FULL` + 默认 CPU isolation | 面向 dedicated CPU/HPC/RT；上游明确指出增加 user/kernel transition overhead，并要求 boot-time CPU list。普通 VPS 无收益。 |
| `CONFIG_RCU_NOCB_CPU_DEFAULT_ALL=y` | 上游说明会增加 `call_rcu()` overhead、context switches 和 per-CPU kthreads；只用于 jitter-sensitive CPU isolation。 |
| `CONFIG_HZ_1000=y` | 可能改善部分短延迟 workload，但增加 tick/accounting 成本；通用 Debian cloud 的 `HZ_250` 更稳妥。 |
| `PREEMPT_FULL/RT` 作为统一默认 | 会牺牲 throughput，且改变 locking/timing 特征；应做单独 low-latency flavour。 |
| `CONFIG_ZSWAP_DEFAULT_ON=y` 与 zram 同时默认启用 | 可能形成双层压缩与额外 CPU/memory accounting。选择 zram 或 zswap，并由 userspace policy 控制。来源：[zswap docs](https://docs.kernel.org/admin-guide/mm/zswap.html)。 |
| `CONFIG_HYPERV_VTL_MODE=y` | 上游明确称此 kernel 必须运行在 VTL2，不能作为 normal guest，不能放入通用 cloud kernel。来源：[Hyper-V Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hv/Kconfig?h=v6.18.34)。 |
| 全局关闭 `INIT_ON_ALLOC`、FORTIFY、HARDENED_USERCOPY、stack protector | 这些是 production security hardening，不应为未量化的微小性能收益默认关闭。 |
| 继续大规模按 NIC vendor 裁剪 | 未加载 module 不驻留；收益主要是磁盘/package size，却可能破坏 uncommon SR-IOV/private cloud。 |
| 删除 ATA PIIX/AHCI | Debian 注释表明它们分别用于 Azure/OpenStack config drive；会直接降低兼容性。 |
| 删除 `VMGENID` | 会削弱 VM clone/rollback/snapshot 后 RNG reseed 安全。 |

## 跨版本与架构矩阵

| 候选 | 6.12 | 6.18 | 7.1 | x86_64 | arm64 |
|---|---:|---:|---:|---:|---:|
| `NET_SCH_FQ=y` + default `fq` | 支持 | 支持 | 支持 | 是 | 是 |
| `CPU_MITIGATIONS=y` compile-time policy | 支持 | 支持 | 支持 | 重点修复 | 保持架构默认 mitigation；不要全局 opt-out |
| THP `madvise` default | 支持 | 支持 | 支持 | 是 | 是 |
| `SCHED_AUTOGROUP=n` | 支持 | 支持 | 支持 | 是 | 是 |
| `DEBUG_LIST=n` + `LIST_HARDENED=y` | 支持 | 支持 | 支持 | 是 | 是 |
| `UBSAN=n` benchmark candidate | 支持 | 支持 | 支持 | 是 | 是 |
| `IDPF_SINGLEQ=n` | 支持 | 支持 | 支持 | 是 | 是 |
| `FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION=n` | 支持 | 支持 | 支持 | 重点 | 通常已为 n |
| `VDPA_SIM=n` / `VP_VDPA=n` | 支持 | 支持 | 支持 | 是 | 是 |
| `XEN_PRIVCMD_EVENTFD=n` guest profile | 支持 | 支持 | 支持 | 是 | 是 |
| `VIRTIO_RTC=m` | 不存在 | 支持 | 支持 | 是 | 是 |
| `PVPANIC` | 支持 | 支持 | 支持 | Debian 已覆盖 | 建议补齐 |
| `PTP_1588_CLOCK_VMW=m` | 支持 | 支持 | 支持 | VMware only | 不可用，依赖 X86 |
| module compression ZSTD | 支持 | 支持 | 支持 | 是 | 是 |

## 已实施的第一轮 fragment

以下设置已应用到对应 series/arch；仍需真实 workload benchmark 才能量化性能收益。

### x86_64

```text
# BBR pacing
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_FQ=y
# CONFIG_DEFAULT_FQ_CODEL is not set
CONFIG_DEFAULT_NET_SCH="fq"

# Safe server defaults
# CONFIG_CPU_MITIGATIONS is not set
# CONFIG_SCHED_AUTOGROUP is not set
# CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS is not set
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y

# Production hot-path cleanup
# CONFIG_DEBUG_LIST is not set
CONFIG_LIST_HARDENED=y
# CONFIG_IDPF_SINGLEQ is not set
# CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION is not set

# Keep niche guest helpers modular
CONFIG_X86_MSR=m
CONFIG_X86_CPUID=m
CONFIG_VMWARE_VMCI=m
CONFIG_PTP_1588_CLOCK_VMW=m

# Guest, not host/test profile
# CONFIG_VDPA_SIM is not set
# CONFIG_VP_VDPA is not set
# CONFIG_VIRTIO_VFIO_PCI is not set
# CONFIG_XEN_PRIVCMD_EVENTFD is not set
# CONFIG_REMOTE_TARGET is not set
# CONFIG_DM_MULTIPATH_HST is not set
# CONFIG_DM_MULTIPATH_IOA is not set

# 6.18/7.1 only
CONFIG_VIRTIO_RTC=m
```

### arm64

```text
# BBR pacing
CONFIG_NET_SCH_FQ=y
CONFIG_DEFAULT_FQ=y
# CONFIG_DEFAULT_FQ_CODEL is not set
CONFIG_DEFAULT_NET_SCH="fq"

# Server defaults
# CONFIG_SCHED_AUTOGROUP is not set
# CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS is not set
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y

# Production hot-path cleanup
# CONFIG_DEBUG_LIST is not set
CONFIG_LIST_HARDENED=y
# CONFIG_IDPF_SINGLEQ is not set

# Guest, not host/test/physical profile
# CONFIG_VDPA_SIM is not set
# CONFIG_VP_VDPA is not set
# CONFIG_XEN_PRIVCMD_EVENTFD is not set
# CONFIG_NXP_CBTX_PHY is not set
# CONFIG_HW_RANDOM_CCTRNG is not set
# CONFIG_PTP_1588_CLOCK_VMW is not set

# 7.1 pKVM dependency
CONFIG_DMA_RESTRICTED_POOL=y
CONFIG_ARM_PKVM_GUEST=y

# 6.18/7.1 only
CONFIG_VIRTIO_RTC=m
CONFIG_PVPANIC=y
CONFIG_PVPANIC_MMIO=m
CONFIG_PVPANIC_PCI=m
```

## 已完成的 Kconfig 验证

- Linux 6.12.101 + Debian `debian/6.12.101-1`：x86_64、arm64 均完成 merge 与 `olddefconfig`。
- Linux 6.18.34 + Debian 6.18 cloud config：x86_64、arm64 均完成 merge 与 `olddefconfig`。
- Linux 7.1.6 + Debian `debian/7.1.6-1`：x86_64、arm64 均完成 merge 与 `olddefconfig`。
- 六个 fragment 的非补丁符号均与最终 `.config` 一致；raw upstream tree 中缺少的 repo patch symbols `TCP_CONG_BBR1`、`TCP_CONG_BRUTAL`、`NETFILTER_XT_TARGET_FLOWOFFLOAD` 按预期不纳入该检查。
- 已确认 default qdisc=`fq`、THP=`madvise`、autogroup/`DEBUG_LIST`/sched_ext 关闭、`LIST_HARDENED=y`；x86 `MAXSMP=n`/`NR_CPUS=512`/`NODES_SHIFT=6`；6.18/7.1 `VIRTIO_RTC=m`；arm64 `pvpanic`；7.1 arm64 通过 `DMA_RESTRICTED_POOL=y` 满足新增的 pKVM guest dependency；7.1 stale crypto symbols 已清除。
- 此处未执行完整 kernel package build、虚拟机启动或性能 A/B；下列计划仍用于 release 前的 artifact、boot 与 benchmark 验证。

## 验证计划

### 阶段 A：Kconfig 与 artifact

每个 series/arch 生成 baseline 和 candidate 两套 config：

1. 运行 `apply_config.sh <series> <arch>` 与 `olddefconfig`。
2. 确认所有候选值最终生效，没有 dependency drop。
3. 比较 `vmlinux`、`bzImage`/`Image`、kernel `.deb`、modules `.deb`、initramfs 大小。
4. 确认 boot-critical Virtio/Xen/Hyper-V/VMware storage、network、console driver 未被意外裁掉。

### 阶段 B：虚拟化兼容性 smoke matrix

至少覆盖：

- KVM/QEMU：Virtio PCI、Virtio MMIO（arm64）、NVMe、SCSI、pvpanic、VIRTIO_RTC。
- Xen：PVH/HVM guest、balloon、net/block frontend；确认关闭的是 backend/privcmd eventfd 而非 frontend。
- Hyper-V/Azure：netvsc/MANA、storvsc、ATA PIIX config drive、time sync。
- VMware：VMXNET3、PVSCSI、VMCI/vsock、PTP module autoload。
- Confidential guest：SEV-SNP/TDX、Arm CCA/pKVM 按可用平台验证。

### 阶段 C：性能 A/B

- 网络：`iperf3`/`netperf`/`flent`，至少覆盖低 RTT、高 RTT、loss、单流、多流；记录 throughput、CPU、p95/p99 latency、retransmit、qdisc backlog。
- FQ 验证：检查 `tc qdisc show`、`ss -tin` pacing 信息；比较 `fq` 与 `fq_codel`。
- 内存：小内存 VPS、Redis/PostgreSQL/JVM/container build；记录 `AnonHugePages`、compaction stall、major fault、PSI、p99 latency。
- scheduler/debug：kernel build、hackbench/schbench、container CPU quota workload；比较 `SCHED_AUTOGROUP`、`DEBUG_LIST`、UBSAN on/off。
- boot：冷启动时间、initramfs 解压、module load latency；用于决定 XZ vs ZSTD。

## 最终建议顺序

1. 先提交“显然正确且低风险”的清理：`IDPF_SINGLEQ=n`、legacy fbcon acceleration `n`、arm64 无效 VMware PTP 删除、VMCI/PTP/MSR/CPUID 恢复 module、`VDPA_SIM=n`。
2. Adopt the small-VPS x86 scale policy separately: `MAXSMP=n` and `NR_CPUS=512`; document that it excludes current 832/896/1920-vCPU cloud instances, and retain `MAXSMP=y`/8192 only in a separate broad-compatibility or ultra-large flavour.
3. 第二批默认行为已实施：BBR + default `fq`、THP `madvise`、`SCHED_AUTOGROUP=n`、`DEBUG_LIST=n` + `LIST_HARDENED=y`；x86 mitigations 按项目策略保持编译时关闭，arm64 使用运行时 `mitigations=off` 才能关闭。
4. 兼容性增强已实施：6.18/7.1 `VIRTIO_RTC=m`、arm64 `pvpanic`，以及 7.1 arm64 pKVM 所需的 `DMA_RESTRICTED_POOL=y`。
5. UBSAN、SLUB_DEBUG、KALLSYMS_ALL、module compression 只在完成 A/B 数据后决定。
6. 不继续无数据地扩展 NIC vendor denylist；先从实际 provider PCI ID / modalias inventory 反推允许列表。
