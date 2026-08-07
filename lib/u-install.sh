#!/usr/bin/env bash
# u-install common library
# shellcheck shell=bash

UI_NAME="u-install"
UI_VERSION="1.1.0"
UI_CONFIG_DIR="${HOME}/.config/u-install"
UI_CONFIG_FILE="${UI_CONFIG_DIR}/u-install.conf"
UI_DATA_DIR="${HOME}/.local/share/u-install"
UI_DB="${UI_DATA_DIR}/db/installed"
UI_AUR_DIR="${HOME}/.local/share/u-install/aur"

# Defaults
UI_PARALLEL_DOWNLOADS=3
UI_AUTO_YES=0
UI_PREFER_SOURCE="auto"
UI_COLORS=1
UI_LOG_LEVEL="info"
UI_MAX_AUR_PARALLEL=2
UI_CLEANUP_AFTER_BUILD=0
UI_NIX_CHANNEL="nixpkgs"

# Colors
ui_setup_colors() {
    if [[ -t 1 && "$UI_COLORS" -eq 1 ]]; then
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
}

ui_info()  { [[ "$UI_LOG_LEVEL" =~ ^(debug|info)$ ]] && printf "${UI_CYAN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_ok()    { [[ "$UI_LOG_LEVEL" =~ ^(debug|info)$ ]] && printf "${UI_GREEN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_warn()  { [[ "$UI_LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && printf "${UI_YELLOW}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_err()   { printf "${UI_RED}[${UI_NAME}]${UI_NC} %s\n" "$1" >&2; }
ui_debug() { [[ "$UI_LOG_LEVEL" == "debug" ]] && printf "${UI_BLUE}[${UI_NAME}:debug]${UI_NC} %s\n" "$1"; }

ui_parse_config() {
    if [[ -f "$UI_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            value="${value//\~\//$HOME/}"
            case "$key" in
                parallel_downloads) UI_PARALLEL_DOWNLOADS="$value" ;;
                aur_build_dir) UI_AUR_DIR="$value" ;;
                auto_yes) [[ "$value" == "true" ]] && UI_AUTO_YES=1 || UI_AUTO_YES=0 ;;
                prefer_source) UI_PREFER_SOURCE="$value" ;;
                colors) [[ "$value" == "true" ]] && UI_COLORS=1 || UI_COLORS=0 ;;
                log_level) UI_LOG_LEVEL="$value" ;;
                max_aur_builds_parallel) UI_MAX_AUR_PARALLEL="$value" ;;
                cleanup_after_build) [[ "$value" == "true" ]] && UI_CLEANUP_AFTER_BUILD=1 || UI_CLEANUP_AFTER_BUILD=0 ;;
                nix_channel) UI_NIX_CHANNEL="$value" ;;
            esac
        done < "$UI_CONFIG_FILE"
    fi
    ui_setup_colors
}

ui_ensure_dirs() {
    mkdir -p "${UI_DATA_DIR}/db" "${UI_AUR_DIR}" "${UI_CONFIG_DIR}"
}

ui_ensure_db() {
    ui_ensure_dirs
    if [[ ! -f "$UI_DB" ]]; then
        touch "$UI_DB"
    fi
}

ui_db_add() {
    local pkg="$1"
    local source="$2"
    ui_ensure_db
    if grep -q "^${pkg}|" "$UI_DB" 2>/dev/null; then
        grep -v "^${pkg}|" "$UI_DB" > "${UI_DB}.tmp" 2>/dev/null || true
        mv "${UI_DB}.tmp" "$UI_DB"
    fi
    echo "${pkg}|${source}|$(date +%Y-%m-%d)" >> "$UI_DB"
}

ui_db_remove() {
    local pkg="$1"
    ui_ensure_db
    if grep -q "^${pkg}|" "$UI_DB" 2>/dev/null; then
        grep -v "^${pkg}|" "$UI_DB" > "${UI_DB}.tmp" 2>/dev/null || true
        mv "${UI_DB}.tmp" "$UI_DB"
    fi
}

ui_db_get_source() {
    local pkg="$1"
    ui_ensure_db
    grep "^${pkg}|" "$UI_DB" 2>/dev/null | tail -n1 | cut -d'|' -f2
}

ui_db_list() {
    ui_ensure_db
    cat "$UI_DB"
}

ui_db_count() {
    ui_ensure_db
    wc -l < "$UI_DB" | tr -d ' '
}

ui_db_count_by_source() {
    local src="$1"
    ui_ensure_db
    grep "|${src}|" "$UI_DB" 2>/dev/null | wc -l | tr -d ' '
}

# Critical packages: only update through native PM
ui_critical_packages=(
    "linux" "linux-lts" "linux-zen" "linux-hardened" "linux-firmware"
    "kernel" "kernels" "kmod" "mkinitcpio" "dracut"
    "grub" "grub2" "systemd-boot" "efibootmgr" "limine" "syslinux"
    "systemd" "systemd-sysvcompat" "openrc" "runit"
    "glibc" "musl" "gcc-libs" "clang-libs"
    "nvidia" "nvidia-lts" "nvidia-utils" "nvidia-settings" "mesa"
    "btrfs-progs" "lvm2" "mdadm" "cryptsetup"
    "networkmanager" "iwd" "wpa_supplicant" "dhcpcd"
    "bash" "coreutils" "util-linux" "shadow" "sudo" "doas"
    "polkit" "dbus" "udev" "eudev"
    "glibc-locales" "tzdata" "iana-etc"
    "mkinitcpio" "initramfs" "initramfs-tools"
    "linux-api-headers" "linux-headers"
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

ui_has_nix() {
    command -v nix-env >/dev/null 2>&1
}

ui_ensure_nix() {
    if ui_has_nix; then
        return 0
    fi
    ui_info "Nix not found. Installing Nix (single-user, no root required)..."
    if ! command -v curl >/dev/null 2>&1; then
        ui_err "curl is required to install Nix."
        return 1
    fi
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
    if [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
        # shellcheck source=/dev/null
        . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
    fi
    if ! ui_has_nix; then
        ui_err "Nix installation failed or requires shell restart."
        return 1
    fi
    ui_ok "Nix installed successfully."
}

ui_nix_install() {
    local pkg="$1"
    ui_ensure_nix || return 1
    ui_info "Installing '${pkg}' via Nix..."
    nix-env -iA "${UI_NIX_CHANNEL}.${pkg}"
}

ui_nix_uninstall() {
    local pkg="$1"
    if ! ui_has_nix; then
        ui_err "Nix is not installed."
        return 1
    fi
    ui_info "Removing '${pkg}' via Nix..."
    nix-env -e "$pkg"
}

ui_nix_update_all() {
    if ! ui_has_nix; then
        ui_warn "Nix is not installed. Skipping Nix updates."
        return 0
    fi
    ui_info "Updating Nix channels..."
    nix-channel --update
    ui_info "Upgrading Nix packages..."
    nix-env -u
}

ui_nix_update_pkg() {
    local pkg="$1"
    if ! ui_has_nix; then
        return 1
    fi
    nix-env -u "$pkg"
}

ui_nix_pkg_size() {
    local pkg="$1"
    if ! ui_has_nix; then
        echo "0"
        return
    fi
    local out_path
    out_path=$(nix-env -q --out-path "$pkg" 2>/dev/null | awk '{print $2}')
    if [[ -n "$out_path" && -d "$out_path" ]]; then
        du -sb "$out_path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

ui_is_arch() {
    [[ "$(ui_detect_distro)" == "arch" ]]
}

ui_has_aur_helper_deps() {
    command -v git >/dev/null 2>&1 && command -v makepkg >/dev/null 2>&1
}

ui_aur_install() {
    local pkg="$1"
    if ! ui_is_arch; then
        ui_err "AUR is only supported on Arch-based distributions."
        return 1
    fi
    if ! ui_has_aur_helper_deps; then
        ui_err "AUR requires 'git' and 'base-devel' (makepkg)."
        return 1
    fi
    local aur_path="${UI_AUR_DIR}/${pkg}"
    ui_info "Cloning AUR package '${pkg}'..."
    rm -rf "$aur_path"
    if ! git clone "https://aur.archlinux.org/${pkg}.git" "$aur_path"; then
        ui_err "Failed to clone AUR package '${pkg}'."
        return 1
    fi
    (
        cd "$aur_path"
        ui_info "Building AUR package '${pkg}'..."
        makepkg --noconfirm -si
    )
    if [[ "$UI_CLEANUP_AFTER_BUILD" -eq 1 ]]; then
        ui_info "Cleaning up AUR build files for '${pkg}'..."
        rm -rf "$aur_path"
    fi
}

ui_aur_uninstall() {
    local pkg="$1"
    if ! command -v pacman >/dev/null 2>&1; then
        ui_err "pacman is required to remove AUR packages."
        return 1
    fi
    ui_info "Removing AUR package '${pkg}' via pacman..."
    sudo pacman -Rns "$pkg"
}

ui_aur_update() {
    local pkg="$1"
    local aur_path="${UI_AUR_DIR}/${pkg}"
    if [[ ! -d "${aur_path}/.git" ]]; then
        ui_warn "AUR cache for '${pkg}' not found. Skipping."
        return 0
    fi
    (
        cd "$aur_path"
        ui_info "Checking AUR updates for '${pkg}'..."
        git fetch origin
        local local_hash
        local_hash=$(git rev-parse HEAD)
        local remote_hash
        remote_hash=$(git rev-parse origin/HEAD)
        if [[ "$local_hash" == "$remote_hash" ]]; then
            ui_info "AUR package '${pkg}' is up to date."
            return 0
        fi
        ui_info "Updating AUR package '${pkg}'..."
        git pull
        makepkg --noconfirm -si
    )
    if [[ "$UI_CLEANUP_AFTER_BUILD" -eq 1 ]]; then
        rm -rf "$aur_path"
    fi
}

ui_aur_check_updates() {
    local pkg="$1"
    local aur_path="${UI_AUR_DIR}/${pkg}"
    if [[ ! -d "${aur_path}/.git" ]]; then
        echo "unknown"
        return
    fi
    (
        cd "$aur_path"
        git fetch origin >/dev/null 2>&1
        local local_hash
        local_hash=$(git rev-parse HEAD)
        local remote_hash
        remote_hash=$(git rev-parse origin/HEAD)
        if [[ "$local_hash" != "$remote_hash" ]]; then
            echo "outdated"
        else
            echo "current"
        fi
    )
}

ui_detect_distro() {
    if command -v pacman >/dev/null 2>&1; then
        echo "arch"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "debian"
    elif command -v dnf >/dev/null 2>&1; then
        echo "fedora"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v zypper >/dev/null 2>&1; then
        echo "suse"
    elif command -v apk >/dev/null 2>&1; then
        echo "alpine"
    elif command -v xbps-install >/dev/null 2>&1; then
        echo "void"
    elif command -v emerge >/dev/null 2>&1; then
        echo "gentoo"
    elif command -v eopkg >/dev/null 2>&1; then
        echo "solus"
    elif command -v slackpkg >/dev/null 2>&1; then
        echo "slackware"
    elif command -v prt-get >/dev/null 2>&1; then
        echo "crux"
    elif command -v swupd >/dev/null 2>&1; then
        echo "clear"
    elif command -v guix >/dev/null 2>&1; then
        echo "guix"
    elif command -v pkg >/dev/null 2>&1 && [[ -d "/data/data/com.termux" ]]; then
        echo "termux"
    elif command -v nixos-rebuild >/dev/null 2>&1; then
        echo "nixos"
    else
        echo "unknown"
    fi
}

ui_native_install() {
    local pkg="$1"
    local distro
    distro=$(ui_detect_distro)
    case "$distro" in
        arch)
            ui_info "Installing '${pkg}' via pacman..."
            sudo pacman -S --needed --noconfirm "$pkg"
            ;;
        debian)
            ui_info "Installing '${pkg}' via apt..."
            sudo apt-get install -y "$pkg"
            ;;
        fedora|yum)
            if command -v dnf >/dev/null 2>&1; then
                ui_info "Installing '${pkg}' via dnf..."
                sudo dnf install -y "$pkg"
            else
                ui_info "Installing '${pkg}' via yum..."
                sudo yum install -y "$pkg"
            fi
            ;;
        suse)
            ui_info "Installing '${pkg}' via zypper..."
            sudo zypper install -y "$pkg"
            ;;
        alpine)
            ui_info "Installing '${pkg}' via apk..."
            doas apk add "$pkg" || sudo apk add "$pkg"
            ;;
        void)
            ui_info "Installing '${pkg}' via xbps..."
            sudo xbps-install -y "$pkg"
            ;;
        gentoo)
            ui_info "Installing '${pkg}' via emerge..."
            sudo emerge "$pkg"
            ;;
        solus)
            ui_info "Installing '${pkg}' via eopkg..."
            sudo eopkg install -y "$pkg"
            ;;
        slackware)
            ui_info "Installing '${pkg}' via slackpkg..."
            sudo slackpkg install "$pkg"
            ;;
        crux)
            ui_info "Installing '${pkg}' via prt-get..."
            sudo prt-get install "$pkg"
            ;;
        clear)
            ui_info "Installing '${pkg}' via swupd..."
            sudo swupd bundle-add "$pkg"
            ;;
        guix)
            ui_info "Installing '${pkg}' via guix..."
            guix package -i "$pkg"
            ;;
        termux)
            ui_info "Installing '${pkg}' via pkg..."
            pkg install -y "$pkg"
            ;;
        nixos)
            ui_info "Installing '${pkg}' via nix-env (NixOS native)..."
            nix-env -iA "nixpkgs.${pkg}"
            ;;
        *)
            ui_err "Unknown distribution. Cannot use native package manager."
            return 1
            ;;
    esac
}

ui_native_uninstall() {
    local pkg="$1"
    local distro
    distro=$(ui_detect_distro)
    case "$distro" in
        arch)
            ui_info "Removing '${pkg}' via pacman..."
            sudo pacman -Rns "$pkg"
            ;;
        debian)
            ui_info "Removing '${pkg}' via apt..."
            sudo apt-get remove --purge -y "$pkg"
            ;;
        fedora|yum)
            if command -v dnf >/dev/null 2>&1; then
                ui_info "Removing '${pkg}' via dnf..."
                sudo dnf remove -y "$pkg"
            else
                ui_info "Removing '${pkg}' via yum..."
                sudo yum remove -y "$pkg"
            fi
            ;;
        suse)
            ui_info "Removing '${pkg}' via zypper..."
            sudo zypper remove -y "$pkg"
            ;;
        alpine)
            ui_info "Removing '${pkg}' via apk..."
            doas apk del "$pkg" || sudo apk del "$pkg"
            ;;
        void)
            ui_info "Removing '${pkg}' via xbps..."
            sudo xbps-remove -y "$pkg"
            ;;
        gentoo)
            ui_info "Removing '${pkg}' via emerge..."
            sudo emerge --unmerge "$pkg"
            ;;
        solus)
            ui_info "Removing '${pkg}' via eopkg..."
            sudo eopkg remove -y "$pkg"
            ;;
        slackware)
            ui_info "Removing '${pkg}' via slackpkg..."
            sudo slackpkg remove "$pkg"
            ;;
        crux)
            ui_info "Removing '${pkg}' via prt-get..."
            sudo prt-get remove "$pkg"
            ;;
        clear)
            ui_info "Removing '${pkg}' via swupd..."
            sudo swupd bundle-remove "$pkg"
            ;;
        guix)
            ui_info "Removing '${pkg}' via guix..."
            guix package -r "$pkg"
            ;;
        termux)
            ui_info "Removing '${pkg}' via pkg..."
            pkg uninstall -y "$pkg"
            ;;
        nixos)
            ui_info "Removing '${pkg}' via nix-env (NixOS native)..."
            nix-env -e "$pkg"
            ;;
        *)
            ui_err "Unknown distribution. Cannot use native package manager."
            return 1
            ;;
    esac
}

ui_native_update() {
    local distro
    distro=$(ui_detect_distro)
    case "$distro" in
        arch)
            ui_info "Updating system via pacman..."
            sudo pacman -Syu --noconfirm
            ;;
        debian)
            ui_info "Updating system via apt..."
            sudo apt-get update && sudo apt-get full-upgrade -y
            ;;
        fedora|yum)
            if command -v dnf >/dev/null 2>&1; then
                ui_info "Updating system via dnf..."
                sudo dnf upgrade --refresh -y
            else
                ui_info "Updating system via yum..."
                sudo yum update -y
            fi
            ;;
        suse)
            ui_info "Updating system via zypper..."
            sudo zypper refresh && sudo zypper dup -y
            ;;
        alpine)
            ui_info "Updating system via apk..."
            doas apk upgrade || sudo apk upgrade
            ;;
        void)
            ui_info "Updating system via xbps..."
            sudo xbps-install -Su
            ;;
        gentoo)
            ui_info "Updating system via emerge..."
            sudo emerge --sync && sudo emerge -uDU @world
            ;;
        solus)
            ui_info "Updating system via eopkg..."
            sudo eopkg upgrade -y
            ;;
        slackware)
            ui_info "Updating system via slackpkg..."
            sudo slackpkg update && sudo slackpkg upgrade-all
            ;;
        crux)
            ui_info "Updating system via prt-get..."
            sudo prt-get sysup
            ;;
        clear)
            ui_info "Updating system via swupd..."
            sudo swupd update
            ;;
        guix)
            ui_info "Updating system via guix..."
            guix pull && guix package -u
            ;;
        termux)
            ui_info "Updating system via pkg..."
            pkg update && pkg upgrade -y
            ;;
        nixos)
            ui_info "Updating system via nixos-rebuild..."
            sudo nixos-rebuild switch --upgrade
            ;;
        *)
            ui_warn "Unknown distribution. Skipping system update."
            ;;
    esac
}

ui_native_search() {
    local pkg="$1"
    local distro
    distro=$(ui_detect_distro)
    case "$distro" in
        arch)
            pacman -Ss "^${pkg}$" >/dev/null 2>&1
            ;;
        debian)
            apt-cache show "$pkg" >/dev/null 2>&1
            ;;
        fedora|yum)
            if command -v dnf >/dev/null 2>&1; then
                dnf info "$pkg" >/dev/null 2>&1
            else
                yum info "$pkg" >/dev/null 2>&1
            fi
            ;;
        suse)
            zypper info "$pkg" >/dev/null 2>&1
            ;;
        alpine)
            apk info "$pkg" >/dev/null 2>&1
            ;;
        void)
            xbps-query -R "$pkg" >/dev/null 2>&1
            ;;
        gentoo)
            emerge -s "^${pkg}$" >/dev/null 2>&1
            ;;
        solus)
            eopkg info "$pkg" >/dev/null 2>&1
            ;;
        slackware)
            slackpkg search "$pkg" >/dev/null 2>&1
            ;;
        crux)
            prt-get info "$pkg" >/dev/null 2>&1
            ;;
        clear)
            swupd search "$pkg" >/dev/null 2>&1
            ;;
        guix)
            guix package -A "^${pkg}$" >/dev/null 2>&1
            ;;
        termux)
            pkg search "$pkg" >/dev/null 2>&1
            ;;
        nixos)
            nix-env -qaP "^${pkg}$" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

ui_nix_search() {
    local pkg="$1"
    ui_ensure_nix || return 1
    nix-env -qaP --json "^${pkg}$" 2>/dev/null | grep -q "$pkg"
}

ui_aur_search() {
    local pkg="$1"
    curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=${pkg}" 2>/dev/null | grep -q '"resultcount":[1-9]'
}

ui_confirm() {
    local msg="$1"
    local auto_yes_override="${2:-}"
    if [[ "$UI_AUTO_YES" -eq 1 || "$auto_yes_override" == "1" ]]; then
        return 0
    fi
    printf "%s [Y/n] " "$msg"
    local resp
    read -r resp
    case "$resp" in
        [Nn]*) return 1 ;;
        *) return 0 ;;
    esac
}

ui_human_size() {
    local bytes="$1"
    if [[ "$bytes" -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ "$bytes" -lt 1048576 ]]; then
        echo "$(echo "scale=1; $bytes/1024" | bc)KB"
    elif [[ "$bytes" -lt 1073741824 ]]; then
        echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
    else
        echo "$(echo "scale=1; $bytes/1073741824" | bc)GB"
    fi
}
