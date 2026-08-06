#!/usr/bin/env bash
# Merge Debian's own kernel config layers for a given kernel series/arch with
# this repo's custom config fragment, using the kernel tree's merge_config.sh.
#
# Usage: apply_config.sh <kernel-series> <arch>
#   kernel-series : e.g. 6.12 (matches custom_configs/<series>/ and kernel_patches/<series>/)
#   arch          : x86_64|amd64 or arm64|aarch64
#
# Env overrides:
#   KERNEL_DIR        kernel source tree to configure (default: $PWD)
#   DEBIAN_CONFIG_DIR  Debian debian/config directory (default: $KERNEL_DIR/../linux-debian/debian/config)
#   CUSTOM_CONFIG      custom config fragment path (default: custom_configs/<series>/<arch>.config)
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-series> <arch>\n' "$(basename "$0")" >&2
  printf '  kernel-series: e.g. 6.12\n' >&2
  printf '  arch: x86_64|amd64 or arm64|aarch64\n' >&2
  exit 1
}

[ $# -eq 2 ] || usage
series=$1
arch_arg=$2

case "$arch_arg" in
  x86_64|amd64)
    arch=x86_64
    debianarch=amd64
    kernelarch=x86
    ;;
  arm64|aarch64)
    arch=arm64
    debianarch=arm64
    kernelarch=arm64
    ;;
  *)
    printf 'error: unsupported arch: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
kernel_dir=${KERNEL_DIR:-$PWD}
debian_config_dir=${DEBIAN_CONFIG_DIR:-$kernel_dir/../linux-debian/debian/config}
custom_config=${CUSTOM_CONFIG:-$repo_root/custom_configs/$series/$arch.config}
merge_config=$kernel_dir/scripts/kconfig/merge_config.sh

require_file() {
  if [ ! -f "$1" ]; then
    printf 'error: required file not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_file "$merge_config"
require_file "$debian_config_dir/config"
require_file "$debian_config_dir/$debianarch/config"
require_file "$debian_config_dir/config.cloud"
require_file "$debian_config_dir/$debianarch/config.cloud-$debianarch"
require_file "$custom_config"

fragments=("$debian_config_dir/config")

# Some kernelarches (currently only x86) ship a shared config layer on top of
# the generic base and below the debianarch-specific one. Pick it up only
# when Debian actually provides it, so new arches need no changes here.
kernelarch_config="$debian_config_dir/kernelarch-$kernelarch/config"
if [ -f "$kernelarch_config" ]; then
  fragments+=("$kernelarch_config")
fi

fragments+=(
  "$debian_config_dir/$debianarch/config"
  "$debian_config_dir/config.cloud"
  "$debian_config_dir/$debianarch/config.cloud-$debianarch"
  "$custom_config"
)

cd "$kernel_dir"
"$merge_config" -m "${fragments[@]}"

printf 'Merged Debian cloud-%s base config with %s\n' "$debianarch" "$custom_config"
