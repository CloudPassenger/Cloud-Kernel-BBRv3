#!/usr/bin/env bash
# Refresh the central AmneziaWG source lock from an upstream tag.
set -euo pipefail

usage() {
  printf 'usage: %s <tag>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage
tag=$1
if ! [[ "$tag" =~ ^v[0-9][A-Za-z0-9._-]*$ ]]; then
  printf 'error: invalid AmneziaWG tag: %s\n' "$tag" >&2
  exit 1
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
metadata_file=$script_dir/source.env

# shellcheck source=/dev/null
source "$metadata_file"
: "${AMNEZIAWG_REPOSITORY:?}"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
source_dir=$temp_dir/source

git -c advice.detachedHead=false clone --quiet \
  --branch "$tag" --depth=1 "$AMNEZIAWG_REPOSITORY" "$source_dir"
commit=$(git -C "$source_dir" rev-parse HEAD)
version=$(sed -n 's/^#define WIREGUARD_VERSION "\([^"]*\)"$/\1/p' \
  "$source_dir/src/version.h")

if ! [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'error: failed to resolve commit for tag %s\n' "$tag" >&2
  exit 1
fi
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'error: failed to resolve version for tag %s\n' "$tag" >&2
  exit 1
fi
if [ "$tag" != "v$version" ]; then
  printf 'error: tag %s does not match source version %s\n' "$tag" "$version" >&2
  exit 1
fi
if ! grep -q '^amneziawg-y :=' "$source_dir/src/Kbuild"; then
  printf 'error: tag %s has an unexpected Kbuild layout\n' "$tag" >&2
  exit 1
fi
validate_patch_stack() {
  local series=$1
  local check_dir=$temp_dir/patch-check-$series
  local patch_dir compatibility_patch

  cp -a "$source_dir/src" "$check_dir"
  for patch_dir in "$script_dir/patches/common" "$script_dir/patches/$series"; do
    [ -d "$patch_dir" ] || continue
    for compatibility_patch in "$patch_dir"/*.patch; do
      [ -e "$compatibility_patch" ] || continue
      if ! patch --fuzz=0 --directory "$check_dir" --strip=1 \
          < "$compatibility_patch"; then
        printf 'error: compatibility patch no longer applies: %s\n' \
          "${compatibility_patch#"$script_dir/"}" >&2
        exit 1
      fi
    done
  done
}

validated_series=0
for series_patch_dir in "$script_dir/patches"/*; do
  [ -d "$series_patch_dir" ] || continue
  series=$(basename "$series_patch_dir")
  [ "$series" = common ] && continue
  validate_patch_stack "$series"
  validated_series=$((validated_series + 1))
done
if [ "$validated_series" -eq 0 ] && [ -d "$script_dir/patches/common" ]; then
  validate_patch_stack __common_only__
fi

cat > "$metadata_file" <<EOF
AMNEZIAWG_REPOSITORY=$AMNEZIAWG_REPOSITORY
AMNEZIAWG_TAG=$tag
AMNEZIAWG_COMMIT=$commit
AMNEZIAWG_VERSION=$version
EOF

printf 'Updated AmneziaWG source lock to %s (%s, version %s)\n' \
  "$tag" "$commit" "$version"
printf 'Revalidate compatibility patches and all supported kernel series before committing.\n'
