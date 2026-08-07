#!/usr/bin/env bash
# u-install common library
# shellcheck shell=bash

UI_NAME="u-install"
UI_VERSION="0.0.1-alpha"
UI_CONFIG_DIR="${HOME}/.config/u-install"
UI_DATA_DIR="${HOME}/.local/share/u-install"
UI_DB="${UI_DATA_DIR}/db/installed"

# Colors
if [[ -t 1 ]]; then
    UI_RED='\033[0;31m'
    UI_GREEN='\033[0;32m'
    UI_YELLOW='\033[1;33m'
    UI_BLUE='\033[0;34m'
    UI_CYAN='\033[0;36m'
    UI_NC='\033[0m'
else
    UI_RED=''
    UI_GREEN=''
    UI_YELLOW=''
    UI_BLUE=''
    UI_CYAN=''
    UI_NC=''
fi

ui_info()  { printf "${UI_CYAN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_ok()    { printf "${UI_GREEN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_warn()  { printf "${UI_YELLOW}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_err()   { printf "${UI_RED}[${UI_NAME}]${UI_NC} %s\n" "$1" >&2; }

ui_detect_distro() {
    if command -v pacman >/dev/null 2>&1; then
        echo "arch"
    elif command -v apt >/dev/null 2>&1; then
        echo "debian"
    elif command -v dnf >/dev/null 2>&1; then
        echo "fedora"
    elif command -v zypper >/dev/null 2>&1; then
        echo "suse"
    elif command -v apk >/dev/null 2>&1; then
        echo "alpine"
    elif command -v xbps-install >/dev/null 2>&1; then
        echo "void"
    elif command -v emerge >/dev/null 2>&1; then
        echo "gentoo"
    else
        echo "unknown"
    fi
}

ui_ensure_db() {
    if [[ ! -d "$(dirname "$UI_DB")" ]]; then
        mkdir -p "$(dirname "$UI_DB")"
    fi
    if [[ ! -f "$UI_DB" ]]; then
        touch "$UI_DB"
    fi
}

ui_db_add() {
    local pkg="$1"
    local source="$2"
    ui_ensure_db
    echo "${pkg}|${source}|$(date +%Y-%m-%d)" >> "$UI_DB"
}

ui_db_remove() {
    local pkg="$1"
    ui_ensure_db
    grep -v "^${pkg}|" "$UI_DB" > "${UI_DB}.tmp" || true
    mv "${UI_DB}.tmp" "$UI_DB"
}

ui_db_get_source() {
    local pkg="$1"
    ui_ensure_db
    grep "^${pkg}|" "$UI_DB" | tail -n1 | cut -d'|' -f2
}

# Critical packages that must only be updated through the native PM
ui_critical_packages=(
    "linux" "linux-lts" "linux-zen" "linux-hardened" "linux-firmware"
    "kernel" "kernels" "kmod" "mkinitcpio" "dracut"
    "grub" "systemd-boot" "efibootmgr" "limine" "syslinux"
    "systemd" "systemd-sysvcompat" "openrc" "runit"
    "glibc" "musl" "gcc-libs" "clang-libs"
    "nvidia" "nvidia-lts" "nvidia-utils" "mesa"
    "btrfs-progs" "lvm2" "mdadm" "cryptsetup"
    "networkmanager" "iwd" "wpa_supplicant" "dhcpcd"
    "bash" "coreutils" "util-linux" "shadow" "sudo" "doas"
)

ui_is_critical() {
    local pkg="$1"
    for crit in "${ui_critical_packages[@]}"; do
        if [[ "$pkg" == "$crit" ]]; then
            return 0
        fi
    done
    return 1
}
