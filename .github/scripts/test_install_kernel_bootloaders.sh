#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# The installer is intentionally sourced so its bootloader functions can be tested.
# shellcheck disable=SC1091
source "$repo_root/install-kernel.sh"
trap - ERR

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mock_bin="$work_dir/bin"
system_root="$work_dir/system"
mkdir -p "$mock_bin"

cat > "$mock_bin/grub-mkconfig" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

[ "$1" = -o ]
grub_config="$2"
grub_defaults="$INSTALLER_TEST_ROOT/etc/default/grub"
default_entry=0
if [ -f "$grub_defaults" ]; then
    configured=$(sed -n 's/^[[:space:]]*GRUB_DEFAULT=//p' "$grub_defaults" | sed -n '1p')
    configured=${configured#\"}
    configured=${configured%\"}
    [ -z "$configured" ] || default_entry="$configured"
fi

mkdir -p "$(dirname "$grub_config")"
cat > "$grub_config" <<EOF
set default="$default_entry"
menuentry 'Alpine Linux, with Linux virt' --class os \$menuentry_id_option 'gnulinux-virt-advanced-test-root' {
    linux /boot/vmlinuz-virt
    initrd /boot/initramfs-virt
}
EOF
if [ "${MOCK_GRUB_INCLUDE_CLOUD:-true}" = true ]; then
    if [ "${MOCK_GRUB_STYLE:-apk}" = arch ]; then
        cat >> "$grub_config" <<'EOF'
menuentry 'Arch Linux, with Linux cloud-bbrv3' --class os $menuentry_id_option 'gnulinux-cloud-bbrv3-advanced-test-root' {
    linux /boot/vmlinuz-linux-cloud-bbrv3
    initrd /boot/initramfs-linux-cloud-bbrv3.img
}
EOF
    else
        cat >> "$grub_config" <<'EOF'
menuentry 'Alpine Linux, with Linux cloud-bbrv3' --class os $menuentry_id_option 'gnulinux-cloud-bbrv3-advanced-test-root' {
    linux /boot/vmlinuz-cloud-bbrv3
    initrd /boot/initramfs-cloud-bbrv3
}
EOF
    fi
fi
MOCK

cat > "$mock_bin/grub-script-check" <<'MOCK'
#!/usr/bin/env sh
exit 0
MOCK

cat > "$mock_bin/update-extlinux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

default_flavor=$(sed -n 's/^default=//p' "$INSTALLER_TEST_ROOT/etc/update-extlinux.conf" | sed -n '1p')
boot_config="$INSTALLER_TEST_ROOT/boot/extlinux.conf"
mkdir -p "$(dirname "$boot_config")"
cat > "$boot_config" <<'EOF'
LABEL virt
  MENU LABEL Linux virt
  LINUX vmlinuz-virt
  INITRD initramfs-virt
EOF
if [ "$default_flavor" = virt ]; then
    printf '%s\n' '  MENU DEFAULT' >> "$boot_config"
fi
cat >> "$boot_config" <<'EOF'
LABEL cloud-bbrv3
  MENU LABEL Linux cloud-bbrv3
  LINUX vmlinuz-cloud-bbrv3
  INITRD initramfs-cloud-bbrv3
EOF
if [ "$default_flavor" = cloud-bbrv3 ]; then
    printf '%s\n' '  MENU DEFAULT' >> "$boot_config"
fi
MOCK

chmod +x "$mock_bin/grub-mkconfig" "$mock_bin/grub-script-check" "$mock_bin/update-extlinux"
export PATH="$mock_bin:$PATH"
export INSTALLER_TEST_ROOT="$system_root"
export INSTALLER_ROOT="$system_root"
LANGUAGE=en

run_as_root() {
    "$@"
}

reset_system_root() {
    rm -rf "$system_root"
    mkdir -p "$system_root/etc/default" "$system_root/boot"
    MOCK_GRUB_INCLUDE_CLOUD=true
    export MOCK_GRUB_INCLUDE_CLOUD
    MOCK_GRUB_STYLE=apk
    export MOCK_GRUB_STYLE
}

assert_contains() {
    local expected="$1"
    local file="$2"
    grep -Fq "$expected" "$file"
}

reset_system_root
mkdir -p "$system_root/boot/grub"
printf '%s\n' '# initial GRUB config' > "$system_root/boot/grub/grub.cfg"
printf '%s\n' 'GRUB_DEFAULT=0' > "$system_root/etc/default/grub"
configure_apk_boot_default
assert_contains 'GRUB_DEFAULT="gnulinux-cloud-bbrv3-advanced-test-root"' \
    "$system_root/etc/default/grub"
assert_contains 'set default="gnulinux-cloud-bbrv3-advanced-test-root"' \
    "$system_root/boot/grub/grub.cfg"

reset_system_root
mkdir -p "$system_root/etc"
printf '%s\n' 'default=virt' > "$system_root/etc/update-extlinux.conf"
configure_apk_boot_default
assert_contains 'default=cloud-bbrv3' "$system_root/etc/update-extlinux.conf"
extlinux_cloud_is_default "$system_root/boot/extlinux.conf"

reset_system_root
cat > "$system_root/boot/extlinux.conf" <<'EOF'
LABEL virt
  MENU DEFAULT
  LINUX vmlinuz-virt
  INITRD initramfs-virt
LABEL cloud-bbrv3
  LINUX vmlinuz-cloud-bbrv3
  INITRD initramfs-cloud-bbrv3
EOF
configure_apk_boot_default
extlinux_cloud_is_default "$system_root/boot/extlinux.conf"
[ "$(grep -c '^[[:space:]]*MENU[[:space:]]\+DEFAULT[[:space:]]*$' \
    "$system_root/boot/extlinux.conf")" -eq 1 ]

reset_system_root
mkdir -p "$system_root/boot/grub"
printf '%s\n' '# initial GRUB config' > "$system_root/boot/grub/grub.cfg"
printf '%s\n' 'GRUB_DEFAULT=0' > "$system_root/etc/default/grub"
MOCK_GRUB_STYLE=arch
export MOCK_GRUB_STYLE
configure_arch_boot_default
assert_contains 'GRUB_DEFAULT="gnulinux-cloud-bbrv3-advanced-test-root"' \
    "$system_root/etc/default/grub"
assert_contains 'vmlinuz-linux-cloud-bbrv3' "$system_root/boot/grub/grub.cfg"

reset_system_root
mkdir -p "$system_root/boot/loader/entries"
printf '%s\n' 'default arch.conf' > "$system_root/boot/loader/loader.conf"
cat > "$system_root/boot/loader/entries/arch.conf" <<'EOF'
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=test-root rw quiet
EOF
configure_arch_boot_default
assert_contains 'default linux-cloud-bbrv3.conf' \
    "$system_root/boot/loader/loader.conf"
assert_contains 'linux   /vmlinuz-linux-cloud-bbrv3' \
    "$system_root/boot/loader/entries/linux-cloud-bbrv3.conf"
assert_contains 'options root=UUID=test-root rw quiet' \
    "$system_root/boot/loader/entries/linux-cloud-bbrv3.conf"

reset_system_root
mkdir -p "$system_root/boot/grub"
printf '%s\n' '# initial GRUB config' > "$system_root/boot/grub/grub.cfg"
printf '%s\n' 'GRUB_DEFAULT=0' > "$system_root/etc/default/grub"
MOCK_GRUB_INCLUDE_CLOUD=false
export MOCK_GRUB_INCLUDE_CLOUD
AUTO_REBOOT=true
if configure_apk_boot_default; then
    echo 'GRUB configuration unexpectedly succeeded without a cloud-bbrv3 entry' >&2
    exit 1
else
    AUTO_REBOOT=false
fi
[ "$AUTO_REBOOT" = false ]

reset_system_root
AUTO_REBOOT=true
if configure_apk_boot_default; then
    echo 'Bootloader detection unexpectedly succeeded without a supported config' >&2
    exit 1
else
    AUTO_REBOOT=false
fi
[ "$AUTO_REBOOT" = false ]

printf '%s\n' 'Installer bootloader integration checks passed.'
