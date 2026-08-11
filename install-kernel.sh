#!/usr/bin/env bash

# ==========================================================================
# Cloud Kernel BBRv3 Installer
# ==========================================================================
# Description: One-click installation script for Cloud Kernel BBRv3
# Author: AI Assistant
# Repository: https://github.com/CloudPassenger/Cloud-Kernel-BBRv3
# Version: 1.0
# ==========================================================================

# Exit on error
# set -e
# Exit on error and print the line number
trap 'echo "Error on line $LINENO: $BASH_COMMAND"' ERR

# Global variables
REPO_URL="https://github.com/CloudPassenger/Cloud-Kernel-BBRv3"
REPO_API="${REPO_URL/github.com/api.github.com\/repos}"
DOWNLOAD_DIR="./cloud-kernels"
SUPPORTED_SERIES=("6.12" "6.18" "7.1")
DEFAULT_SERIES="7.1"
KERNEL_SERIES=""
ARCH=""
LANGUAGE="zh"  # Default language: Chinese
SELECTED_TAG=""
KERNEL_RELEASE=""
AUTO_REBOOT=true
SPECIFIED_VERSION=""
COMMAND=""
DISTRO_ID=""
DISTRO_FAMILY=""
DISTRO_VERSION_MAJOR=""
RPM_ARCH=""
TRUSTED_GPG_FINGERPRINT=${CLOUD_KERNEL_GPG_FINGERPRINT:-}
SIGNING_PUBLIC_KEY_NAME="cloud-kernel-signing.asc"
APK_PUBLIC_KEY_NAME="cloud-kernel-bbrv3.rsa.pub"
CHECKSUM_MANIFEST_NAME="SHA256SUMS"
CHECKSUM_SIGNATURE_NAME="SHA256SUMS.asc"

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==========================================================================
# Language Support
# ==========================================================================

# Language strings
declare -A STRINGS
# English strings
STRINGS[en,welcome]="Welcome to Cloud Kernel BBRv3 Installer"
STRINGS[en,language_selection]="Please select your language:"
STRINGS[en,english]="English"
STRINGS[en,chinese]="简体中文"
STRINGS[en,checking_system]="Checking system compatibility..."
STRINGS[en,not_debian_based]="Error: Supported systems are Debian 11+, Ubuntu 20.04+, Fedora 43/44, Enterprise Linux 9/10, Alpine Linux 3.21-3.24, and Arch Linux x86_64."
STRINGS[en,debian_version_too_old]="Error: Debian version must be 11 or higher. Detected version:"
STRINGS[en,ubuntu_version_too_old]="Error: Ubuntu version must be 20.04 or higher. Detected version:"
STRINGS[en,architecture_check]="Checking system architecture..."
STRINGS[en,architecture_not_supported]="Error: Your system architecture is not supported. Only amd64 (x86_64) and arm64 (aarch64) are supported."
STRINGS[en,arch_linux_x86_only]="Error: Official Arch Linux packages are available only for x86_64."
STRINGS[en,detected_arch]="Detected architecture:"
STRINGS[en,fetching_releases]="Fetching available kernel releases..."
STRINGS[en,fetch_error]="Error fetching releases. Please check your internet connection and try again."
STRINGS[en,no_releases]="No releases found in the repository."
STRINGS[en,no_series_releases]="No releases found for the selected kernel series and architecture:"
STRINGS[en,select_series]="Select a kernel series:"
STRINGS[en,select_version]="Select kernel version to install:"
STRINGS[en,default_series]="default"
STRINGS[en,latest_recommended]="Latest version in this series!"
STRINGS[en,using_series]="Using kernel series:"
STRINGS[en,selected]="Selected:"
STRINGS[en,unsupported_series]="Error: Unsupported kernel series. Supported series: 6.12, 6.18, 7.1."
STRINGS[en,invalid_version]="Error: Kernel version must use the full x.y.z format."
STRINGS[en,version_series_mismatch]="Error: The specified kernel version does not belong to the selected series."
STRINGS[en,missing_option_value]="Error: Missing value for option:"
STRINGS[en,downloading]="Downloading kernel packages..."
STRINGS[en,kernel_release]="Kernel release:"
STRINGS[en,suffix_detected]="Kernel suffix detected:"
STRINGS[en,no_suffix_warning]="Note: this release carries no kernel suffix, so it may conflict with the distribution kernel of the same version."
STRINGS[en,boot_entry_missing]="Warning: the expected boot image was not found, please check the boot loader:"
STRINGS[en,boot_entry_found]="Installed boot image:"
STRINGS[en,apk_boot_default_set]="Set extlinux default boot flavor to:"
STRINGS[en,apk_boot_default_skip]="No /etc/update-extlinux.conf found (extlinux not in use); configure your bootloader manually to boot the new kernel by default."
STRINGS[en,created_dir]="Created download directory:"
STRINGS[en,downloading_file]="Downloading:"
STRINGS[en,download_success]="Successfully downloaded all kernel packages."
STRINGS[en,download_failed]="Failed to download one or more kernel packages."
STRINGS[en,verifying_downloads]="Verifying release signatures and checksums..."
STRINGS[en,verification_success]="Release signatures and checksums verified successfully."
STRINGS[en,verification_failed]="Release signature or checksum verification failed."
STRINGS[en,fingerprint_unpinned]="Warning: no trusted fingerprint was supplied. Signatures are checked against the release key, but the key identity is not pinned."
STRINGS[en,fingerprint_mismatch]="Error: The release signing key fingerprint does not match the trusted fingerprint."
STRINGS[en,installing]="Installing kernel packages..."
STRINGS[en,install_success]="Kernel installation completed successfully!"
STRINGS[en,install_failed]="Kernel installation failed."
STRINGS[en,reboot_prompt]="Do you want to reboot now to apply the new kernel? [y/N]: "
STRINGS[en,rebooting]="Rebooting system..."
STRINGS[en,skip_reboot]="Skipping reboot. Please reboot manually to apply the new kernel."
STRINGS[en,press_any_key]="Press any key to continue..."
STRINGS[en,root_required]="This script requires root privileges to install packages."
STRINGS[en,run_as_root]="Please run this script as root or with sudo:"
STRINGS[en,sudo_not_installed]="The 'sudo' command is not installed and you are not running as root."
STRINGS[en,installing_dependecies]="Installing required dependencies..."
STRINGS[en,dependency_installed]="Dependency installed successfully."
STRINGS[en,enter_choice]="Enter choice"
STRINGS[en,build_time]="Build Time"
STRINGS[en,updating_apt]="Updating package repository metadata..."
STRINGS[en,apt_updated]="Package repository metadata updated successfully."
STRINGS[en,pacman_update_notice]="Arch Linux package databases are used as-is to avoid an unsafe partial upgrade. Run 'sudo pacman -Syu' before this installer if the system is not fully updated."
STRINGS[en,version_not_found]="Error: Specified version not found."
STRINGS[en,using_auto_version]="Using latest available version in the selected series instead."
STRINGS[en,help_title]="Cloud Kernel BBRv3 Installer - Help"
STRINGS[en,help_usage]="Usage:"
STRINGS[en,help_commands]="Commands:"
STRINGS[en,help_install]="install    Install the kernel"
STRINGS[en,help_help]="help       Show this help message"
STRINGS[en,help_options]="Options:"
STRINGS[en,help_language]="  -l, --language    Set language (zh/en)"
STRINGS[en,help_install_options]="Options for 'install' command:"
STRINGS[en,help_series]="  -s, --series, --kernel-series    Select kernel series (6.12/6.18/7.1; default: 7.1)"
STRINGS[en,help_version]="  -v, --version     Specify full kernel version (infers series when -s is omitted)"
STRINGS[en,help_no_reboot]="  -a, --no-reboot   Skip reboot after installation"
STRINGS[en,help_signing_fingerprint]="      --signing-fingerprint    Optional trusted OpenPGP signing-key fingerprint"
STRINGS[en,help_examples]="Examples:"
STRINGS[en,help_example1]="  Install the latest kernel from the 6.18 series with English interface:"
STRINGS[en,help_example2]="  Install a specific kernel version without reboot:"
STRINGS[en,auto_install]="Automatic installation mode"
STRINGS[en,using_version]="Using kernel version:"

# Chinese strings
STRINGS[zh,welcome]="欢迎使用 Cloud Kernel BBRv3 安装程序"
STRINGS[zh,language_selection]="请选择您的语言："
STRINGS[zh,english]="English"
STRINGS[zh,chinese]="简体中文"
STRINGS[zh,checking_system]="正在检查系统兼容性..."
STRINGS[zh,not_debian_based]="错误：支持 Debian 11+、Ubuntu 20.04+、Fedora 43/44、Enterprise Linux 9/10、Alpine Linux 3.21-3.24，以及 Arch Linux x86_64。"
STRINGS[zh,debian_version_too_old]="错误：Debian 版本必须为 11 或更高。检测到的版本："
STRINGS[zh,ubuntu_version_too_old]="错误：Ubuntu 版本必须为 20.04 或更高。检测到的版本："
STRINGS[zh,architecture_check]="正在检查系统架构..."
STRINGS[zh,architecture_not_supported]="错误：您的系统架构不受支持。仅支持 amd64 (x86_64) 和 arm64 (aarch64)。"
STRINGS[zh,arch_linux_x86_only]="错误：官方 Arch Linux 软件包仅提供 x86_64 架构。"
STRINGS[zh,detected_arch]="检测到的架构："
STRINGS[zh,fetching_releases]="正在获取可用的内核版本..."
STRINGS[zh,fetch_error]="获取版本失败。请检查您的网络连接并重试。"
STRINGS[zh,no_releases]="在存储库中未找到版本。"
STRINGS[zh,no_series_releases]="未找到适用于所选内核系列和系统架构的版本："
STRINGS[zh,select_series]="请选择内核系列："
STRINGS[zh,select_version]="选择要安装的内核版本："
STRINGS[zh,default_series]="默认"
STRINGS[zh,latest_recommended]="此系列的最新版本！"
STRINGS[zh,using_series]="使用内核系列："
STRINGS[zh,selected]="已选择："
STRINGS[zh,unsupported_series]="错误：不支持的内核系列。支持的系列：6.12、6.18、7.1。"
STRINGS[zh,invalid_version]="错误：内核版本必须使用完整的 x.y.z 格式。"
STRINGS[zh,version_series_mismatch]="错误：指定的内核版本不属于所选系列。"
STRINGS[zh,missing_option_value]="错误：选项缺少参数值："
STRINGS[zh,downloading]="正在下载内核包..."
STRINGS[zh,kernel_release]="内核发行版本号："
STRINGS[zh,suffix_detected]="检测到内核后缀："
STRINGS[zh,no_suffix_warning]="注意：此版本不带内核后缀，可能与同版本号的发行版官方内核冲突。"
STRINGS[zh,boot_entry_missing]="警告：未找到预期的启动镜像，请检查引导器配置："
STRINGS[zh,boot_entry_found]="已安装启动镜像："
STRINGS[zh,apk_boot_default_set]="已将 extlinux 默认启动内核设置为："
STRINGS[zh,apk_boot_default_skip]="未找到 /etc/update-extlinux.conf（未使用 extlinux 引导器）；请手动配置引导器以默认启动新内核。"
STRINGS[zh,created_dir]="已创建下载目录："
STRINGS[zh,downloading_file]="正在下载："
STRINGS[zh,download_success]="成功下载所有内核包。"
STRINGS[zh,download_failed]="下载一个或多个内核包失败。"
STRINGS[zh,verifying_downloads]="正在验证发行签名和校验和..."
STRINGS[zh,verification_success]="发行签名和校验和验证成功。"
STRINGS[zh,verification_failed]="发行签名或校验和验证失败。"
STRINGS[zh,fingerprint_unpinned]="警告：未提供可信指纹。签名仍会使用 Release 中的公钥验证，但不会钉扎该密钥的身份。"
STRINGS[zh,fingerprint_mismatch]="错误：发行签名密钥指纹与可信指纹不匹配。"
STRINGS[zh,installing]="正在安装内核包..."
STRINGS[zh,install_success]="内核安装成功完成！"
STRINGS[zh,install_failed]="内核安装失败。"
STRINGS[zh,reboot_prompt]="是否现在重启以应用新内核？[y/N]："
STRINGS[zh,rebooting]="正在重启系统..."
STRINGS[zh,skip_reboot]="跳过重启。请手动重启以应用新内核。"
STRINGS[zh,press_any_key]="按任意键继续..."
STRINGS[zh,root_required]="此脚本需要 root 权限才能安装软件包。"
STRINGS[zh,run_as_root]="请以 root 身份或使用 sudo 运行此脚本："
STRINGS[zh,sudo_not_installed]="'sudo' 命令未安装，并且您不是以 root 身份运行。"
STRINGS[zh,installing_dependecies]="正在安装所需的依赖项..."
STRINGS[zh,dependency_installed]="依赖项安装成功。"
STRINGS[zh,enter_choice]="请输入选择"
STRINGS[zh,build_time]="构建时间"
STRINGS[zh,updating_apt]="正在更新软件包仓库元数据..."
STRINGS[zh,apt_updated]="软件包仓库元数据更新成功。"
STRINGS[zh,pacman_update_notice]="为避免不安全的部分升级，Arch Linux 将直接使用当前软件包数据库。如果系统不是最新状态，请先运行 'sudo pacman -Syu'。"
STRINGS[zh,version_not_found]="错误：未找到指定版本。"
STRINGS[zh,using_auto_version]="将使用所选系列的最新可用版本。"
STRINGS[zh,help_title]="Cloud Kernel BBRv3 安装程序 - 帮助"
STRINGS[zh,help_usage]="用法："
STRINGS[zh,help_commands]="命令："
STRINGS[zh,help_install]="install    安装内核"
STRINGS[zh,help_help]="help       显示此帮助信息"
STRINGS[zh,help_options]="选项："
STRINGS[zh,help_language]="  -l, --language    设置语言 (zh/en)"
STRINGS[zh,help_install_options]="'install' 命令的选项："
STRINGS[zh,help_series]="  -s, --series, --kernel-series    选择内核系列 (6.12/6.18/7.1；默认：7.1)"
STRINGS[zh,help_version]="  -v, --version     指定完整内核版本（未设置 -s 时自动推断系列）"
STRINGS[zh,help_no_reboot]="  -a, --no-reboot   安装后不重启"
STRINGS[zh,help_signing_fingerprint]="      --signing-fingerprint    可选的可信 OpenPGP 签名密钥指纹"
STRINGS[zh,help_examples]="示例："
STRINGS[zh,help_example1]="  使用英文界面安装 6.18 系列的最新内核："
STRINGS[zh,help_example2]="  安装特定版本内核且不重启："
STRINGS[zh,auto_install]="自动安装模式"
STRINGS[zh,using_version]="使用内核版本："

# Get string according to current language
get_string() {
    echo "${STRINGS[$LANGUAGE,$1]}"
}

# ==========================================================================
# Helper Functions
# ==========================================================================

# Print colored text
print_colored() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${NC}"
}

# Print section header
print_header() {
    local text="$1"
    echo ""
    print_colored "${BOLD}${BLUE}" "==================================================="
    print_colored "${BOLD}${BLUE}" "  $text"
    print_colored "${BOLD}${BLUE}" "==================================================="
    echo ""
}

# Wait for user input
wait_for_key() {
    read -n 1 -s -r -p "$(get_string press_any_key)"
    echo ""
}

# Check for root privileges
check_root() {
    if [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1; then
        return
    fi

    print_colored "${RED}" "$(get_string sudo_not_installed)"
    print_colored "${YELLOW}" "$(get_string root_required)"
    print_colored "${YELLOW}" "$(get_string run_as_root)"
    echo "  sudo $0"
    echo "  or"
    echo "  su -c \"$0\""
    exit 1
}

# Run a command as root without duplicating sudo handling
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Update package repository metadata
update_package_index() {
    if [ "$DISTRO_FAMILY" = pacman ]; then
        print_colored "${YELLOW}" "$(get_string pacman_update_notice)"
        return
    fi

    print_colored "${CYAN}" "$(get_string updating_apt)"

    case "$DISTRO_FAMILY" in
        deb) run_as_root apt-get update ;;
        rpm) run_as_root dnf makecache ;;
        apk) run_as_root apk update ;;
        *) return 1 ;;
    esac

    print_colored "${GREEN}" "$(get_string apt_updated)"
}

# Install a dependency package
install_dependency() {
    local command_name="$1"
    local package_name="${2:-$1}"

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    print_colored "${CYAN}" "$(get_string installing_dependecies) $package_name"
    case "$DISTRO_FAMILY" in
        deb) run_as_root apt-get install -y "$package_name" ;;
        rpm) run_as_root dnf install -y "$package_name" ;;
        apk) run_as_root apk add "$package_name" ;;
        pacman) run_as_root pacman -S --needed --noconfirm "$package_name" ;;
        *)
            print_colored "${RED}" "$(get_string install_failed)"
            exit 1
            ;;
    esac
    print_colored "${GREEN}" "$(get_string dependency_installed)"
}

# Install GnuPG using the distribution-specific package name.
install_gpg_dependency() {
    case "$DISTRO_FAMILY" in
        deb|apk|pacman) install_dependency gpg gnupg ;;
        rpm) install_dependency gpg gnupg2 ;;
    esac
}

# Normalize an OpenPGP fingerprint for exact comparison.
normalize_fingerprint() {
    tr -d '[:space:]' | tr '[:lower:]' '[:upper:]'
}

# Verify the release key, detached manifest signature, and every download.
verify_downloads() {
    print_header "$(get_string verifying_downloads)"

    if [ -n "$TRUSTED_GPG_FINGERPRINT" ]; then
        TRUSTED_GPG_FINGERPRINT=$(printf '%s' "$TRUSTED_GPG_FINGERPRINT" | normalize_fingerprint)
    fi

    local public_key="$DOWNLOAD_DIR/$SIGNING_PUBLIC_KEY_NAME"
    local manifest="$DOWNLOAD_DIR/$CHECKSUM_MANIFEST_NAME"
    local signature="$DOWNLOAD_DIR/$CHECKSUM_SIGNATURE_NAME"
    if [ ! -s "$public_key" ] || [ ! -s "$manifest" ] || [ ! -s "$signature" ]; then
        print_colored "${RED}" "$(get_string verification_failed)"
        exit 1
    fi

    install_gpg_dependency

    local actual_fingerprint
    actual_fingerprint=$(gpg --batch --with-colons --show-keys "$public_key" \
        | sed -n 's/^fpr:::::::::\([^:]*\):$/\1/p' \
        | sed -n '1p')
    actual_fingerprint=$(printf '%s' "$actual_fingerprint" | normalize_fingerprint)
    if [ -z "$actual_fingerprint" ]; then
        print_colored "${RED}" "$(get_string verification_failed)"
        exit 1
    fi
    if [ -n "$TRUSTED_GPG_FINGERPRINT" ] && \
       [ "$actual_fingerprint" != "$TRUSTED_GPG_FINGERPRINT" ]; then
        print_colored "${RED}" "$(get_string fingerprint_mismatch)"
        exit 1
    fi
    if [ -z "$TRUSTED_GPG_FINGERPRINT" ]; then
        print_colored "${YELLOW}" "$(get_string fingerprint_unpinned)"
    fi

    local keyring
    keyring=$(mktemp)
    if ! gpg --batch --yes --dearmor --output "$keyring" "$public_key" || \
       ! gpgv --keyring "$keyring" "$signature" "$manifest"; then
        rm -f "$keyring"
        print_colored "${RED}" "$(get_string verification_failed)"
        exit 1
    fi
    rm -f "$keyring"

    declare -A manifest_hashes=()
    local expected_hash filename extra
    while read -r expected_hash filename extra; do
        [ -n "$expected_hash" ] && [ -n "$filename" ] && [ -z "$extra" ] || {
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        }
        filename=${filename#\*}
        if [[ ! "$expected_hash" =~ ^[0-9a-fA-F]{64}$ ]] || \
           [[ "$filename" == */* ]] || [ -n "${manifest_hashes[$filename]+x}" ]; then
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi
        manifest_hashes[$filename]=${expected_hash,,}
    done < "$manifest"

    local downloaded_file actual_hash
    for downloaded_file in "$DOWNLOAD_DIR"/*; do
        [ -f "$downloaded_file" ] || continue
        filename=$(basename "$downloaded_file")
        case "$filename" in
            "$CHECKSUM_MANIFEST_NAME"|"$CHECKSUM_SIGNATURE_NAME") continue ;;
        esac
        if [ -z "${manifest_hashes[$filename]+x}" ]; then
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi
        actual_hash=$(sha256sum "$downloaded_file")
        actual_hash=${actual_hash%% *}
        if [ "${actual_hash,,}" != "${manifest_hashes[$filename]}" ]; then
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi
    done

    if [ "$DISTRO_FAMILY" = rpm ]; then
        run_as_root rpm --import "$public_key"
        local rpm_package
        for rpm_package in "$DOWNLOAD_DIR"/*.rpm; do
            [ -f "$rpm_package" ] || continue
            if ! rpmkeys --checksig "$rpm_package"; then
                print_colored "${RED}" "$(get_string verification_failed)"
                exit 1
            fi
        done
    fi

    if [ "$DISTRO_FAMILY" = pacman ]; then
        local package_keyring
        package_keyring=$(mktemp)
        if ! gpg --batch --yes --dearmor --output "$package_keyring" "$public_key"; then
            rm -f "$package_keyring"
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi

        local arch_package package_signature
        local arch_package_count=0
        for arch_package in "$DOWNLOAD_DIR"/*.pkg.tar.zst; do
            [ -f "$arch_package" ] || continue
            arch_package_count=$((arch_package_count + 1))
            package_signature=$arch_package.sig
            if [ ! -s "$package_signature" ] || \
               ! gpgv --keyring "$package_keyring" "$package_signature" "$arch_package"; then
                rm -f "$package_keyring"
                print_colored "${RED}" "$(get_string verification_failed)"
                exit 1
            fi
        done
        if [ "$arch_package_count" -ne 2 ]; then
            rm -f "$package_keyring"
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi

        if ! run_as_root pacman-key --init || \
           ! run_as_root pacman-key --add "$public_key" || \
           ! run_as_root pacman-key --lsign-key "$actual_fingerprint"; then
            rm -f "$package_keyring"
            print_colored "${RED}" "$(get_string verification_failed)"
            exit 1
        fi
        rm -f "$package_keyring"
    fi

    print_colored "${GREEN}" "✓ $(get_string verification_success)"
}


# Select language
select_language() {
    clear
    print_colored "${BOLD}${GREEN}" "Cloud Kernel BBRv3 Installer / 安装程序"
    echo ""
    print_colored "${YELLOW}" "Please select your language / 请选择您的语言:"
    echo ""
    echo "1) English"
    echo "2) 中文"
    echo ""
    
    local choice
    read -r -p "Enter choice / 请输入选择 [1-2]: " choice
    
    case $choice in
        1)
            LANGUAGE="en"
            ;;
        2)
            LANGUAGE="zh"
            ;;
        *)
            LANGUAGE="zh"
            ;;
    esac
    
    clear
    print_header "$(get_string welcome)"
}

# Check whether a kernel series is maintained by this repository
is_supported_series() {
    local requested_series="$1"
    local series

    for series in "${SUPPORTED_SERIES[@]}"; do
        if [ "$series" = "$requested_series" ]; then
            return 0
        fi
    done

    return 1
}

# Select a maintained kernel series in interactive mode
select_kernel_series() {
    print_colored "${PURPLE}" "$(get_string select_series)"
    echo ""

    local i
    for i in "${!SUPPORTED_SERIES[@]}"; do
        if [ "${SUPPORTED_SERIES[$i]}" = "$DEFAULT_SERIES" ]; then
            echo "$((i + 1))) ${SUPPORTED_SERIES[$i]} ($(get_string default_series))"
        else
            echo "$((i + 1))) ${SUPPORTED_SERIES[$i]}"
        fi
    done

    echo ""
    local choice
    read -r -p "$(get_string enter_choice) [1-${#SUPPORTED_SERIES[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#SUPPORTED_SERIES[@]}" ]; then
        KERNEL_SERIES="${SUPPORTED_SERIES[$((choice - 1))]}"
    else
        KERNEL_SERIES="$DEFAULT_SERIES"
    fi

    print_colored "${GREEN}" "✓ $(get_string using_series) $KERNEL_SERIES"
}

# Validate and normalize command-line kernel selection options
validate_kernel_selection() {
    local version_series=""

    if [ -n "$SPECIFIED_VERSION" ]; then
        if [[ ! "$SPECIFIED_VERSION" =~ ^([0-9]+\.[0-9]+)\.[0-9]+$ ]]; then
            print_colored "${RED}" "$(get_string invalid_version) $SPECIFIED_VERSION"
            exit 1
        fi

        version_series="${BASH_REMATCH[1]}"
        if [ -z "$KERNEL_SERIES" ]; then
            KERNEL_SERIES="$version_series"
        elif [ "$KERNEL_SERIES" != "$version_series" ]; then
            print_colored "${RED}" "$(get_string version_series_mismatch) $SPECIFIED_VERSION / $KERNEL_SERIES"
            exit 1
        fi
    fi

    if [ "$COMMAND" = "install" ] && [ -z "$KERNEL_SERIES" ]; then
        KERNEL_SERIES="$DEFAULT_SERIES"
    fi

    if [ -n "$KERNEL_SERIES" ] && ! is_supported_series "$KERNEL_SERIES"; then
        print_colored "${RED}" "$(get_string unsupported_series)"
        exit 1
    fi
}

# Check the distribution and supported release range
check_system() {
    print_colored "${CYAN}" "$(get_string checking_system)"

    if [ ! -r /etc/os-release ]; then
        print_colored "${RED}" "$(get_string not_debian_based)"
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID=${ID:-}
    DISTRO_VERSION_MAJOR=""

    case "$DISTRO_ID" in
        debian)
            DISTRO_FAMILY=deb
            DISTRO_VERSION_MAJOR=${VERSION_ID%%.*}
            if [[ ! "$DISTRO_VERSION_MAJOR" =~ ^[0-9]+$ ]] || \
               [ "$DISTRO_VERSION_MAJOR" -lt 11 ]; then
                print_colored "${RED}" "$(get_string debian_version_too_old) ${VERSION_ID:-unknown}"
                exit 1
            fi
            ;;
        ubuntu)
            DISTRO_FAMILY=deb
            DISTRO_VERSION_MAJOR=${VERSION_ID%%.*}
            local ubuntu_minor=${VERSION_ID#*.}
            ubuntu_minor=${ubuntu_minor%%.*}
            if [[ ! "$DISTRO_VERSION_MAJOR" =~ ^[0-9]+$ ]] || \
               [[ ! "$ubuntu_minor" =~ ^[0-9]+$ ]] || \
               [ "$DISTRO_VERSION_MAJOR" -lt 20 ] || \
               { [ "$DISTRO_VERSION_MAJOR" -eq 20 ] && [ "$ubuntu_minor" -lt 4 ]; }; then
                print_colored "${RED}" "$(get_string ubuntu_version_too_old) ${VERSION_ID:-unknown}"
                exit 1
            fi
            ;;
        fedora)
            DISTRO_FAMILY=rpm
            DISTRO_VERSION_MAJOR=${VERSION_ID%%.*}
            if [[ ! "$DISTRO_VERSION_MAJOR" =~ ^[0-9]+$ ]] || \
               [ "$DISTRO_VERSION_MAJOR" -lt 43 ] || [ "$DISTRO_VERSION_MAJOR" -gt 44 ]; then
                print_colored "${RED}" "$(get_string not_debian_based)"
                exit 1
            fi
            ;;
        rhel|rocky|centos|almalinux|ol)
            DISTRO_FAMILY=rpm
            DISTRO_VERSION_MAJOR=${VERSION_ID%%.*}
            if [[ ! "$DISTRO_VERSION_MAJOR" =~ ^[0-9]+$ ]] || \
               [ "$DISTRO_VERSION_MAJOR" -lt 9 ] || [ "$DISTRO_VERSION_MAJOR" -gt 10 ]; then
                print_colored "${RED}" "$(get_string not_debian_based)"
                exit 1
            fi
            ;;
        alpine)
            DISTRO_FAMILY=apk
            case "${VERSION_ID:-}" in
                3.21|3.21.*|3.22|3.22.*|3.23|3.23.*|3.24|3.24.*) ;;
                *)
                    print_colored "${RED}" "$(get_string not_debian_based)"
                    exit 1
                    ;;
            esac
            ;;
        arch)
            DISTRO_FAMILY=pacman
            ;;
        *)
            print_colored "${RED}" "$(get_string not_debian_based)"
            exit 1
            ;;
    esac

    print_colored "${GREEN}" "✓ ${PRETTY_NAME:-$DISTRO_ID}"
}

# Check system architecture
check_arch() {
    print_colored "${CYAN}" "$(get_string architecture_check)"

    local machine
    machine=$(uname -m)

    case "$machine" in
        x86_64|amd64)
            ARCH=amd64
            RPM_ARCH=x86_64
            ;;
        aarch64|arm64)
            ARCH=arm64
            RPM_ARCH=aarch64
            ;;
        *)
            print_colored "${RED}" "$(get_string architecture_not_supported)"
            print_colored "${RED}" "$(get_string detected_arch) $machine"
            exit 1
            ;;
    esac

    if [ "$DISTRO_FAMILY" = pacman ] && [ "$ARCH" != amd64 ]; then
        print_colored "${RED}" "$(get_string arch_linux_x86_only)"
        print_colored "${RED}" "$(get_string detected_arch) $machine"
        exit 1
    fi

    print_colored "${GREEN}" "✓ $machine"
}

# Fetch available releases from GitHub
fetch_releases() {
    print_colored "${CYAN}" "$(get_string fetching_releases)"
    print_colored "${CYAN}" "$(get_string using_series) $KERNEL_SERIES"


    # Get up to 100 releases so older maintained series remain selectable
    local releases_json
    if ! releases_json=$(curl -fsSL "${REPO_API}/releases?per_page=100"); then
        print_colored "${RED}" "$(get_string fetch_error)"
        exit 1
    fi

    if [ -z "$releases_json" ]; then
        print_colored "${RED}" "$(get_string fetch_error)"
        exit 1
    fi

    # Use the most recent asset upload time instead of the release publication
    # time. Fall back for releases that do not contain assets.
    local releases_info
    releases_info=$(jq -r '
        .[]
        | "\(.tag_name)|\((([.assets[]?.created_at] | max) // .published_at // .created_at))"
    ' <<< "$releases_json")

    if [ -z "$releases_info" ] || [ "$releases_info" = "null" ]; then
        print_colored "${RED}" "$(get_string no_releases)"
        exit 1
    fi

    # Filter releases by the selected series and system architecture
    local filtered_releases=()
    local series_pattern="${KERNEL_SERIES//./\\.}"
    local release_line tag base_tag asset_upload_time

    while IFS= read -r release_line; do
        tag="${release_line%%|*}"
        asset_upload_time="${release_line#*|}"
        asset_upload_time="${asset_upload_time/T/ }"
        asset_upload_time="${asset_upload_time%Z}"
        base_tag="${tag%-arm64}"

        if [[ ! "$base_tag" =~ ^${series_pattern}\.[0-9]+$ ]]; then
            continue
        fi

        if [ "$ARCH" = "amd64" ] && [[ "$tag" != *"-arm64" ]]; then
            filtered_releases+=("$tag|$asset_upload_time")
        elif [ "$ARCH" = "arm64" ] && [[ "$tag" = *"-arm64" ]]; then
            filtered_releases+=("$tag|$asset_upload_time")
        fi
    done <<< "$releases_info"

    if [ "${#filtered_releases[@]}" -eq 0 ]; then
        print_colored "${RED}" "$(get_string no_series_releases) $KERNEL_SERIES / $ARCH"
        exit 1
    fi

    # Use a requested full version from the selected series
    if [ -n "$SPECIFIED_VERSION" ]; then
        local version_tag="$SPECIFIED_VERSION"
        local release found=false

        if [ "$ARCH" = "arm64" ]; then
            version_tag="${SPECIFIED_VERSION}-arm64"
        fi

        for release in "${filtered_releases[@]}"; do
            tag="${release%%|*}"
            if [ "$tag" = "$version_tag" ]; then
                SELECTED_TAG="$tag"
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            print_colored "${YELLOW}" "$(get_string version_not_found) $version_tag"
            print_colored "${YELLOW}" "$(get_string using_auto_version)"
            SELECTED_TAG="${filtered_releases[0]%%|*}"
        fi

        print_colored "${GREEN}" "✓ $(get_string using_version) $SELECTED_TAG"
        return
    fi

    # Automatic mode installs the latest release within the selected series
    if [ "$COMMAND" = "install" ]; then
        SELECTED_TAG="${filtered_releases[0]%%|*}"
        print_colored "${GREEN}" "✓ $(get_string auto_install): $SELECTED_TAG"
        return
    fi

    # Display the versions available within the selected series
    print_colored "${YELLOW}" "$(get_string select_version)"
    echo ""

    local i=0 release build_time
    for release in "${filtered_releases[@]}"; do
        tag="${release%%|*}"
        build_time="${release#*|}"

        if [ "$i" -eq 0 ]; then
            print_colored "${GREEN}" "$i) ${tag} - $(get_string build_time): ${build_time} ($(get_string latest_recommended))"
        else
            echo "$i) ${tag} - $(get_string build_time): ${build_time}"
        fi

        ((i++))
    done

    echo ""
    local choice
    read -r -p "$(get_string enter_choice) [0-$((i - 1))]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#filtered_releases[@]}" ]; then
        SELECTED_TAG="${filtered_releases[$choice]%%|*}"
    else
        SELECTED_TAG="${filtered_releases[0]%%|*}"
    fi

    print_colored "${GREEN}" "✓ $(get_string selected) $SELECTED_TAG"
}

# Download kernel packages
download_packages() {
    print_header "$(get_string downloading)"
    DOWNLOAD_DIR="./cloud-kernels/${SELECTED_TAG}/${DISTRO_ID}-${ARCH}"

    # Always start with an empty target-specific directory so stale packages
    # from an earlier release can never be installed with the selected one.
    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    print_colored "${CYAN}" "$(get_string created_dir) $DOWNLOAD_DIR"

    local release_json assets_json
    release_json=$(curl -fsSL "${REPO_API}/releases/tags/${SELECTED_TAG}")

    case "$DISTRO_FAMILY" in
        deb)
            assets_json=$(jq -r '.assets[] | select(.name | endswith(".deb")) | select(.name | test("linux-(headers|image|libc-dev)")) | .browser_download_url' <<< "$release_json")
            ;;
        rpm)
            assets_json=$(jq -r \
                --arg arch "$RPM_ARCH" \
                '.assets[] | select(.name | test("^kernel-cloud-bbrv3(-devel)?-")) | select(.name | endswith("." + $arch + ".rpm")) | .browser_download_url' \
                <<< "$release_json")
            ;;
        apk)
            assets_json=$(jq -r \
                --arg key "$APK_PUBLIC_KEY_NAME" \
                '.assets[] | select(((.name | endswith(".apk")) and (.name | test("^linux-cloud-bbrv3(-dev)?-"))) or (.name == $key)) | .browser_download_url' \
                <<< "$release_json")
            ;;
        pacman)
            assets_json=$(jq -r \
                '.assets[] | select(.name | test("^linux-cloud-bbrv3(-headers)?-[0-9].*-x86_64\\.pkg\\.tar\\.zst(\\.sig)?$")) | .browser_download_url' \
                <<< "$release_json")
            ;;
        *)
            assets_json=""
            ;;
    esac

    local common_assets
    common_assets=$(jq -r \
        --arg manifest "$CHECKSUM_MANIFEST_NAME" \
        --arg signature "$CHECKSUM_SIGNATURE_NAME" \
        --arg public_key "$SIGNING_PUBLIC_KEY_NAME" \
        '.assets[] | select(.name == $manifest or .name == $signature or .name == $public_key) | .browser_download_url' \
        <<< "$release_json")
    assets_json=$(printf '%s\n%s\n' "$assets_json" "$common_assets" | sed '/^$/d')

    if [ -z "$assets_json" ]; then
        print_colored "${RED}" "$(get_string download_failed)"
        exit 1
    fi

    local package_url filename
    while IFS= read -r package_url; do
        filename=$(basename "$package_url")
        print_colored "${CYAN}" "$(get_string downloading_file) $filename"
        if ! curl -L "$package_url" -o "${DOWNLOAD_DIR}/${filename}" --progress-bar; then
            print_colored "${RED}" "$(get_string download_failed)"
            exit 1
        fi
    done <<< "$assets_json"

    verify_downloads

    print_colored "${GREEN}" "$(get_string download_success)"
    detect_kernel_release
}

# Derive the exact kernel release, including CONFIG_LOCALVERSION, from the
# downloaded package metadata or installed package metadata.
detect_kernel_release() {
    KERNEL_RELEASE=""

    case "$DISTRO_FAMILY" in
        deb)
            local image_deb=""
            while IFS= read -r image_deb; do
                [ -n "$image_deb" ] || continue
                local name
                name=$(basename "$image_deb")
                name="${name#linux-image-}"
                name="${name%%_*}"
                if [ -n "$name" ]; then
                    KERNEL_RELEASE="$name"
                    break
                fi
            done < <(find "$DOWNLOAD_DIR" -name 'linux-image-*.deb' ! -name '*-dbg_*.deb' | sort)
            ;;
        rpm)
            local main_rpm=""
            main_rpm=$(find "$DOWNLOAD_DIR" -name 'kernel-cloud-bbrv3-[0-9]*.rpm' | sort | sed -n '1p')
            if [ -n "$main_rpm" ]; then
                KERNEL_RELEASE=$(rpm -qp --provides "$main_rpm" \
                    | sed -n 's/^kernel-uname-r = //p' | sed -n '1p')
            fi
            ;;
        apk)
            if [ -r /usr/share/kernel/cloud-bbrv3/kernel.release ]; then
                KERNEL_RELEASE=$(cat /usr/share/kernel/cloud-bbrv3/kernel.release)
            fi
            ;;
        pacman)
            local main_arch_package=""
            main_arch_package=$(find "$DOWNLOAD_DIR" \
                -name 'linux-cloud-bbrv3-[0-9]*.pkg.tar.zst' | sort | sed -n '1p')
            if [ -n "$main_arch_package" ]; then
                KERNEL_RELEASE=$(bsdtar -tf "$main_arch_package" \
                    | sed -n 's#^\(\./\)\?usr/lib/modules/\([^/]*\)/pkgbase$#\2#p' \
                    | sed -n '1p')
            fi
            ;;
    esac

    if [ -z "$KERNEL_RELEASE" ]; then
        return
    fi

    print_colored "${CYAN}" "$(get_string kernel_release) $KERNEL_RELEASE"

    local base_version="${SELECTED_TAG%-arm64}"
    local suffix="${KERNEL_RELEASE#"$base_version"}"
    suffix="${suffix#-}"

    if [ -n "$suffix" ]; then
        print_colored "${GREEN}" "✓ $(get_string suffix_detected) -$suffix"
    else
        print_colored "${YELLOW}" "$(get_string no_suffix_warning)"
    fi
}

# Ensure the newly installed kernel becomes the extlinux boot default.
# Alpine's kernel packages carry no bootloader integration of their own
# (upstream linux-lts/linux-virt ship no install= trigger); the syslinux
# package's own /boot trigger regenerates extlinux.conf on every kernel
# install, but it only honors whatever "default=" flavor is already
# pinned in /etc/update-extlinux.conf (typically the stock virt/lts
# flavor), so a freshly installed cloud-bbrv3 kernel is added to the
# boot menu but never becomes the default without this step.
configure_apk_boot_default() {
    local extlinux_conf="/etc/update-extlinux.conf"
    if [ ! -f "$extlinux_conf" ]; then
        print_colored "${YELLOW}" "$(get_string apk_boot_default_skip)"
        return
    fi

    if grep -q '^default=' "$extlinux_conf"; then
        run_as_root sed -i 's/^default=.*/default=cloud-bbrv3/' "$extlinux_conf"
    else
        run_as_root sh -c "printf 'default=cloud-bbrv3\n' >> '$extlinux_conf'"
    fi
    run_as_root update-extlinux --warn-only
    print_colored "${GREEN}" "✓ $(get_string apk_boot_default_set) cloud-bbrv3"
}

# Install kernel packages
install_packages() {
    print_header "$(get_string installing)"

    case "$DISTRO_FAMILY" in
        deb)
            local install_cmd=(dpkg -i)
            if [ "$(id -u)" -ne 0 ]; then
                install_cmd=(sudo dpkg -i)
            fi

            local deb
            local headers=()
            mapfile -t headers < <(find "$DOWNLOAD_DIR" -name 'linux-headers*.deb')
            for deb in "${headers[@]}"; do
                print_colored "${CYAN}" "Installing: $(basename "$deb")"
                "${install_cmd[@]}" "$deb" || {
                    print_colored "${RED}" "$(get_string install_failed)"
                    exit 1
                }
            done

            local libc_dev=()
            mapfile -t libc_dev < <(find "$DOWNLOAD_DIR" -name 'linux-libc-dev*.deb')
            for deb in "${libc_dev[@]}"; do
                print_colored "${CYAN}" "Installing: $(basename "$deb")"
                "${install_cmd[@]}" "$deb" || {
                    print_colored "${RED}" "$(get_string install_failed)"
                    exit 1
                }
            done

            local images=()
            mapfile -t images < <(find "$DOWNLOAD_DIR" -name 'linux-image*.deb')
            for deb in "${images[@]}"; do
                print_colored "${CYAN}" "Installing: $(basename "$deb")"
                "${install_cmd[@]}" "$deb" || {
                    print_colored "${RED}" "$(get_string install_failed)"
                    exit 1
                }
            done
            ;;
        rpm)
            local rpm_packages=()
            mapfile -t rpm_packages < <(find "$DOWNLOAD_DIR" -name '*.rpm' | sort)
            if [ "${#rpm_packages[@]}" -eq 0 ] || \
               ! run_as_root dnf install -y "${rpm_packages[@]}"; then
                print_colored "${RED}" "$(get_string install_failed)"
                exit 1
            fi
            ;;
        apk)
            local apk_key apk_packages=()
            for apk_key in "$DOWNLOAD_DIR"/*.rsa.pub; do
                [ -e "$apk_key" ] || continue
                run_as_root install -Dm644 "$apk_key" "/etc/apk/keys/$(basename "$apk_key")"
            done
            mapfile -t apk_packages < <(find "$DOWNLOAD_DIR" -name '*.apk' | sort)
            if [ "${#apk_packages[@]}" -eq 0 ] || \
               ! run_as_root apk add "${apk_packages[@]}"; then
                print_colored "${RED}" "$(get_string install_failed)"
                exit 1
            fi
            detect_kernel_release
            configure_apk_boot_default
            ;;
        pacman)
            local arch_packages=()
            mapfile -t arch_packages < <(find "$DOWNLOAD_DIR" -name '*.pkg.tar.zst' | sort)
            if [ "${#arch_packages[@]}" -eq 0 ] || \
               ! run_as_root pacman -U --noconfirm "${arch_packages[@]}"; then
                print_colored "${RED}" "$(get_string install_failed)"
                exit 1
            fi
            ;;
    esac

    print_colored "${GREEN}" "$(get_string install_success)"

    local boot_image=""
    case "$DISTRO_FAMILY" in
        deb|rpm) boot_image="/boot/vmlinuz-${KERNEL_RELEASE}" ;;
        apk) boot_image=/boot/vmlinuz-cloud-bbrv3 ;;
        pacman) boot_image=/boot/vmlinuz-linux-cloud-bbrv3 ;;
    esac
    if [ -n "$KERNEL_RELEASE" ] && [ -e "$boot_image" ]; then
        print_colored "${GREEN}" "✓ $(get_string boot_entry_found) $boot_image"
    elif [ -n "$boot_image" ]; then
        print_colored "${YELLOW}" "$(get_string boot_entry_missing) $boot_image"
    fi

    rm -rf "$DOWNLOAD_DIR"

    if [ "$AUTO_REBOOT" = false ]; then
        print_colored "${YELLOW}" "$(get_string skip_reboot)"
        return
    fi

    if [ "$COMMAND" != "install" ]; then
        local reboot_choice
        read -r -p "$(get_string reboot_prompt)" reboot_choice
        if [[ ! "$reboot_choice" =~ ^[Yy]$ ]]; then
            print_colored "${YELLOW}" "$(get_string skip_reboot)"
            return
        fi
    fi

    print_colored "${YELLOW}" "$(get_string rebooting)"
    run_as_root reboot
}

# Show help message
show_help() {
    print_header "$(get_string help_title)"

    get_string help_usage
    echo "  $0 [options] [command]"
    echo ""

    get_string help_commands
    echo "  $(get_string help_install)"
    echo "  $(get_string help_help)"
    echo ""

    get_string help_options
    get_string help_language
    echo ""

    get_string help_install_options
    get_string help_series
    get_string help_version
    get_string help_no_reboot
    get_string help_signing_fingerprint
    echo ""

    get_string help_examples
    get_string help_example1
    echo "  $0 -l en install --series 6.18"
    echo ""
    get_string help_example2
    echo "  $0 install --series 6.12 --version 6.12.21 --no-reboot"
    echo ""

    exit 0
}

# Parse command line arguments
parse_args() {
    local current_arg=""
    local i=1

    while [ "$i" -le "$#" ]; do
        current_arg="${!i}"

        case "$current_arg" in
            -l|--language)
                i=$((i + 1))
                if [ "$i" -gt "$#" ]; then
                    print_colored "${RED}" "$(get_string missing_option_value) $current_arg"
                    exit 1
                fi
                case "${!i}" in
                    zh|en)
                        LANGUAGE="${!i}"
                        ;;
                    *)
                        LANGUAGE="zh"
                        ;;
                esac
                ;;
            install)
                COMMAND="install"
                ;;
            help)
                COMMAND="help"
                ;;
            -s|--series|--kernel-series)
                i=$((i + 1))
                if [ "$i" -gt "$#" ]; then
                    print_colored "${RED}" "$(get_string missing_option_value) $current_arg"
                    exit 1
                fi
                KERNEL_SERIES="${!i}"
                ;;
            -v|--version)
                i=$((i + 1))
                if [ "$i" -gt "$#" ]; then
                    print_colored "${RED}" "$(get_string missing_option_value) $current_arg"
                    exit 1
                fi
                SPECIFIED_VERSION="${!i}"
                ;;
            -a|--no-reboot)
                AUTO_REBOOT=false
                ;;
            --signing-fingerprint)
                i=$((i + 1))
                if [ "$i" -gt "$#" ]; then
                    print_colored "${RED}" "$(get_string missing_option_value) $current_arg"
                    exit 1
                fi
                TRUSTED_GPG_FINGERPRINT="${!i}"
                ;;
        esac

        i=$((i + 1))
    done

    if [ -z "$COMMAND" ]; then
        COMMAND="interactive"
    fi

    if [ "$COMMAND" != "help" ]; then
        validate_kernel_selection
    fi
}

# ==========================================================================
# Main Execution
# ==========================================================================

main() {
    parse_args "$@"

    if [ "$COMMAND" = "help" ]; then
        show_help
    fi

    check_root

    if [ "$COMMAND" = "interactive" ]; then
        select_language
        if [ -z "$KERNEL_SERIES" ]; then
            select_kernel_series
        else
            print_colored "${GREEN}" "✓ $(get_string using_series) $KERNEL_SERIES"
        fi
    fi

    print_header "$(get_string welcome)"
    check_system
    update_package_index
    check_arch
    install_dependency curl
    install_dependency jq
    fetch_releases
    download_packages
    install_packages
}

# Run main only when the script is executed directly
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    main "$@"
fi