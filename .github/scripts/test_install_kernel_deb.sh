#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_packages_dir=${1:-/packages}

# The installer is sourced so CI exercises its real package selection, APT
# sandbox permissions, and temporary download cleanup.
# shellcheck disable=SC1091
source "$repo_root/install-kernel.sh"
trap - ERR
trap cleanup_download_dir EXIT

prepare_temporary_packages() {
    create_download_dir
    cp "$source_packages_dir"/*.deb "$DOWNLOAD_DIR"/
    chmod 0600 "$DOWNLOAD_DIR"/*.deb
    install_download_dir=$DOWNLOAD_DIR
}

assert_sandboxed_install() {
    local log_file="$1"
    local expected_download_dir="$2"
    grep -Fq "$expected_download_dir/" "$log_file"
    if grep -Fq 'unsandboxed as root' "$log_file"; then
        printf 'error: APT fell back to an unsandboxed root download\n' >&2
        exit 1
    fi
    if [ -e "$expected_download_dir" ]; then
        printf 'error: temporary download directory was not cleaned up\n' >&2
        exit 1
    fi
}

prepare_temporary_packages
DISTRO_FAMILY=deb
AUTO_REBOOT=false
INSTALL_HEADERS=false
detect_kernel_release
release=$KERNEL_RELEASE
[ -n "$release" ]

install_packages 2>&1 | tee /tmp/runtime-install.log
assert_sandboxed_install /tmp/runtime-install.log "$install_download_dir"
[ -f "/boot/vmlinuz-$release" ]
[ -s "/boot/initrd.img-$release" ]
[ -d "/lib/modules/$release" ]
[ ! -e "/lib/modules/$release/build" ]
if dpkg-query -W -f='${db:Status-Abbrev}' "linux-headers-$release" 2>/dev/null | grep -q '^ii'; then
    printf 'error: kernel headers were installed without --headers\n' >&2
    exit 1
fi

prepare_temporary_packages
INSTALL_HEADERS=true
install_packages 2>&1 | tee /tmp/headers-install.log
assert_sandboxed_install /tmp/headers-install.log "$install_download_dir"
[ -L "/lib/modules/$release/build" ]
[ -d "/usr/src/linux-headers-$release" ]

dpkg_development_package=$(find "$source_packages_dir" -name 'linux-libc-dev_*.deb' -print -quit)
dpkg_development_package=$(dpkg-deb -f "$dpkg_development_package" Package)
apt-get purge -y "linux-headers-$release" "linux-image-$release" "$dpkg_development_package"
[ ! -e "/lib/modules/$release" ]
[ ! -e "/boot/vmlinuz-$release" ]
[ ! -e "/boot/initrd.img-$release" ]
