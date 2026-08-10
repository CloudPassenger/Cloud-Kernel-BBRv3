#!/usr/bin/env bash
# Compile one kernel tree exactly once and stage it for every packaging lane.
#
# This is the single "heavy" compile (vmlinux/Image + all enabled modules)
# shared by the DEB, RPM, APK, and Arch packaging lanes. It intentionally does
# NOT ship host-compiled programs (scripts/basic/fixdep, scripts/mod/modpost,
# scripts/sign-file, scripts/dtc/dtc, tools/objtool/objtool, ...): those are
# dynamically linked against the machine that compiled them, so every
# packaging lane must relink them against its own libc via `make
# modules_prepare` before it packages headers or signs modules. That step is
# a handful of small host C programs (seconds), not a kernel rebuild.
#
# Target-arch outputs (vmlinux/Image, *.ko modules) have no host libc
# dependency at all -- they are kernel-mode ELF loaded by the bootloader/
# kernel itself -- so they are safe to reuse byte-for-byte across every
# packaging distro.
set -euo pipefail

usage() {
  printf 'usage: %s <kernel-version> <arch> <source-archive> <output-dir>\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -eq 4 ] || usage

kernel_version=$1
arch_arg=$2
source_archive=$(realpath "$3")
output_dir=$(realpath -m "$4")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
work_dir=$repo_root/.build/kernel/$arch_arg

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
  x86_64|amd64) kernel_arch=x86 ;;
  arm64|aarch64) kernel_arch=arm64 ;;
  *)
    printf 'error: unsupported architecture: %s\n' "$arch_arg" >&2
    exit 1
    ;;
esac

if [ ! -f "$source_archive" ]; then
  printf 'error: prepared source archive not found: %s\n' "$source_archive" >&2
  exit 1
fi

sudo bash "$script_dir/build_pahole.sh" "${RUNNER_TEMP:-/tmp}/dwarves-v1.31"

rm -rf "$work_dir"
mkdir -p "$work_dir" "$output_dir"
tar --zstd -xf "$source_archive" -C "$work_dir"

kernel_dir=$work_dir/linux
if [ ! -f "$kernel_dir/.config" ]; then
  printf 'error: prepared kernel config not found\n' >&2
  exit 1
fi

kernel_localversion=${KERNEL_LOCALVERSION:-}
if ! grep -q '^CONFIG_DEBUG_INFO_BTF=y$' "$kernel_dir/.config"; then
  printf 'error: CONFIG_DEBUG_INFO_BTF was not selected\n' >&2
  exit 1
fi
if grep -q '^CONFIG_DEBUG_INFO_NONE=y$' "$kernel_dir/.config"; then
  printf 'error: CONFIG_DEBUG_INFO_NONE was unexpectedly selected\n' >&2
  exit 1
fi
if [ -n "$kernel_localversion" ]; then
  expected_localversion="CONFIG_LOCALVERSION=\"-$kernel_localversion\""
else
  expected_localversion='CONFIG_LOCALVERSION=""'
fi
if ! grep -qxF "$expected_localversion" "$kernel_dir/.config"; then
  printf 'error: expected %s, got: %s\n' \
    "$expected_localversion" "$(grep '^CONFIG_LOCALVERSION=' "$kernel_dir/.config")" >&2
  exit 1
fi

export CCACHE_DIR=${CCACHE_DIR:-$repo_root/.ccache/kernel/$arch_arg}
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

make -C "$kernel_dir" -j"$(nproc)" --output-sync=target \
  V="$kernel_make_verbosity" \
  ARCH="$kernel_arch" \
  CC="ccache gcc" \
  HOSTCC="ccache gcc" \
  KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-cloudpassenger}" \
  KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-cloud-kernel-bbrv3}"

# De-hostify: drop every host-compiled ELF program under scripts/ and tools/.
# Each packaging lane rebuilds these (cheaply, via `make modules_prepare`)
# against its own libc before it signs modules or packages headers. This
# leaves the actual compiled kernel/module objects untouched.
find "$kernel_dir/scripts" "$kernel_dir/tools" -type f -print0 2>/dev/null \
  | while IFS= read -r -d '' file; do
      case "$(head -c 4 "$file" 2>/dev/null)" in
        $'\x7fELF') rm -f "$file" ;;
      esac
    done
find "$kernel_dir/scripts" "$kernel_dir/tools" -name '*.o' -delete

tar --zstd -cf "$output_dir/compiled-kernel.tar.zst" -C "$work_dir" linux
printf 'Compiled kernel release %s for %s\n' "$actual_release" "$arch_arg"
