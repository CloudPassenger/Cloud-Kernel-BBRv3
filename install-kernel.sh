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
REPO_API="https://api.github.com/repos/CloudPassenger/Cloud-Kernel-BBRv3"
DOWNLOAD_DIR="./cloud-kernels"
ARCH=""
LANGUAGE="zh"  # Default language: Chinese
SELECTED_TAG=""
IS_ROOT=false
AUTO_REBOOT=true
SPECIFIED_VERSION=""
COMMAND=""

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
STRINGS[en,not_debian_based]="Error: This system is not Debian-based. Only Debian and Ubuntu are supported."
STRINGS[en,debian_version_too_old]="Error: Debian version must be 11 or higher. Detected version:"
STRINGS[en,ubuntu_version_too_old]="Error: Ubuntu version must be 20.04 or higher. Detected version:"
STRINGS[en,architecture_check]="Checking system architecture..."
STRINGS[en,architecture_not_supported]="Error: Your system architecture is not supported. Only amd64 (x86_64) and arm64 (aarch64) are supported."
STRINGS[en,detected_arch]="Detected architecture:"
STRINGS[en,fetching_releases]="Fetching available kernel releases..."
STRINGS[en,fetch_error]="Error fetching releases. Please check your internet connection and try again."
STRINGS[en,no_releases]="No releases found in the repository."
STRINGS[en,select_version]="Select kernel version to install:"
STRINGS[en,latest_recommended]="Latest version!"
STRINGS[en,downloading]="Downloading kernel packages..."
STRINGS[en,created_dir]="Created download directory:"
STRINGS[en,downloading_file]="Downloading:"
STRINGS[en,download_success]="Successfully downloaded all kernel packages."
STRINGS[en,download_failed]="Failed to download one or more kernel packages."
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
STRINGS[en,updating_apt]="Updating APT package list..."
STRINGS[en,apt_updated]="APT package list updated successfully."
STRINGS[en,version_not_found]="Error: Specified version not found."
STRINGS[en,using_auto_version]="Using latest available version instead."
STRINGS[en,help_title]="Cloud Kernel BBRv3 Installer - Help"
STRINGS[en,help_usage]="Usage:"
STRINGS[en,help_commands]="Commands:"
STRINGS[en,help_install]="install    Install the kernel"
STRINGS[en,help_help]="help       Show this help message"
STRINGS[en,help_options]="Options:"
STRINGS[en,help_language]="  -l, --language    Set language (zh/en)"
STRINGS[en,help_install_options]="Options for 'install' command:"
STRINGS[en,help_version]="  -v, --version     Specify kernel version"
STRINGS[en,help_no_reboot]="  -a, --no-reboot   Skip reboot after installation"
STRINGS[en,help_examples]="Examples:"
STRINGS[en,help_example1]="  Install latest kernel with English interface:"
STRINGS[en,help_example2]="  Install specific kernel version without reboot:"
STRINGS[en,auto_install]="Automatic installation mode"
STRINGS[en,using_version]="Using kernel version:"

# Chinese strings
STRINGS[zh,welcome]="欢迎使用 Cloud Kernel BBRv3 安装程序"
STRINGS[zh,language_selection]="请选择您的语言："
STRINGS[zh,english]="English"
STRINGS[zh,chinese]="简体中文"
STRINGS[zh,checking_system]="正在检查系统兼容性..."
STRINGS[zh,not_debian_based]="错误：此系统不是基于 Debian 的系统。仅支持 Debian 和 Ubuntu。"
STRINGS[zh,debian_version_too_old]="错误：Debian 版本必须为 11 或更高。检测到的版本："
STRINGS[zh,ubuntu_version_too_old]="错误：Ubuntu 版本必须为 20.04 或更高。检测到的版本："
STRINGS[zh,architecture_check]="正在检查系统架构..."
STRINGS[zh,architecture_not_supported]="错误：您的系统架构不受支持。仅支持 amd64 (x86_64) 和 arm64 (aarch64)。"
STRINGS[zh,detected_arch]="检测到的架构："
STRINGS[zh,fetching_releases]="正在获取可用的内核版本..."
STRINGS[zh,fetch_error]="获取版本失败。请检查您的网络连接并重试。"
STRINGS[zh,no_releases]="在存储库中未找到版本。"
STRINGS[zh,select_version]="选择要安装的内核版本："
STRINGS[zh,latest_recommended]="最新版本！"
STRINGS[zh,downloading]="正在下载内核包..."
STRINGS[zh,created_dir]="已创建下载目录："
STRINGS[zh,downloading_file]="正在下载："
STRINGS[zh,download_success]="成功下载所有内核包。"
STRINGS[zh,download_failed]="下载一个或多个内核包失败。"
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
STRINGS[zh,updating_apt]="正在更新 APT 软件源..."
STRINGS[zh,apt_updated]="APT 软件源更新成功。"
STRINGS[zh,version_not_found]="错误：未找到指定版本。"
STRINGS[zh,using_auto_version]="将使用最新可用版本。"
STRINGS[zh,help_title]="Cloud Kernel BBRv3 安装程序 - 帮助"
STRINGS[zh,help_usage]="用法："
STRINGS[zh,help_commands]="命令："
STRINGS[zh,help_install]="install    安装内核"
STRINGS[zh,help_help]="help       显示此帮助信息"
STRINGS[zh,help_options]="选项："
STRINGS[zh,help_language]="  -l, --language    设置语言 (zh/en)"
STRINGS[zh,help_install_options]="'install' 命令的选项："
STRINGS[zh,help_version]="  -v, --version     指定内核版本"
STRINGS[zh,help_no_reboot]="  -a, --no-reboot   安装后不重启"
STRINGS[zh,help_examples]="示例："
STRINGS[zh,help_example1]="  使用英文界面安装最新内核："
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
    if [ "$(id -u)" -eq 0 ]; then
        IS_ROOT=true
    elif command -v sudo >/dev/null 2>&1; then
        IS_ROOT=true
    else
        print_colored "${RED}" "$(get_string sudo_not_installed)"
        print_colored "${YELLOW}" "$(get_string root_required)"
        print_colored "${YELLOW}" "$(get_string run_as_root)"
        echo "  sudo $0"
        echo "  or"
        echo "  su -c \"$0\""
        exit 1
    fi
}

# Update apt
update_apt() {
    print_colored "${CYAN}" "$(get_string updating_apt)"
    if [ "$IS_ROOT" = true ]; then
        apt-get update
    else
        sudo apt-get update
    fi
    print_colored "${GREEN}" "$(get_string apt_updated)"
}

# Install a dependency package
install_dependency() {
    local package="$1"
    
    if ! command -v "$package" >/dev/null 2>&1; then
        print_colored "${CYAN}" "$(get_string installing_dependecies) $package"
        
        if [ "$IS_ROOT" = true ]; then
            if [ "$(id -u)" -eq 0 ]; then
                apt-get install -y "$package"
            else
                sudo apt-get install -y "$package"
            fi
        else
            print_colored "${RED}" "$(get_string root_required)"
            exit 1
        fi
        
        print_colored "${GREEN}" "$(get_string dependency_installed)"
    fi
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
    read -p "Enter choice / 请输入选择 [1-2]: " choice
    
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

# Check if system is Debian-based and version requirements
check_system() {
    print_colored "${CYAN}" "$(get_string checking_system)"
    
    # Check if system is Debian-based
    if [ ! -f /etc/debian_version ]; then
        if ! command -v apt-get >/dev/null 2>&1; then
            print_colored "${RED}" "$(get_string not_debian_based)"
            exit 1
        fi
    fi
    
    # Install required dependencies
    install_dependency "bc"
    
    # Check Debian version
    if grep -q "Debian" /etc/issue; then
        version=$(cat /etc/debian_version)
        major_version=${version%%.*}
        if [ "$major_version" -lt 11 ]; then
            print_colored "${RED}" "$(get_string debian_version_too_old) $version"
            exit 1
        fi
    fi
    
    # Check Ubuntu version
    if grep -q "Ubuntu" /etc/issue; then
        # Install lsb-release if not installed
        install_dependency "lsb-release"
        
        version=$(lsb_release -rs)
        if [ "$(echo "$version < 20.04" | bc)" -eq 1 ]; then
            print_colored "${RED}" "$(get_string ubuntu_version_too_old) $version"
            exit 1
        fi
    fi
    
    # Install lsb-release if not installed
    install_dependency "lsb-release"
    
    print_colored "${GREEN}" "✓ $(lsb_release -is) $(lsb_release -rs)"
}

# Check system architecture
check_arch() {
    print_colored "${CYAN}" "$(get_string architecture_check)"
    
    local machine=$(uname -m)
    
    case "$machine" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            print_colored "${RED}" "$(get_string architecture_not_supported)"
            print_colored "${RED}" "$(get_string detected_arch) $machine"
            exit 1
            ;;
    esac
    
    print_colored "${GREEN}" "✓ $ARCH"
}

# Fetch available releases from GitHub
fetch_releases() {
    print_colored "${CYAN}" "$(get_string fetching_releases)"
    
    # Install curl and jq if not installed
    install_dependency "curl"
    install_dependency "jq"
    
    # Get releases
    local releases_json
    releases_json=$(curl -s "${REPO_API}/releases")
    
    if [ $? -ne 0 ] || [ -z "$releases_json" ]; then
        print_colored "${RED}" "$(get_string fetch_error)"
        exit 1
    fi
    
    # Extract tags and published times using jq
    local releases_info
    releases_info=$(echo "$releases_json" | jq -r '.[] | "\(.tag_name)|\(.published_at)"')
    
    if [ -z "$releases_info" ] || [ "$releases_info" == "null" ]; then
        print_colored "${RED}" "$(get_string no_releases)"
        exit 1
    fi
    
    # Filter releases based on architecture
    local filtered_releases=()
    
    while IFS= read -r release_line; do
        local tag=$(echo "$release_line" | cut -d'|' -f1)
        local published_time=$(echo "$release_line" | cut -d'|' -f2 | sed 's/T/ /g' | sed 's/Z$//')
        
        if [ "$ARCH" = "amd64" ] && ! [[ "$tag" == *"-arm64" ]]; then
            filtered_releases+=("$tag|$published_time")
        elif [ "$ARCH" = "arm64" ] && [[ "$tag" == *"-arm64" ]]; then
            filtered_releases+=("$tag|$published_time")
        fi
    done <<< "$releases_info"
    
    # If a specific version was requested
    if [ -n "$SPECIFIED_VERSION" ]; then
        local version_tag=""
        
        if [ "$ARCH" = "amd64" ]; then
            version_tag="$SPECIFIED_VERSION"
        elif [ "$ARCH" = "arm64" ]; then
            version_tag="${SPECIFIED_VERSION}-arm64"
        fi
        
        local found=false
        
        for release in "${filtered_releases[@]}"; do
            local tag=$(echo "$release" | cut -d'|' -f1)
            if [ "$tag" = "$version_tag" ]; then
                SELECTED_TAG="$tag"
                found=true
                break
            fi
        done
        
        if [ "$found" = false ]; then
            print_colored "${YELLOW}" "$(get_string version_not_found) $version_tag"
            print_colored "${YELLOW}" "$(get_string using_auto_version)"
            SELECTED_TAG=$(echo "${filtered_releases[0]}" | cut -d'|' -f1)
        fi
        
        print_colored "${GREEN}" "✓ $(get_string using_version) $SELECTED_TAG"
        return
    fi
    
    # If automatic installation was selected
    if [ "$COMMAND" = "install" ]; then
        SELECTED_TAG=$(echo "${filtered_releases[0]}" | cut -d'|' -f1)
        print_colored "${GREEN}" "✓ $(get_string auto_install): $SELECTED_TAG"
        return
    fi
    
    # Display menu for tag selection
    print_colored "${YELLOW}" "$(get_string select_version)"
    echo ""
    
    local i=0
    for release in "${filtered_releases[@]}"; do
        local tag=$(echo "$release" | cut -d'|' -f1)
        local build_time=$(echo "$release" | cut -d'|' -f2)
        
        if [ "$i" -eq 0 ]; then
            print_colored "${GREEN}" "$i) ${tag} - $(get_string build_time): ${build_time} ($(get_string latest_recommended))"
        else
            echo "$i) ${tag} - $(get_string build_time): ${build_time}"
        fi
        
        ((i++))
    done
    
    echo ""
    echo -n "$(get_string enter_choice) [0-$((i-1))]: "
    local choice
    read choice
    
    # Set selected tag
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt ${#filtered_releases[@]} ]; then
        SELECTED_TAG=$(echo "${filtered_releases[$choice]}" | cut -d'|' -f1)
    else
        SELECTED_TAG=$(echo "${filtered_releases[0]}" | cut -d'|' -f1)
    fi
    
    print_colored "${GREEN}" "✓ Selected: $SELECTED_TAG"
}

# Download kernel packages
download_packages() {
    print_header "$(get_string downloading)"
    
    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    print_colored "${CYAN}" "$(get_string created_dir) $DOWNLOAD_DIR"
    
    # Get release assets using jq
    local assets_json
    assets_json=$(curl -s "${REPO_API}/releases/tags/${SELECTED_TAG}" | jq -r '.assets[] | select(.name | endswith(".deb")) | select(.name | test("linux-(headers|image|libc-dev)")) | .browser_download_url')
    
    if [ -z "$assets_json" ]; then
        print_colored "${RED}" "$(get_string download_failed)"
        exit 1
    fi
    
    # Download packages
    while IFS= read -r deb_url; do
        local filename=$(basename "$deb_url")
        print_colored "${CYAN}" "$(get_string downloading_file) $filename"
        curl -L "$deb_url" -o "${DOWNLOAD_DIR}/${filename}" --progress-bar
        
        if [ $? -ne 0 ]; then
            print_colored "${RED}" "$(get_string download_failed)"
            exit 1
        fi
    done <<< "$assets_json"
    
    print_colored "${GREEN}" "$(get_string download_success)"
}

# Install kernel packages
install_packages() {
    print_header "$(get_string installing)"
    
    local install_cmd="dpkg -i"
    if [ "$(id -u)" -ne 0 ]; then
        install_cmd="sudo dpkg -i"
    fi
    
    # First install headers
    local headers=($(find "$DOWNLOAD_DIR" -name "linux-headers*.deb"))
    for deb in "${headers[@]}"; do
        print_colored "${CYAN}" "Installing: $(basename "$deb")"
        $install_cmd "$deb"
        
        if [ $? -ne 0 ]; then
            print_colored "${RED}" "$(get_string install_failed)"
            exit 1
        fi
    done
    
    # Then install libc-dev
    local libc_dev=($(find "$DOWNLOAD_DIR" -name "linux-libc-dev*.deb"))
    for deb in "${libc_dev[@]}"; do
        print_colored "${CYAN}" "Installing: $(basename "$deb")"
        $install_cmd "$deb"
        
        if [ $? -ne 0 ]; then
            print_colored "${RED}" "$(get_string install_failed)"
            exit 1
        fi
    done
    
    # Finally install image
    local images=($(find "$DOWNLOAD_DIR" -name "linux-image*.deb"))
    for deb in "${images[@]}"; do
        print_colored "${CYAN}" "Installing: $(basename "$deb")"
        $install_cmd "$deb"
        
        if [ $? -ne 0 ]; then
            print_colored "${RED}" "$(get_string install_failed)"
            exit 1
        fi
    done
    
    print_colored "${GREEN}" "$(get_string install_success)"
    
    # Handle reboot based on AUTO_REBOOT flag
    if [ "$AUTO_REBOOT" = false ]; then
        print_colored "${YELLOW}" "$(get_string skip_reboot)"
        return
    fi
    
    # Ask for reboot if not in automatic mode
    if [ "$COMMAND" != "install" ]; then
        local reboot_choice
        read -p "$(get_string reboot_prompt)" reboot_choice
        if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
            print_colored "${YELLOW}" "$(get_string rebooting)"
            if [ "$(id -u)" -eq 0 ]; then
                reboot
            else
                sudo reboot
            fi
        else
            print_colored "${YELLOW}" "$(get_string skip_reboot)"
        fi
    else
        # Automatic reboot in automatic mode
        print_colored "${YELLOW}" "$(get_string rebooting)"
        if [ "$(id -u)" -eq 0 ]; then
            reboot
        else
            sudo reboot
        fi
    fi
}

# Show help message
show_help() {
    print_header "$(get_string help_title)"
    
    echo "$(get_string help_usage)"
    echo "  $0 [options] [command]"
    echo ""
    
    echo "$(get_string help_commands)"
    echo "  $(get_string help_install)"
    echo "  $(get_string help_help)"
    echo ""
    
    echo "$(get_string help_options)"
    echo "$(get_string help_language)"
    echo ""
    
    echo "$(get_string help_install_options)"
    echo "$(get_string help_version)"
    echo "$(get_string help_no_reboot)"
    echo ""
    
    echo "$(get_string help_examples)"
    echo "$(get_string help_example1)"
    echo "  $0 -l en install"
    echo ""
    echo "$(get_string help_example2)"
    echo "  $0 install -v 6.12.21 -a"
    echo ""
    
    exit 0
}

# Parse command line arguments
parse_args() {
    local current_arg=""
    local i=1
    
    while [ $i -le $# ]; do
        current_arg="${!i}"
        
        case "$current_arg" in
            -l|--language)
                i=$((i+1))
                if [ $i -le $# ]; then
                    case "${!i}" in
                        zh|en)
                            LANGUAGE="${!i}"
                            ;;
                        *)
                            LANGUAGE="zh"
                            ;;
                    esac
                fi
                ;;
            install)
                COMMAND="install"
                ;;
            help)
                COMMAND="help"
                ;;
            -v|--version)
                if [ "$COMMAND" = "install" ]; then
                    i=$((i+1))
                    if [ $i -le $# ]; then
                        SPECIFIED_VERSION="${!i}"
                    fi
                fi
                ;;
            -a|--no-reboot)
                if [ "$COMMAND" = "install" ]; then
                    AUTO_REBOOT=false
                fi
                ;;
        esac
        
        i=$((i+1))
    done
    
    # Default to help if no command specified
    if [ -z "$COMMAND" ]; then
        COMMAND="interactive"
    fi
}

# ==========================================================================
# Main Execution
# ==========================================================================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Show help if requested
    if [ "$COMMAND" = "help" ]; then
        show_help
    fi
    
    # Check for root privileges
    check_root
    
    # Update apt
    update_apt
    
    # Interactive mode - select language
    if [ "$COMMAND" = "interactive" ]; then
        select_language
    fi
    
    # Display header
    print_header "$(get_string welcome)"
    
    # Check system compatibility
    check_system
    check_arch
    
    # Fetch and select release
    fetch_releases
    
    # Download packages
    download_packages
    
    # Install packages
    install_packages
}

# Run the main function with all arguments
main "$@" 