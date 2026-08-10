#!/usr/bin/env bash
# Build one Arch Linux x86_64 package set from an already-compiled kernel archive.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-version> <arch> <build-id> <compiled-archive> <output-dir>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 5 ] || usage

kernel_version=$1
arch_arg=$2
build_id=$3
compiled_archive=$(realpath "$4")
output_dir=$(realpath -m "$5")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
work_dir=$repo_root/.build/arch/$build_id-$arch_arg
package_dir=$work_dir/package
package_output=$work_dir/packages

diagnostic_build=${DIAGNOSTIC_BUILD:-false}
case "$diagnostic_build" in
  true) kernel_make_verbosity=1 ;;
  false) kernel_make_verbosity=0 ;;
  *)
    printf 'error: DIAGNOSTIC_BUILD must be true or false\n' >&2
    exit 1
    ;;
esac

case "$arch_arg" in
  x86_64|amd64) ;;
  arm64|aarch64)
    printf 'error: official Arch Linux packages are only built for x86_64\n' >&2
    exit 1
    ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

if [ ! -f "$compiled_archive" ]; then
  printf 'error: compiled kernel archive not found: %s\n' "$compiled_archive" >&2
  exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
  printf 'error: pacman is required for Arch Linux builds\n' >&2
  exit 1
fi

pacman -Syu --noconfirm --needed \
  base-devel bc bison cmake flex git kmod libelf mkinitcpio openssl \
  python rsync xxhash zstd

localversion=$(tar --zstd -xOf "$compiled_archive" linux/.config \
  | sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p')
kernel_release=$kernel_version$localversion
source_sha256=$(sha256sum "$compiled_archive")
source_sha256=${source_sha256%% *}

rm -rf "$work_dir"
mkdir -p "$package_dir" "$package_output" "$output_dir"
cp "$compiled_archive" "$package_dir/compiled-kernel.tar.zst"
sed \
  -e "s/@KERNEL_VERSION@/$kernel_version/g" \
  -e "s/@KERNEL_RELEASE@/$kernel_release/g" \
  -e "s/@MAKE_VERBOSITY@/$kernel_make_verbosity/g" \
  -e "s/@SOURCE_SHA256@/$source_sha256/g" \
  "$repo_root/packaging/arch/PKGBUILD.in" > "$package_dir/PKGBUILD"

if ! id builder >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash builder
fi
chown -R builder:builder "$work_dir"

runuser -u builder -- env \
  MAKEFLAGS="-j$(nproc)" \
  PKGDEST="$package_output" \
  makepkg \
    --dir "$package_dir" \
    --cleanbuild \
    --force \
    --noconfirm

find "$package_output" -maxdepth 1 -type f -name '*.pkg.tar.zst' \
  -exec cp -v {} "$output_dir"/ \;

packages=("$output_dir"/*.pkg.tar.zst)
if [ "${#packages[@]}" -ne 2 ]; then
  printf 'error: expected two Arch packages, found %d\n' "${#packages[@]}" >&2
  exit 1
fi
pacman -Qp "${packages[@]}"
