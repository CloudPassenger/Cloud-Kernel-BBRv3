#!/usr/bin/env bash
# Build one distribution-neutral RPM set from a prepared kernel archive.
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
work_dir=$repo_root/.build/rpm/$build_id-$arch_arg

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
    rpm_arch=x86_64
    kernel_arch=x86
    ;;
  arm64|aarch64)
    rpm_arch=aarch64
    kernel_arch=arm64
    ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

if [ ! -f "$source_archive" ]; then
  printf 'error: prepared source archive not found: %s\n' "$source_archive" >&2
  exit 1
fi

if command -v dnf >/dev/null 2>&1; then
  dnf -y install \
    bash bc binutils bison cmake diffutils elfutils-devel elfutils-libelf-devel \
    findutils flex gcc git gzip hostname kmod make openssl openssl-devel patch \
    perl python3 rpm-build rsync tar xz zlib-devel zstd
  if ! command -v ccache >/dev/null 2>&1; then
    dnf -y install ccache || {
      dnf -y install epel-release
      dnf -y install ccache
    }
  fi
else
  printf 'error: dnf is required for RPM builds\n' >&2
  exit 1
fi

bash "$script_dir/build_pahole.sh" "/tmp/dwarves-v1.31"

rm -rf "$work_dir"
mkdir -p "$work_dir" "$output_dir"
tar --zstd -xf "$source_archive" -C "$work_dir"

kernel_dir=$work_dir/linux
if [ ! -f "$kernel_dir/.config" ]; then
  printf 'error: prepared kernel config not found\n' >&2
  exit 1
fi


export CCACHE_DIR=${CCACHE_DIR:-$repo_root/.ccache/rpm/$build_id-$arch_arg}
mkdir -p "$CCACHE_DIR"

make -C "$kernel_dir" \
  ARCH="$kernel_arch" \
  CC="ccache gcc" \
  HOSTCC="ccache gcc" \
  olddefconfig

actual_release=$(make -s -C "$kernel_dir" ARCH="$kernel_arch" kernelrelease)
case "$actual_release" in
  "$kernel_version"|"$kernel_version"-*) ;;
  *)
    printf 'error: kernel release %s does not match version %s\n' "$actual_release" "$kernel_version" >&2
    exit 1
    ;;
esac

build_log=$work_dir/rpmbuild.log
set +e
rpmbuild -bb "$repo_root/packaging/rpm/kernel-cloud-bbrv3.spec" \
  --target "$rpm_arch" \
  --define "_topdir $work_dir/rpmbuild" \
  --define "kernel_version $kernel_version" \
  --define "kernel_release $actual_release" \
  --define "kernel_source_dir $kernel_dir" \
  --define "kernel_arch $kernel_arch" \
  --define "kernel_make_verbosity $kernel_make_verbosity" \
  > "$build_log" 2>&1
build_status=$?
set -e

if [ "$build_status" -ne 0 ]; then
  grep -nEi 'fatal|error:|Error [0-9]+|failed|killed|no space|undefined reference' \
    "$build_log" | tail -n 200 || true
  tail -n 500 "$build_log"
  exit "$build_status"
fi

cat "$build_log"

find "$work_dir/rpmbuild/RPMS" -type f -name '*.rpm' -exec cp -v {} "$output_dir"/ \;
rpm -qp --queryformat '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' "$output_dir"/*.rpm
