#!/usr/bin/env bash
# Emit the AmneziaWG external-module manifest for one kernel series.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-series>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage
kernel_series=$1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
metadata_file=$script_dir/source.env

if ! [[ "$kernel_series" =~ ^[0-9]+\.[0-9]+$ ]]; then
  printf 'error: invalid kernel series: %s\n' "$kernel_series" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$metadata_file"
: "${AMNEZIAWG_REPOSITORY:?}"
: "${AMNEZIAWG_TAG:?}"
: "${AMNEZIAWG_COMMIT:?}"
: "${AMNEZIAWG_VERSION:?}"

kconfig_sha=$(sha256sum "$script_dir/Kconfig" | cut -d ' ' -f 1)
patch_scopes=()
for patch_scope in common "$kernel_series"; do
  if [ -d "$script_dir/patches/$patch_scope" ]; then
    patch_scopes+=("patches/$patch_scope")
  fi
done
if [ "${#patch_scopes[@]}" -gt 0 ]; then
  patches_sha=$(
    cd "$script_dir"
    find "${patch_scopes[@]}" -type f -name '*.patch' -print0 \
      | sort -z \
      | xargs -0 -r sha256sum \
      | sha256sum \
      | cut -d ' ' -f 1
  )
else
  patches_sha=$(printf '' | sha256sum | cut -d ' ' -f 1)
fi

required_config=(CONFIG_AMNEZIAWG=m)
if [ "$kernel_series" = 7.1 ]; then
  required_config+=(CONFIG_IPV6=y)
fi
required_config_json=$(printf '%s\n' "${required_config[@]}" | jq -R . | jq -s .)

jq -n \
  --arg repository "$AMNEZIAWG_REPOSITORY" \
  --arg tag "$AMNEZIAWG_TAG" \
  --arg commit "$AMNEZIAWG_COMMIT" \
  --arg version "$AMNEZIAWG_VERSION" \
  --arg kconfig_sha256 "$kconfig_sha" \
  --arg patches_sha256 "$patches_sha" \
  --argjson required_config "$required_config_json" \
  '{
    source: {
      repository: $repository,
      tag: $tag,
      commit: $commit,
      version: $version,
      kconfig_sha256: $kconfig_sha256,
      patches_sha256: $patches_sha256
    },
    config: {
      required: $required_config
    },
    modules: [{
      build_path: "drivers/net/amneziawg/amneziawg.ko",
      name: "amneziawg",
      version: $version,
      package_pattern: "kernel/drivers/net/amneziawg/amneziawg.ko*"
    }]
  }'
