#!/usr/bin/env bash
# Validate external-module configuration, build outputs, or packaged modules.
set -euo pipefail

usage() {
  printf 'usage: %s config <kernel-dir> [manifest]\n' "$(basename "$0")" >&2
  printf '       %s build <kernel-dir> <kernel-release> [manifest]\n' \
    "$(basename "$0")" >&2
  printf '       %s package <modules-dir> <manifest>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -ge 2 ] && [ "$#" -le 4 ] || usage
stage=$1
target_dir=$(realpath "$2")

case "$stage" in
  config)
    [ "$#" -le 3 ] || usage
    manifest_file=${3:-$target_dir/.external-modules/manifest.json}
    ;;
  build)
    [ "$#" -ge 3 ] || usage
    kernel_release=$3
    manifest_file=${4:-$target_dir/.external-modules/manifest.json}
    ;;
  package)
    [ "$#" -eq 3 ] || usage
    manifest_file=$3
    ;;
  *) usage ;;
esac
manifest_file=$(realpath "$manifest_file")

if [ ! -f "$manifest_file" ]; then
  printf 'error: external-module manifest not found: %s\n' "$manifest_file" >&2
  exit 1
fi
if ! jq -e '
    type == "array" and length > 0 and
    all(.[];
      (.name | type == "string" and length > 0) and
      (.source | type == "object") and
      (.config.required | type == "array") and
      all(.config.required[]; type == "string" and length > 0) and
      (.modules | type == "array" and length > 0) and
      all(.modules[];
        (.build_path | type == "string" and length > 0) and
        (.name | type == "string" and length > 0) and
        (.version | type == "string" and length > 0) and
        (.package_pattern | type == "string" and length > 0)
      )
    )
  ' "$manifest_file" >/dev/null; then
  printf 'error: invalid external-module manifest: %s\n' "$manifest_file" >&2
  exit 1
fi

case "$stage" in
  config)
    while IFS=$'\t' read -r package_name required_config; do
      if ! grep -qxF "$required_config" "$target_dir/.config"; then
        printf 'error: external module %s requires %s\n' \
          "$package_name" "$required_config" >&2
        exit 1
      fi
    done < <(jq -r '.[] | .name as $package | .config.required[] | [$package, .] | @tsv' \
      "$manifest_file")
    ;;
  build)
    [ -n "$kernel_release" ] || usage
    while IFS=$'\t' read -r package_name build_path module_name expected_version; do
      module_file=$target_dir/$build_path
      if [ ! -s "$module_file" ]; then
        printf 'error: external module %s output not found: %s\n' \
          "$package_name" "$module_file" >&2
        exit 1
      fi
      actual_name=$(modinfo -F name "$module_file")
      actual_version=$(modinfo -F version "$module_file")
      actual_vermagic=$(modinfo -F vermagic "$module_file")
      if [ "$actual_name" != "$module_name" ]; then
        printf 'error: external module %s has name %s, expected %s\n' \
          "$package_name" "$actual_name" "$module_name" >&2
        exit 1
      fi
      if [ "$actual_version" != "$expected_version" ]; then
        printf 'error: external module %s has version %s, expected %s\n' \
          "$package_name" "$actual_version" "$expected_version" >&2
        exit 1
      fi
      case "$actual_vermagic" in
        "$kernel_release "*) ;;
        *)
          printf 'error: external module %s vermagic %s does not match %s\n' \
            "$package_name" "$actual_vermagic" "$kernel_release" >&2
          exit 1
          ;;
      esac
    done < <(jq -r '.[] | .name as $package | .modules[] |
      [$package, .build_path, .name, .version] | @tsv' "$manifest_file")
    ;;
  package)
    while IFS=$'\t' read -r package_name package_pattern; do
      pattern_dir=$(dirname "$package_pattern")
      pattern_name=$(basename "$package_pattern")
      package_count=0
      if [ -d "$target_dir/$pattern_dir" ]; then
        package_count=$(find "$target_dir/$pattern_dir" -maxdepth 1 -type f \
          -name "$pattern_name" | wc -l)
      fi
      if [ "$package_count" -ne 1 ]; then
        printf 'error: expected one packaged module for %s matching %s, found %s\n' \
          "$package_name" "$package_pattern" "$package_count" >&2
        exit 1
      fi
    done < <(jq -r '.[] | .name as $package | .modules[] |
      [$package, .package_pattern] | @tsv' "$manifest_file")
    ;;
esac
