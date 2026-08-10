#!/usr/bin/env bash
# Prepare one patched and configured kernel source tree for every package adapter.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-version> <arch> [work-dir]\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage

kernel_version=$1
arch_arg=$2
work_dir_arg=${3:-$PWD/kernel-work}
series=${kernel_version%.*}
kernel_major=${kernel_version%%.*}
kernel_minor=${series#*.}

case "$arch_arg" in
  x86_64|amd64)
    arch=x86_64
    kernel_arch=x86
    ;;
  arm64|aarch64)
    arch=arm64
    kernel_arch=arm64
    ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
work_dir=$(realpath -m "$work_dir_arg")
kernel_dir=$work_dir/linux
debian_dir=$work_dir/linux-debian
xanmod_dir=$work_dir/linux-xanmod-patches
source_archive=$work_dir/linux-$kernel_version.tar.xz

for required_dir in \
  "$repo_root/kernel_patches/$series" \
  "$repo_root/custom_configs/$series"; do
  if [ ! -d "$required_dir" ]; then
    printf 'error: required directory not found: %s\n' "$required_dir" >&2
    exit 1
  fi
done

mkdir -p "$work_dir"
for path in "$kernel_dir" "$debian_dir" "$xanmod_dir"; do
  if [ -e "$path" ]; then
    printf 'error: work path already exists: %s\n' "$path" >&2
    exit 1
  fi
done

printf 'Downloading Linux %s source...\n' "$kernel_version"
curl --fail --location --retry 3 \
  --output "$source_archive" \
  "https://cdn.kernel.org/pub/linux/kernel/v${kernel_major}.x/linux-${kernel_version}.tar.xz"
tar -xJf "$source_archive" -C "$work_dir"
mv "$work_dir/linux-$kernel_version" "$kernel_dir"
rm -f "$source_archive"

printf 'Cloning Debian kernel tag debian/%s-1...\n' "$kernel_version"
git clone --branch "debian/$kernel_version-1" --depth=1 \
  https://salsa.debian.org/kernel-team/linux.git "$debian_dir"

printf 'Cloning XanMod patch collection...\n'
git clone --depth=1 https://gitlab.com/xanmod/linux-patches.git "$xanmod_dir"

if [ "$series" = "6.18" ] && dpkg --compare-versions "$kernel_version" lt "6.18.33"; then
  xanmod_ref=0bc9e62789c65ae9b2cf8910773f892a51d9e896
  git -C "$xanmod_dir" fetch --depth=1 origin "$xanmod_ref"
  git -C "$xanmod_dir" checkout --detach FETCH_HEAD
fi

xanmod_fix_dir=$repo_root/xanmod_patch_fixes/$series
if [ -d "$xanmod_fix_dir" ]; then
  for fix_patch in "$xanmod_fix_dir"/*.patch; do
    [ -e "$fix_patch" ] || continue
    patch -d "$xanmod_dir" -p1 < "$fix_patch"
  done
fi

cp -R "$debian_dir/debian/patches" "$kernel_dir/patches"

xanmod_net_dir=$xanmod_dir/linux-${kernel_major}.${kernel_minor}.y-xanmod/net
if [ ! -d "$xanmod_net_dir" ]; then
  xanmod_net_dir=$xanmod_dir/eol/linux-${kernel_major}.${kernel_minor}.y-xanmod/net
fi
if [ ! -d "$xanmod_net_dir" ]; then
  printf 'error: XanMod net patch directory not found for %s\n' "$series" >&2
  exit 1
fi

cp -R "$xanmod_net_dir" "$kernel_dir/patches/net"
cp -R "$repo_root/kernel_patches/$series" "$kernel_dir/patches/custom"

{
  printf '\n# Net patches from XanMod\n'
  find "$kernel_dir/patches/net" -type f -name '*.patch' -printf 'net/%P\n' | sort
  printf '# Custom patches\n'
  find "$kernel_dir/patches/custom" -type f -name '*.patch' -printf 'custom/%P\n' | sort
} >> "$kernel_dir/patches/series"

printf 'Applying complete patch series...\n'
(
  cd "$kernel_dir"
  QUILT_PATCHES=patches quilt push -a
)

printf 'Merging Debian cloud config for %s...\n' "$arch"
KERNEL_DIR=$kernel_dir \
DEBIAN_CONFIG_DIR=$debian_dir/debian/config \
  bash "$repo_root/.github/scripts/apply_config.sh" "$series" "$arch"
make -C "$kernel_dir" ARCH="$kernel_arch" olddefconfig
kernel_release=$(make -s -C "$kernel_dir" ARCH="$kernel_arch" kernelrelease)

kernel_source_sha=$(curl --fail --location --retry 3 --silent \
  "https://cdn.kernel.org/pub/linux/kernel/v${kernel_major}.x/sha256sums.asc" \
  | sed -n "s/^\\([0-9a-f]\\{64\\}\\)  linux-${kernel_version}\\.tar\\.xz$/\\1/p" \
  | head -n 1)
debian_commit=$(git -C "$debian_dir" rev-parse HEAD)
xanmod_commit=$(git -C "$xanmod_dir" rev-parse HEAD)
config_sha=$(sha256sum "$kernel_dir/.config" | cut -d ' ' -f 1)
series_sha=$(sha256sum "$kernel_dir/patches/series" | cut -d ' ' -f 1)

# Remove host-built helpers before archiving so each packaging lane rebuilds
# them against its own libc while preserving the resolved kernel config.
prepared_config=$work_dir/prepared.config
cp "$kernel_dir/.config" "$prepared_config"
make -C "$kernel_dir" ARCH="$kernel_arch" mrproper
mv "$prepared_config" "$kernel_dir/.config"

jq -n \
  --arg kernel_version "$kernel_version" \
  --arg kernel_release "$kernel_release" \
  --arg series "$series" \
  --arg arch "$arch" \
  --arg kernel_source_sha256 "$kernel_source_sha" \
  --arg debian_tag "debian/$kernel_version-1" \
  --arg debian_commit "$debian_commit" \
  --arg xanmod_commit "$xanmod_commit" \
  --arg patch_series_sha256 "$series_sha" \
  --arg config_sha256 "$config_sha" \
  '{
    kernel_version: $kernel_version,
    kernel_release: $kernel_release,
    series: $series,
    arch: $arch,
    kernel_source_sha256: $kernel_source_sha256,
    debian_tag: $debian_tag,
    debian_commit: $debian_commit,
    xanmod_commit: $xanmod_commit,
    patch_series_sha256: $patch_series_sha256,
    config_sha256: $config_sha256
  }' > "$work_dir/build-manifest.json"

printf 'Prepared Linux %s for %s in %s\n' "$kernel_version" "$arch" "$kernel_dir"
