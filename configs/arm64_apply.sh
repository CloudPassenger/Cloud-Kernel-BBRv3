#! /bin/bash

./scripts/kconfig/merge_config.sh -m \  
  ../linux-debian/debian/config/config \
  ../linux-debian/debian/config/arm64/config \
  ../linux-debian/debian/config/config.cloud \
  ../linux-debian/debian/config/arm64/config.cloud-arm64

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
./scripts/config --enable CONFIG_ARM_PKVM_GUEST
./scripts/config --module CONFIG_VDPA_SIM
./scripts/config --module CONFIG_VP_VDPA
./scripts/config --enable CONFIG_XEN_VIRTIO
./scripts/config --enable CONFIG_XEN_PRIVCMD_EVENTFD
# EFI
./scripts/config --enable CONFIG_EFI
./scripts/config --enable CONFIG_EFI_ZBOOT
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
# Frame Buffer
./scripts/config --enable CONFIG_SYSFB_SIMPLEFB
# Block Devices
./scripts/config --enable CONFIG_ZRAM_BACKEND_LZO
./scripts/config --enable CONFIG_ZRAM_DEF_COMP_ZSTD
./scripts/config --enable CONFIG_ZRAM_MULTI_COMP
# PCI
./scripts/config --enable CONFIG_PCI
# GPIO
./scripts/config --module CONFIG_GPIO_VIRTIO
# IO
./scripts/config --module CONFIG_UIO_HV_GENERIC
# Ethernet driver support
./scripts/config --disable CONFIG_NET_VENDOR_CORTINA
./scripts/config --disable CONFIG_NET_VENDOR_DAVICOM
./scripts/config --disable CONFIG_NET_VENDOR_ENGLEDER
./scripts/config --disable CONFIG_NET_VENDOR_FUNGIBLE
./scripts/config --disable CONFIG_NET_VENDOR_LITEX
./scripts/config --disable CONFIG_NET_VENDOR_META
./scripts/config --disable CONFIG_NET_VENDOR_VERTEXCOM
./scripts/config --disable CONFIG_NET_VENDOR_WANGXUN
./scripts/config --disable CONFIG_NET_VENDOR_XILINX
./scripts/config --module CONFIG_NXP_CBTX_PHY
./scripts/config --enable CONFIG_IDPF_SINGLEQ
# Clock Support
./scripts/config --enable CONFIG_PTP_1588_CLOCK_VMW
# Watchdog
./scripts/config --enable CONFIG_SOFT_WATCHDOG_PRETIMEOUT
./scripts/config --disable CONFIG_MARVELL_GTI_WDT
# Hardware
./scripts/config --disable CONFIG_SURFACE_PLATFORMS
# Crypto
./scripts/config --module CONFIG_CRYPTO_ECDSA
./scripts/config --module CONFIG_CRYPTO_ARIA
./scripts/config --module CONFIG_CRYPTO_HCTR2
./scripts/config --module CONFIG_HW_RANDOM_CCTRNG
./scripts/config --module CONFIG_CRYPTO_BLAKE2B
./scripts/config --module CONFIG_CRYPTO_SM3_NEON
./scripts/config --module CONFIG_CRYPTO_SM3_ARM64_CE
./scripts/config --module CONFIG_CRYPTO_AES_ARM64
./scripts/config --module CONFIG_CRYPTO_CHACHA20_NEON
./scripts/config --module CONFIG_CRYPTO_SM4_ARM64_CE
./scripts/config --module CONFIG_CRYPTO_SM4_ARM64_CE_BLK
./scripts/config --module CONFIG_CRYPTO_SM4_ARM64_NEON_BLK
./scripts/config --module CONFIG_CRYPTO_SM4_ARM64_CE_CCM
./scripts/config --module CONFIG_CRYPTO_SM4_ARM64_CE_GCM
./scripts/config --module CONFIG_CRYPTO_LIB_CURVE25519
echo "⭕ Applied custom kernel settings"