#!/usr/bin/env bash
# Package one Debian/Ubuntu .deb set from an already-compiled kernel archive.
#
# This intentionally does not call `make bindeb-pkg`: that target compiles
# and packages in one step, coupling the heavy build to Debian packaging.
# Instead it replicates upstream scripts/package/{mkdebian,builddeb}'s
# control/postinst/postrm/preinst/prerm content and modules_install /
# install-extmod-build / headers_install packaging steps by hand, against a
# kernel tree that build_kernel.sh already compiled once for every lane.
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
work_dir=$repo_root/.build/deb/$build_id-$arch_arg

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
  x86_64|amd64)
    kernel_arch=x86
    debarch=amd64
    ;;
  arm64|aarch64)
    kernel_arch=arm64
    debarch=arm64
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

rm -rf "$work_dir"
mkdir -p "$work_dir" "$output_dir"
tar --zstd -xf "$compiled_archive" -C "$work_dir"

kernel_dir=$work_dir/linux
if [ ! -f "$kernel_dir/.config" ]; then
  printf 'error: compiled kernel config not found\n' >&2
  exit 1
fi

cd "$kernel_dir"

kernel_release=$(make -s ARCH="$kernel_arch" kernelrelease)
case "$kernel_release" in
  "$kernel_version"|"$kernel_version"-*) ;;
  *)
    printf 'error: kernel release %s does not match version %s\n' "$kernel_release" "$kernel_version" >&2
    exit 1
    ;;
esac

# Refresh host-side build tooling (fixdep, modpost, sign-file, dtc, objtool,
# the Kconfig frontend, ...) against this container's own libc. The compiled
# vmlinux/*.ko objects are already built and are left untouched by this step.
make ARCH="$kernel_arch" CC=gcc HOSTCC=gcc modules_prepare

packageversion="$kernel_version-1"
maintainer="Cloud Kernel BBRv3 Maintainers <noreply@cloud-kernel-bbrv3.invalid>"
image_path=$(make -s ARCH="$kernel_arch" image_name)
initrd=No
if grep -q '^CONFIG_BLK_DEV_INITRD=y$' include/config/auto.conf; then
  initrd=Yes
fi

render_control() {
  sed \
    -e "s/@KERNEL_RELEASE@/$kernel_release/g" \
    -e "s/@DEBARCH@/$debarch/g" \
    -e "s/@PACKAGE_VERSION@/$packageversion/g" \
    -e "s/@MAINTAINER@/$maintainer/g" \
    "$1"
}

# --- linux-image-<release> --------------------------------------------------
image_root=$work_dir/pkg/linux-image
rm -rf "$image_root"
mkdir -p "$image_root/boot" "$image_root/DEBIAN"

if [ -d "arch/$kernel_arch/boot/dts" ]; then
  make ARCH="$kernel_arch" \
    V="$kernel_make_verbosity" \
    INSTALL_DTBS_PATH="$image_root/usr/lib/linux-image-$kernel_release" \
    dtbs_install
fi

make ARCH="$kernel_arch" \
  V="$kernel_make_verbosity" \
  INSTALL_MOD_PATH="$image_root" \
  INSTALL_MOD_STRIP=1 \
  modules_install
rm -f \
  "$image_root/lib/modules/$kernel_release/build" \
  "$image_root/lib/modules/$kernel_release/source"

cp System.map "$image_root/boot/System.map-$kernel_release"
cp .config "$image_root/boot/config-$kernel_release"
install -Dm644 "$image_path" "$image_root/boot/vmlinuz-$kernel_release"

render_control "$repo_root/packaging/deb/control-image.in" > "$image_root/DEBIAN/control"
for hook in postinst postrm preinst prerm; do
  sed \
    -e "s/@KERNEL_RELEASE@/$kernel_release/g" \
    -e "s#@INSTALLED_IMAGE_PATH@#boot/vmlinuz-$kernel_release#g" \
    -e "s#@HOOKDIR@#/etc/kernel/$hook.d#g" \
    -e "s/@INITRD@/$initrd/g" \
    "$repo_root/packaging/deb/kernel-hook.in" > "$image_root/DEBIAN/$hook"
  chmod 755 "$image_root/DEBIAN/$hook"
done

dpkg-deb --root-owner-group --build "$image_root" \
  "$output_dir/linux-image-${kernel_release}_${packageversion}_${debarch}.deb"

# --- linux-headers-<release> ------------------------------------------------
headers_root=$work_dir/pkg/linux-headers
rm -rf "$headers_root"
headers_dir="$headers_root/usr/src/linux-headers-$kernel_release"
mkdir -p "$headers_dir" "$headers_root/DEBIAN"

make ARCH="$kernel_arch" \
  V="$kernel_make_verbosity" \
  run-command \
  KBUILD_RUN_COMMAND="$PWD/scripts/package/install-extmod-build $headers_dir"
mkdir -p "$headers_root/lib/modules/$kernel_release"
ln -sf "/usr/src/linux-headers-$kernel_release" \
  "$headers_root/lib/modules/$kernel_release/build"

render_control "$repo_root/packaging/deb/control-headers.in" > "$headers_root/DEBIAN/control"

dpkg-deb --root-owner-group --build "$headers_root" \
  "$output_dir/linux-headers-${kernel_release}_${packageversion}_${debarch}.deb"

# --- linux-libc-dev ----------------------------------------------------------
libc_root=$work_dir/pkg/linux-libc-dev
rm -rf "$libc_root"
mkdir -p "$libc_root/usr" "$libc_root/DEBIAN"

make ARCH="$kernel_arch" \
  V="$kernel_make_verbosity" \
  headers_install \
  INSTALL_HDR_PATH="$libc_root/usr"

multiarch=$(dpkg-architecture -a "$debarch" -q DEB_HOST_MULTIARCH)
mkdir -p "$libc_root/usr/include/$multiarch"
mv "$libc_root/usr/include/asm" "$libc_root/usr/include/$multiarch/asm"

render_control "$repo_root/packaging/deb/control-libc-dev.in" > "$libc_root/DEBIAN/control"

dpkg-deb --root-owner-group --build "$libc_root" \
  "$output_dir/linux-libc-dev_${packageversion}_${debarch}.deb"

cp .config "$output_dir/linux-${kernel_version}-${debarch}.config"

for deb in "$output_dir"/*.deb; do
  dpkg-deb --info "$deb" | grep -E '^ (Package|Version|Architecture):'
done
printf 'Built Debian packages for kernel release %s\n' "$kernel_release"
