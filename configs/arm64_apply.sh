#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
kernel_dir=${KERNEL_DIR:-$PWD}
debian_config_dir=${DEBIAN_CONFIG_DIR:-$kernel_dir/../linux-debian/debian/config}
custom_config=${ARM64_CUSTOM_CONFIG:-$script_dir/arm64_custom.config}
merge_config=$kernel_dir/scripts/kconfig/merge_config.sh

require_file() {
  if [ ! -f "$1" ]; then
    printf 'error: required file not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_file "$merge_config"
require_file "$debian_config_dir/config"
require_file "$debian_config_dir/arm64/config"
require_file "$debian_config_dir/config.cloud"
require_file "$debian_config_dir/arm64/config.cloud-arm64"
require_file "$custom_config"

cd "$kernel_dir"
"$merge_config" -m \
  "$debian_config_dir/config" \
  "$debian_config_dir/arm64/config" \
  "$debian_config_dir/config.cloud" \
  "$debian_config_dir/arm64/config.cloud-arm64" \
  "$custom_config"

printf 'Merged Debian cloud-arm64 base config with %s\n' "$custom_config"
