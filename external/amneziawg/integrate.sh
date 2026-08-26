#!/usr/bin/env bash
# Import a pinned AmneziaWG release into a prepared Linux source tree.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-dir> <kernel-series>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 2 ] || usage
kernel_dir=$(realpath "$1")
kernel_series=$2
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
metadata_file=$script_dir/source.env
kconfig_file=$script_dir/Kconfig
destination=$kernel_dir/drivers/net/amneziawg

if ! [[ "$kernel_series" =~ ^[0-9]+\.[0-9]+$ ]]; then
  printf 'error: invalid kernel series: %s\n' "$kernel_series" >&2
  exit 1
fi

if [ ! -f "$kernel_dir/drivers/net/Kconfig" ] || [ ! -f "$kernel_dir/drivers/net/Makefile" ]; then
  printf 'error: invalid kernel source tree: %s\n' "$kernel_dir" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$metadata_file"
: "${AMNEZIAWG_REPOSITORY:?}"
: "${AMNEZIAWG_TAG:?}"
: "${AMNEZIAWG_COMMIT:?}"
: "${AMNEZIAWG_VERSION:?}"

if ! [[ "$AMNEZIAWG_TAG" =~ ^v[0-9][A-Za-z0-9._-]*$ ]]; then
  printf 'error: invalid AmneziaWG tag: %s\n' "$AMNEZIAWG_TAG" >&2
  exit 1
fi
if ! [[ "$AMNEZIAWG_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'error: invalid AmneziaWG commit: %s\n' "$AMNEZIAWG_COMMIT" >&2
  exit 1
fi
if ! [[ "$AMNEZIAWG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'error: invalid AmneziaWG version: %s\n' "$AMNEZIAWG_VERSION" >&2
  exit 1
fi
if [ -e "$destination" ]; then
  printf 'error: AmneziaWG destination already exists: %s\n' "$destination" >&2
  exit 1
fi
if grep -q '^config AMNEZIAWG$' "$kernel_dir/drivers/net/Kconfig"; then
  printf 'error: CONFIG_AMNEZIAWG is already wired into the kernel tree\n' >&2
  exit 1
fi
if grep -q 'CONFIG_AMNEZIAWG.*amneziawg/' "$kernel_dir/drivers/net/Makefile"; then
  printf 'error: AmneziaWG is already wired into drivers/net/Makefile\n' >&2
  exit 1
fi
kconfig_anchor_count=$(grep -c '^endif # NETDEVICES$' \
  "$kernel_dir/drivers/net/Kconfig" || true)
if [ "$kconfig_anchor_count" -ne 1 ]; then
  printf 'error: expected one NETDEVICES Kconfig anchor, found %s\n' \
    "$kconfig_anchor_count" >&2
  exit 1
fi

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
source_dir=$temp_dir/source

git -c advice.detachedHead=false clone --quiet \
  --branch "$AMNEZIAWG_TAG" --depth=1 "$AMNEZIAWG_REPOSITORY" "$source_dir"
actual_commit=$(git -C "$source_dir" rev-parse HEAD)
if [ "$actual_commit" != "$AMNEZIAWG_COMMIT" ]; then
  printf 'error: AmneziaWG tag %s resolved to %s, expected %s\n' \
    "$AMNEZIAWG_TAG" "$actual_commit" "$AMNEZIAWG_COMMIT" >&2
  exit 1
fi

upstream_version=$(sed -n 's/^#define WIREGUARD_VERSION "\([^"]*\)"$/\1/p' \
  "$source_dir/src/version.h")
if [ "$upstream_version" != "$AMNEZIAWG_VERSION" ]; then
  printf 'error: AmneziaWG source version %s does not match pinned version %s\n' \
    "$upstream_version" "$AMNEZIAWG_VERSION" >&2
  exit 1
fi
if ! grep -q '^amneziawg-y :=' "$source_dir/src/Kbuild"; then
  printf 'error: pinned AmneziaWG source has an unexpected Kbuild layout\n' >&2
  exit 1
fi

mkdir -p "$destination"
cp -a "$source_dir/src/." "$destination/"
rm -rf "$destination/tests"
rm -f "$destination/.gitignore" "$destination/wireguard.mod.c"
cp "$source_dir/COPYING" "$destination/COPYING"
cp "$kconfig_file" "$destination/Kconfig"
sed -i "s/^WIREGUARD_VERSION = .*/WIREGUARD_VERSION = $AMNEZIAWG_VERSION/" \
  "$destination/Makefile"
sed -i "s/^PACKAGE_VERSION=.*/PACKAGE_VERSION=\"$AMNEZIAWG_VERSION\"/" \
  "$destination/dkms.conf"

for patch_dir in "$script_dir/patches/common" "$script_dir/patches/$kernel_series"; do
  [ -d "$patch_dir" ] || continue
  for compatibility_patch in "$patch_dir"/*.patch; do
    [ -e "$compatibility_patch" ] || continue
    patch --fuzz=0 --directory "$destination" --strip=1 < "$compatibility_patch"
  done
done

cat > "$destination/version.h" <<EOF
#ifndef WIREGUARD_VERSION
#define WIREGUARD_VERSION "$AMNEZIAWG_VERSION"
#endif
EOF

sed -i \
  '/^endif # NETDEVICES$/i source "drivers/net/amneziawg/Kconfig"\n' \
  "$kernel_dir/drivers/net/Kconfig"
printf '\nobj-$%s += amneziawg/\n' '(CONFIG_AMNEZIAWG)' \
  >> "$kernel_dir/drivers/net/Makefile"

printf 'Imported AmneziaWG %s (%s) into %s\n' \
  "$AMNEZIAWG_VERSION" "$AMNEZIAWG_COMMIT" "$destination"
