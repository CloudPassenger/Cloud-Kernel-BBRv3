#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_packages_dir=${1:-/packages}
packages_dir=$(mktemp -d)
cp "$source_packages_dir"/*.apk "$source_packages_dir"/*.rsa.pub "$packages_dir"/
trap 'rm -rf "$packages_dir"' EXIT

# The installer is sourced so CI exercises its real package selection and
# bootloader integration without downloading release assets again.
# shellcheck disable=SC1091
source "$repo_root/install-kernel.sh"
trap - ERR

DOWNLOAD_DIR=$packages_dir
DISTRO_FAMILY=apk
AUTO_REBOOT=false
INSTALL_HEADERS=false

install_packages 2>&1 | tee /tmp/runtime-install.log
release=$(cat /usr/share/kernel/cloud-bbrv3/kernel.release)

[ -f /boot/vmlinuz-cloud-bbrv3 ]
[ -s /boot/initramfs-cloud-bbrv3 ]
[ -d "/lib/modules/$release" ]
[ ! -e "/lib/modules/$release/build" ]
[ ! -e "/usr/src/linux-headers-$release" ]
apk info -e linux-firmware-none
! apk info -e linux-firmware
[ "$(apk info | grep -c '^linux-firmware')" -eq 1 ]

if [ "$(apk --print-arch)" = x86_64 ]; then
    grep -Fxq 'default=cloud-bbrv3' /etc/update-extlinux.conf
    extlinux_cloud_is_default /boot/extlinux.conf
    [ "$(grep -c '^[[:space:]]*MENU[[:space:]]\+DEFAULT[[:space:]]*$' \
        /boot/extlinux.conf)" -eq 1 ]
fi

INSTALL_HEADERS=true
mkdir -p "$packages_dir"
cp "$source_packages_dir"/*.apk "$source_packages_dir"/*.rsa.pub "$packages_dir"/
DOWNLOAD_DIR=$packages_dir

install_packages >/tmp/headers-install.log 2>&1
[ -L "/lib/modules/$release/build" ]
[ -d "/usr/src/linux-headers-$release" ]

apk del linux-cloud-bbrv3-dev linux-cloud-bbrv3
[ ! -e /boot/vmlinuz-cloud-bbrv3 ]
[ ! -e /boot/initramfs-cloud-bbrv3 ]
[ ! -e "/lib/modules/$release" ]
