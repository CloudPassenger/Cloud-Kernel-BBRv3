#!/usr/bin/env bash
# Integrate external modules or collect their build manifests.
set -euo pipefail

usage() {
  printf 'usage: %s integrate <kernel-dir> <kernel-series>\n' "$(basename "$0")" >&2
  printf '       %s manifest <kernel-series>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -ge 2 ] || usage
action=$1
shift
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
external_dir=$repo_root/external

if [ ! -d "$external_dir" ]; then
  printf 'error: external module directory not found: %s\n' "$external_dir" >&2
  exit 1
fi

case "$action" in
  integrate)
    [ "$#" -eq 2 ] || usage
    kernel_dir=$(realpath "$1")
    kernel_series=$2
    ;;
  manifest)
    [ "$#" -eq 1 ] || usage
    kernel_series=$1
    manifest_dir=$(mktemp -d)
    trap 'rm -rf "$manifest_dir"' EXIT
    ;;
  *) usage ;;
esac

if ! [[ "$kernel_series" =~ ^[0-9]+\.[0-9]+$ ]]; then
  printf 'error: invalid kernel series: %s\n' "$kernel_series" >&2
  exit 1
fi

module_dirs=("$external_dir"/*)
module_count=0
for module_dir in "${module_dirs[@]}"; do
  [ -d "$module_dir" ] || continue
  module_name=$(basename "$module_dir")
  for required_hook in integrate.sh manifest.sh; do
    if [ ! -f "$module_dir/$required_hook" ]; then
      printf 'error: external module %s is missing %s\n' \
        "$module_name" "$required_hook" >&2
      exit 1
    fi
  done

  if [ "$action" = integrate ]; then
    printf 'Integrating external module %s for Linux %s...\n' \
      "$module_name" "$kernel_series"
    bash "$module_dir/integrate.sh" "$kernel_dir" "$kernel_series"
  else
    module_manifest=$manifest_dir/$module_name.json
    bash "$module_dir/manifest.sh" "$kernel_series" \
      | jq --arg name "$module_name" '. + {name: $name}' > "$module_manifest"
    if ! jq -e 'type == "object"' "$module_manifest" >/dev/null; then
      printf 'error: invalid manifest from external module %s\n' "$module_name" >&2
      exit 1
    fi
  fi
  module_count=$((module_count + 1))
done

if [ "$module_count" -eq 0 ]; then
  printf 'error: no external module definitions found under %s\n' \
    "$external_dir" >&2
  exit 1
fi

if [ "$action" = integrate ]; then
  install -Dm755 "$script_dir/check_external_modules.sh" \
    "$kernel_dir/.external-modules/check.sh"
else
  jq -s 'sort_by(.name)' "$manifest_dir"/*.json
fi
