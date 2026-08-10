#!/usr/bin/env bash
# Build one Alpine-version-neutral APK set from a prepared kernel archive.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-version> <arch> <build-id> <source-archive> <output-dir>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 5 ] || usage

kernel_version=$1
arch_arg=$2
build_id=$3
source_archive=$(realpath "$4")
output_dir=$(realpath -m "$5")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
work_dir=$repo_root/.build/apk/$build_id-$arch_arg
package_dir=$work_dir/aports/testing/linux-cloud-bbrv3

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
  x86_64|amd64) expected_carch=x86_64 ;;
  arm64|aarch64) expected_carch=aarch64 ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

if [ ! -f "$source_archive" ]; then
  printf 'error: prepared source archive not found: %s\n' "$source_archive" >&2
  exit 1
fi

apk add \
  alpine-sdk argp-standalone bash bc binutils bison bpftool ccache cmake \
  diffutils doas elfutils-dev findutils flex gawk git gmp-dev installkernel \
  linux-headers mkinitfs mpc1-dev mpfr-dev musl-obstack-dev openssl-dev perl \
  pkgconf python3 rsync sed tar xz zlib-dev \
  zstd

bash "$script_dir/build_pahole.sh" /tmp/dwarves-v1.31
actual_carch=$(apk --print-arch)
if [ "$actual_carch" != "$expected_carch" ]; then
  printf 'error: expected Alpine architecture %s, got %s\n' "$expected_carch" "$actual_carch" >&2
  exit 1
fi

localversion=$(tar --zstd -xOf "$source_archive" linux/.config \
  | sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p')
kernel_release=$kernel_version$localversion

rm -rf "$work_dir"
mkdir -p "$package_dir" "$output_dir"
cp "$source_archive" "$package_dir/prepared-kernel.tar.zst"
sed \
  -e "s/@KERNEL_VERSION@/$kernel_version/g" \
  -e "s/@MAKE_VERBOSITY@/$kernel_make_verbosity/g" \
  -e "s/@KERNEL_RELEASE@/$kernel_release/g" \
  "$repo_root/packaging/apk/APKBUILD.in" > "$package_dir/APKBUILD"
sed \
  -e "s/@KERNEL_RELEASE@/$kernel_release/g" \
  "$repo_root/packaging/apk/post-deinstall.in" \
  > "$package_dir/linux-cloud-bbrv3.post-deinstall"
cp "$package_dir/linux-cloud-bbrv3.post-deinstall" \
  "$package_dir/linux-cloud-bbrv3-dev.post-deinstall"

if ! id builder >/dev/null 2>&1; then
  adduser -D builder
fi
addgroup builder abuild 2>/dev/null || true
printf 'permit nopass builder as root\n' > /etc/doas.d/abuild.conf
mkdir -p /home/builder/.abuild /home/builder/packages
chown -R builder:abuild "$work_dir" /home/builder/.abuild /home/builder/packages

export CCACHE_DIR=${CCACHE_DIR:-$repo_root/.ccache/apk/$build_id-$arch_arg}
mkdir -p "$CCACHE_DIR"
chown -R builder:abuild "$CCACHE_DIR"

su builder -c "abuild-keygen -a -n"
find /home/builder/.abuild -type f -name '*.rsa.pub' \
  -exec install -m 0644 {} /etc/apk/keys/ \;
su builder -c "cd '$package_dir' && CCACHE_DIR='$CCACHE_DIR' abuild checksum"
su builder -c "cd '$package_dir' && CCACHE_DIR='$CCACHE_DIR' abuild -r"

find /home/builder/packages -type f -name '*.apk' -exec cp -v {} "$output_dir"/ \;
find /home/builder/.abuild -type f -name '*.rsa.pub' -exec cp -v {} "$output_dir"/ \;

apk_version=$(apk --version)
printf 'Built with %s\n' "$apk_version"
