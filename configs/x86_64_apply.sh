#! /bin/bash

./scripts/kconfig/merge_config.sh -m \  
  ../linux-debian/debian/config/config \
  ../linux-debian/debian/config/amd64/config \
  ../linux-debian/debian/config/config.cloud \
  ../linux-debian/debian/config/amd64/config.cloud-amd64 \
  ../configs/x86_64.config

echo "⭕ Merged Configurations from Debian"

./scripts/config --disable CONFIG_FAIR_GROUP_SCHED
./scripts/config --disable CONFIG_SCHED_AUTOGROUP
./scripts/config --disable CONFIG_SCHED_CORE
./scripts/config --enable CONFIG_ECHO_SCHED
echo "⭕ Applied settings from ECHO-CPU-Scheduler"

# Kernel Config
./scripts/config --enable CONFIG_IKCONFIG
./scripts/config --enable CONFIG_IKCONFIG_PROC
# Virtualization
./scripts/config --enable CONFIG_HYPERVISOR_GUEST
./scripts/config --enable CONFIG_PARAVIRT_SPINLOCKS
./scripts/config --enable CONFIG_XEN
./scripts/config --enable CONFIG_XEN_PV
./scripts/config --enable CONFIG_XEN_PVH
./scripts/config --enable CONFIG_XEN_VIRTIO
./scripts/config --enable CONFIG_XEN_PRIVCMD_EVENTFD
./scripts/config --enable CONFIG_KVM_GUEST
./scripts/config --enable CONFIG_PARAVIRT_TIME_ACCOUNTING
./scripts/config --enable CONFIG_X86_MSR
./scripts/config --enable CONFIG_X86_CPUID
./scripts/config --enable CONFIG_VMWARE_VMCI
./scripts/config --module CONFIG_VMWARE_PVSCSI
./scripts/config --module CONFIG_VMWARE_BALLOON 
./scripts/config --module CONFIG_VIRTIO_VFIO_PCI
./scripts/config --module CONFIG_VDPA_SIM
./scripts/config --module CONFIG_VP_VDPA
./scripts/config --module CONFIG_HYPERV
./scripts/config --module CONFIG_HYPERV_UTILS
./scripts/config --module CONFIG_HYPERV_BALLOON
# EFI
./scripts/config --enable CONFIG_EFI
./scripts/config --enable CONFIG_EFI_STUB
./scripts/config --module CONFIG_EFI_SECRET
# CPU Mitigations
./scripts/config --disable CONFIG_CPU_MITIGATIONS
# Compat
./scripts/config --enable CONFIG_COMPAT_32BIT_TIME
# TCP Congestion Control
./scripts/config --enable CONFIG_TCP_CONG_BBR
./scripts/config --enable CONFIG_TCP_CONG_BBR1
./scripts/config --enable CONFIG_DEFAULT_BBR
./scripts/config --set-val CONFIG_DEFAULT_TCP_CONG "bbr"
# Netfilter
./scripts/config --module CONFIG_NFT_REJECT_NETDEV
./scripts/config --module CONFIG_NETFILTER_XT_TARGET_FLOWOFFLOAD
./scripts/config --module CONFIG_HYPERV_VSOCKETS
# PCI
./scripts/config --enable CONFIG_PCI
# Frame Buffer
./scripts/config --enable CONFIG_SYSFB_SIMPLEFB
./scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION
# Block Devices
./scripts/config --enable CONFIG_ZRAM_BACKEND_LZO
./scripts/config --enable CONFIG_ZRAM_DEF_COMP_ZSTD
./scripts/config --enable CONFIG_ZRAM_MULTI_COMP
# LVM
./scripts/config --module CONFIG_DM_MULTIPATH_HST
./scripts/config --module CONFIG_DM_MULTIPATH_IOA
# Generic Target Core Mod (TCM) and ConfigFS Infrastructure
./scripts/config --module CONFIG_REMOTE_TARGET
# Ethernet driver support
./scripts/config --disable CONFIG_NET_VENDOR_CORTINA
./scripts/config --disable CONFIG_NET_VENDOR_ENGLEDER
./scripts/config --disable CONFIG_NET_VENDOR_FUNGIBLE
./scripts/config --disable CONFIG_NET_VENDOR_LITEX
./scripts/config --disable CONFIG_NET_VENDOR_META
./scripts/config --disable CONFIG_NET_VENDOR_VERTEXCOM
./scripts/config --disable CONFIG_NET_VENDOR_WANGXUN
./scripts/config --disable CONFIG_NET_VENDOR_XILINX
./scripts/config --enable CONFIG_IDPF_SINGLEQ
# Clock Support
./scripts/config --enable CONFIG_PTP_1588_CLOCK_VMW
# Watchdog
./scripts/config --enable CONFIG_SOFT_WATCHDOG_PRETIMEOUT
# Hardware
./scripts/config --disable CONFIG_SURFACE_PLATFORMS
# Crypto
./scripts/config --module CONFIG_CRYPTO_BLAKE2B
./scripts/config --module CONFIG_CRYPTO_AES_NI_INTEL
./scripts/config --module CONFIG_CRYPTO_SM4_AESNI_AVX_X86_64
./scripts/config --module CONFIG_CRYPTO_SM4_AESNI_AVX2_X86_64
./scripts/config --module CONFIG_CRYPTO_ARIA_AESNI_AVX_X86_64
./scripts/config --module CONFIG_CRYPTO_ARIA_AESNI_AVX2_X86_64
./scripts/config --module CONFIG_CRYPTO_ARIA_GFNI_AVX512_X86_64
./scripts/config --module CONFIG_CRYPTO_POLYVAL_CLMUL_NI
./scripts/config --module CONFIG_CRYPTO_SM3_AVX_X86_64
./scripts/config --module CONFIG_CRYPTO_CRC32C_INTEL
./scripts/config --module CONFIG_CRYPTO_CRC32_PCLMUL
echo "⭕ Applied custom kernel settings"

