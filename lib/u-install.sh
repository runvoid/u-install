#!/usr/bin/env bash
# u-install common library v1.2.1
# shellcheck shell=bash
# The UI_* config globals below are populated here and consumed by the sourcing
# u-* command scripts, so ShellCheck can't see their cross-file use.
# shellcheck disable=SC2034

UI_NAME="u-install"
UI_VERSION="1.2.1"
UI_CONFIG_DIR="${HOME}/.config/u-install"
UI_CONFIG_FILE="${UI_CONFIG_DIR}/u-install.conf"
UI_DATA_DIR="${HOME}/.local/share/u-install"
UI_DB="${UI_DATA_DIR}/db/installed"
UI_AUR_DIR="${HOME}/.local/share/u-install/aur"
UI_BIN_DIR="${HOME}/.local/bin"
UI_EXPORT_FORMAT="u2"

UI_PARALLEL_DOWNLOADS=3
UI_AUTO_YES=0
UI_PREFER_SOURCE="auto"
UI_COLORS=1
UI_LOG_LEVEL="info"
UI_MAX_AUR_PARALLEL=2
UI_CLEANUP_AFTER_BUILD=0
UI_NIX_CHANNEL="nixpkgs"
UI_AUR_SECURITY_CHECK=1

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
ui_print_version() { printf "%s %s\n" "$(basename "$0")" "$UI_VERSION"; }

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
                aur_security_check) [[ "$value" == "true" ]] && UI_AUR_SECURITY_CHECK=1 || UI_AUR_SECURITY_CHECK=0 ;;
            esac
        done < "$UI_CONFIG_FILE"
    fi
    ui_setup_colors
}

ui_ensure_dirs() { mkdir -p "${UI_DATA_DIR}/db" "${UI_AUR_DIR}" "${UI_CONFIG_DIR}"; }
ui_ensure_db()   { ui_ensure_dirs; [[ -f "$UI_DB" ]] || touch "$UI_DB"; }

ui_db_add() {
    local pkg="$1" src="$2"
    ui_ensure_db
    grep -q "^${pkg}|" "$UI_DB" 2>/dev/null && { grep -v "^${pkg}|" "$UI_DB" > "${UI_DB}.tmp"; mv "${UI_DB}.tmp" "$UI_DB"; }
    echo "${pkg}|${src}|$(date +%Y-%m-%d)" >> "$UI_DB"
}

ui_db_remove() {
    local pkg="$1"
    ui_ensure_db
    grep -q "^${pkg}|" "$UI_DB" 2>/dev/null && { grep -v "^${pkg}|" "$UI_DB" > "${UI_DB}.tmp"; mv "${UI_DB}.tmp" "$UI_DB"; }
}

ui_db_get_source() { ui_ensure_db; grep "^${1}|" "$UI_DB" 2>/dev/null | tail -n1 | cut -d'|' -f2 || true; }
ui_db_list()       { ui_ensure_db; cat "$UI_DB"; }
ui_db_count()      { ui_ensure_db; wc -l < "$UI_DB" | tr -d ' '; }
ui_db_count_by_source() { ui_ensure_db; grep "|${1}|" "$UI_DB" 2>/dev/null | wc -l | tr -d ' ' || true; }

ui_critical_packages=(
    linux linux-lts linux-zen linux-hardened linux-firmware
    kernel kernels kmod mkinitcpio dracut
    grub grub2 systemd-boot efibootmgr limine syslinux
    systemd systemd-sysvcompat openrc runit
    glibc musl gcc-libs clang-libs
    nvidia nvidia-lts nvidia-utils nvidia-settings mesa
    btrfs-progs lvm2 mdadm cryptsetup
    networkmanager iwd wpa_supplicant dhcpcd
    bash coreutils util-linux shadow sudo doas
    polkit dbus udev eudev
    glibc-locales tzdata iana-etc
    initramfs initramfs-tools
    linux-api-headers linux-headers
)

ui_is_critical() {
    for c in "${ui_critical_packages[@]}"; do [[ "$1" == "$c" ]] && return 0; done
    return 1
}

ui_has_nix() { command -v nix-env >/dev/null 2>&1; }

ui_ensure_nix() {
    ui_has_nix && return 0
    ui_info "Nix not found. Installing Nix (single-user, no root required)..."
    command -v curl >/dev/null 2>&1 || { ui_err "curl is required"; return 1; }
    local missing=()
    command -v xz  >/dev/null 2>&1 || missing+=("xz")
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    if [[ ${#missing[@]} -gt 0 ]]; then
        ui_err "Nix installer requires: ${missing[*]}"
        ui_info "On Debian/Ubuntu: sudo apt-get install -y xz-utils tar"
        return 1
    fi
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
    [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]] && . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
    ui_has_nix || { ui_err "Nix installation failed"; return 1; }
    ui_ok "Nix installed."
}

ui_nix_install()   { local pkg="$1"; ui_ensure_nix || return 1; ui_info "Installing '${pkg}' via Nix..."; nix-env -iA "${UI_NIX_CHANNEL}.${pkg}"; }
ui_nix_uninstall() { local pkg="$1"; ui_has_nix || { ui_err "Nix not installed"; return 1; }; ui_info "Removing '${pkg}' via Nix..."; nix-env -e "$pkg"; }
ui_nix_update_all() {
    ui_has_nix || { ui_warn "Nix not installed"; return 0; }
    ui_info "Updating Nix channels..."; nix-channel --update
    ui_info "Upgrading Nix packages..."; nix-env -u
}
ui_nix_update_pkg() { ui_has_nix || return 1; nix-env -u "$1"; }

ui_nix_pkg_size() {
    ui_has_nix || { echo "0"; return; }
    local out_path; out_path=$(nix-env -q --out-path "$1" 2>/dev/null | awk '{print $2}')
    [[ -n "$out_path" && -d "$out_path" ]] && du -sb "$out_path" 2>/dev/null | cut -f1 || echo "0"
}

ui_is_arch() { [[ "$(ui_detect_distro)" == "arch" ]]; }
ui_has_aur_helper_deps() { command -v git >/dev/null 2>&1 && command -v makepkg >/dev/null 2>&1; }

ui_aur_security_scan() {
    local pkgbuild="$1"
    [[ -f "$pkgbuild" ]] || return 0
    grep -Eq 'curl.*\|.*(bash|sh|zsh)' "$pkgbuild" 2>/dev/null && echo "pipes remote download to shell"
    grep -Eq 'wget.*\|.*(bash|sh|zsh)' "$pkgbuild" 2>/dev/null && echo "pipes remote download to shell"
    grep -Eq 'rm -rf /($|[^/])' "$pkgbuild" 2>/dev/null && echo "dangerous rm -rf / pattern"
    grep -Eq 'dd if=/dev/zero' "$pkgbuild" 2>/dev/null && echo "disk wiping command"
    grep -Eq 'mkfs\.' "$pkgbuild" 2>/dev/null && echo "disk formatting command"
    grep -Eq '> /dev/sd[a-z]' "$pkgbuild" 2>/dev/null && echo "writes to block device"
    grep -Eq 'sudo ' "$pkgbuild" 2>/dev/null && echo "uses sudo in build"
    return 0
}

ui_aur_security_check() {
    local pkgbuild="$1"
    [[ "$UI_AUR_SECURITY_CHECK" -eq 0 ]] && return 0
    [[ -f "$pkgbuild" ]] || return 0
    local issues=()
    while IFS= read -r line; do [[ -n "$line" ]] && issues+=("$line"); done < <(ui_aur_security_scan "$pkgbuild")
    if [[ ${#issues[@]} -gt 0 ]]; then
        ui_warn "Security issues found in PKGBUILD:"
        for i in "${issues[@]}"; do ui_warn "  - $i"; done
        return 1
    fi
    return 0
}

ui_aur_install() {
    local pkg="$1"
    ui_is_arch || { ui_err "AUR requires Arch-based distro"; return 1; }
    ui_has_aur_helper_deps || { ui_err "AUR requires git and base-devel"; return 1; }
    local aur_path="${UI_AUR_DIR}/${pkg}"
    rm -rf "$aur_path"
    ui_info "Cloning AUR package '${pkg}'..."
    git clone "https://aur.archlinux.org/${pkg}.git" "$aur_path" || { ui_err "Clone failed"; return 1; }
    [[ -f "${aur_path}/PKGBUILD" ]] && { ui_aur_security_check "${aur_path}/PKGBUILD" || { ui_confirm "Security issues detected. Continue?" || { rm -rf "$aur_path"; return 1; }; }; }
    (cd "$aur_path" || exit 1; makepkg --noconfirm -si)
    [[ "$UI_CLEANUP_AFTER_BUILD" -eq 1 ]] && rm -rf "$aur_path"
}

ui_aur_uninstall() { command -v pacman >/dev/null 2>&1 || { ui_err "pacman required"; return 1; }; sudo pacman -Rns "$1"; }

ui_aur_update() {
    local pkg="$1" aur_path="${UI_AUR_DIR}/${pkg}"
    [[ -d "${aur_path}/.git" ]] || { ui_warn "AUR cache for '${pkg}' not found"; return 0; }
    (cd "$aur_path" || exit 1; git fetch origin; local_hash=$(git rev-parse HEAD); remote_hash=$(git rev-parse origin/HEAD)
    [[ "$local_hash" == "$remote_hash" ]] && { ui_info "AUR '${pkg}' is up to date"; return 0; }
    ui_info "Updating AUR '${pkg}'..."; git pull; makepkg --noconfirm -si)
    [[ "$UI_CLEANUP_AFTER_BUILD" -eq 1 ]] && rm -rf "$aur_path"
}

ui_aur_check_updates() {
    local pkg="$1" aur_path="${UI_AUR_DIR}/${pkg}"
    [[ -d "${aur_path}/.git" ]] || { echo "unknown"; return; }
    (cd "$aur_path" || exit 1; git fetch origin >/dev/null 2>&1
    [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/HEAD)" ]] && echo "outdated" || echo "current")
}

ui_detect_distro() {
    command -v pacman  >/dev/null 2>&1 && { echo "arch"; return; }
    command -v apt-get >/dev/null 2>&1 && { echo "debian"; return; }
    command -v dnf     >/dev/null 2>&1 && { echo "fedora"; return; }
    command -v yum     >/dev/null 2>&1 && { echo "yum"; return; }
    command -v zypper  >/dev/null 2>&1 && { echo "suse"; return; }
    command -v apk     >/dev/null 2>&1 && { echo "alpine"; return; }
    command -v xbps-install >/dev/null 2>&1 && { echo "void"; return; }
    command -v emerge  >/dev/null 2>&1 && { echo "gentoo"; return; }
    command -v eopkg   >/dev/null 2>&1 && { echo "solus"; return; }
    command -v slackpkg >/dev/null 2>&1 && { echo "slackware"; return; }
    command -v prt-get >/dev/null 2>&1 && { echo "crux"; return; }
    command -v swupd   >/dev/null 2>&1 && { echo "clear"; return; }
    command -v guix    >/dev/null 2>&1 && { echo "guix"; return; }
    command -v pkg     >/dev/null 2>&1 && [[ -d "/data/data/com.termux" ]] && { echo "termux"; return; }
    command -v nixos-rebuild >/dev/null 2>&1 && { echo "nixos"; return; }
    echo "unknown"
}

# Second argument is an optional exact version to pin. Only package managers
# that support it use the pin; the rest warn and fall back to the latest.
ui_native_install() {
    local pkg="$1" ver="${2:-}" distro; distro=$(ui_detect_distro)
    local spec="$pkg"
    case "$distro" in
        arch)   [[ -n "$ver" ]] && ui_warn "pacman: version pinning unsupported; installing latest '${pkg}'"; ui_info "Installing '${pkg}' via pacman..."; sudo pacman -S --needed --noconfirm "$pkg" ;;
        debian) [[ -n "$ver" ]] && spec="${pkg}=${ver}"; ui_info "Installing '${spec}' via apt..."; sudo apt-get install -y "$spec" ;;
        fedora|yum) [[ -n "$ver" ]] && spec="${pkg}-${ver}"; if command -v dnf >/dev/null 2>&1; then ui_info "Installing '${spec}' via dnf..."; sudo dnf install -y "$spec"; else ui_info "Installing '${spec}' via yum..."; sudo yum install -y "$spec"; fi ;;
        suse)   [[ -n "$ver" ]] && spec="${pkg}=${ver}"; ui_info "Installing '${spec}' via zypper..."; sudo zypper install -y "$spec" ;;
        alpine) ui_info "Installing '${pkg}' via apk..."; doas apk add "$pkg" || sudo apk add "$pkg" ;;
        void)   ui_info "Installing '${pkg}' via xbps..."; sudo xbps-install -y "$pkg" ;;
        gentoo) ui_info "Installing '${pkg}' via emerge..."; sudo emerge "$pkg" ;;
        solus)  ui_info "Installing '${pkg}' via eopkg..."; sudo eopkg install -y "$pkg" ;;
        slackware) ui_info "Installing '${pkg}' via slackpkg..."; sudo slackpkg install "$pkg" ;;
        crux)   ui_info "Installing '${pkg}' via prt-get..."; sudo prt-get install "$pkg" ;;
        clear)  ui_info "Installing '${pkg}' via swupd..."; sudo swupd bundle-add "$pkg" ;;
        guix)   ui_info "Installing '${pkg}' via guix..."; guix package -i "$pkg" ;;
        termux) ui_info "Installing '${pkg}' via pkg..."; pkg install -y "$pkg" ;;
        nixos)  ui_info "Installing '${pkg}' via nix-env..."; nix-env -iA "nixpkgs.${pkg}" ;;
        *)      ui_err "Unknown distribution"; return 1 ;;
    esac
}

ui_native_uninstall() {
    local pkg="$1" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   ui_info "Removing '${pkg}' via pacman..."; sudo pacman -Rns "$pkg" ;;
        debian) ui_info "Removing '${pkg}' via apt..."; sudo apt-get remove --purge -y "$pkg" ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then ui_info "Removing '${pkg}' via dnf..."; sudo dnf remove -y "$pkg"; else ui_info "Removing '${pkg}' via yum..."; sudo yum remove -y "$pkg"; fi ;;
        suse)   ui_info "Removing '${pkg}' via zypper..."; sudo zypper remove -y "$pkg" ;;
        alpine) ui_info "Removing '${pkg}' via apk..."; doas apk del "$pkg" || sudo apk del "$pkg" ;;
        void)   ui_info "Removing '${pkg}' via xbps..."; sudo xbps-remove -y "$pkg" ;;
        gentoo) ui_info "Removing '${pkg}' via emerge..."; sudo emerge --unmerge "$pkg" ;;
        solus)  ui_info "Removing '${pkg}' via eopkg..."; sudo eopkg remove -y "$pkg" ;;
        slackware) ui_info "Removing '${pkg}' via slackpkg..."; sudo slackpkg remove "$pkg" ;;
        crux)   ui_info "Removing '${pkg}' via prt-get..."; sudo prt-get remove "$pkg" ;;
        clear)  ui_info "Removing '${pkg}' via swupd..."; sudo swupd bundle-remove "$pkg" ;;
        guix)   ui_info "Removing '${pkg}' via guix..."; guix package -r "$pkg" ;;
        termux) ui_info "Removing '${pkg}' via pkg..."; pkg uninstall -y "$pkg" ;;
        nixos)  ui_info "Removing '${pkg}' via nix-env..."; nix-env -e "$pkg" ;;
        *)      ui_err "Unknown distribution"; return 1 ;;
    esac
}

ui_native_update() {
    local distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   ui_info "Updating system via pacman..."; sudo pacman -Syu --noconfirm ;;
        debian) ui_info "Updating system via apt..."; sudo apt-get update && sudo apt-get full-upgrade -y ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then ui_info "Updating system via dnf..."; sudo dnf upgrade --refresh -y; else ui_info "Updating system via yum..."; sudo yum update -y; fi ;;
        suse)   ui_info "Updating system via zypper..."; sudo zypper refresh && sudo zypper dup -y ;;
        alpine) ui_info "Updating system via apk..."; doas apk upgrade || sudo apk upgrade ;;
        void)   ui_info "Updating system via xbps..."; sudo xbps-install -Su ;;
        gentoo) ui_info "Updating system via emerge..."; sudo emerge --sync && sudo emerge -uDU @world ;;
        solus)  ui_info "Updating system via eopkg..."; sudo eopkg upgrade -y ;;
        slackware) ui_info "Updating system via slackpkg..."; sudo slackpkg update && sudo slackpkg upgrade-all ;;
        crux)   ui_info "Updating system via prt-get..."; sudo prt-get sysup ;;
        clear)  ui_info "Updating system via swupd..."; sudo swupd update ;;
        guix)   ui_info "Updating system via guix..."; guix pull && guix package -u ;;
        termux) ui_info "Updating system via pkg..."; pkg update && pkg upgrade -y ;;
        nixos)  ui_info "Updating system via nixos-rebuild..."; sudo nixos-rebuild switch --upgrade ;;
        *)      ui_warn "Unknown distribution. Skipping system update." ;;
    esac
}

ui_native_search() {
    local pkg="$1" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   pacman -Ss "^${pkg}$" >/dev/null 2>&1 ;;
        debian) apt-cache show "$pkg" >/dev/null 2>&1 ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then dnf info "$pkg" >/dev/null 2>&1; else yum info "$pkg" >/dev/null 2>&1; fi ;;
        suse)   zypper info "$pkg" >/dev/null 2>&1 ;;
        alpine) apk info "$pkg" >/dev/null 2>&1 ;;
        void)   xbps-query -R "$pkg" >/dev/null 2>&1 ;;
        gentoo) emerge -s "^${pkg}$" >/dev/null 2>&1 ;;
        solus)  eopkg info "$pkg" >/dev/null 2>&1 ;;
        slackware) slackpkg search "$pkg" >/dev/null 2>&1 ;;
        crux)   prt-get info "$pkg" >/dev/null 2>&1 ;;
        clear)  swupd search "$pkg" >/dev/null 2>&1 ;;
        guix)   guix package -A "^${pkg}$" >/dev/null 2>&1 ;;
        termux) pkg search "$pkg" >/dev/null 2>&1 ;;
        nixos)  nix-env -qaP "^${pkg}$" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

ui_native_search_version() {
    local pkg="$1" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   pacman -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        debian) apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2; exit}' ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then dnf info "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' | tr -d ' '; else yum info "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' | tr -d ' '; fi ;;
        suse)   zypper info "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        alpine) apk info "$pkg" 2>/dev/null | head -n1 | awk '{print $1}' | sed 's/.*-//' ;;
        void)   xbps-query -R "$pkg" 2>/dev/null | awk -F': ' '/^pkgver/{print $2; exit}' | tr -d ' ' ;;
        gentoo) emerge -s "^${pkg}$" 2>/dev/null | grep -m1 "${pkg}-" | sed 's/.*-//' | awk '{print $1}' ;;
        solus)  eopkg info "$pkg" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        *)      echo "" ;;
    esac
}

# Search must only probe an already-installed Nix; it must never trigger the
# Nix bootstrap (that is reserved for explicit installs via ui_ensure_nix).
ui_nix_search() { local pkg="$1"; ui_has_nix || return 1; nix-env -qaP --json "^${pkg}$" 2>/dev/null | grep -q "$pkg"; }

ui_nix_search_version() {
    local pkg="$1"
    ui_has_nix || { echo ""; return; }
    nix-env -qaP --json "^${pkg}$" 2>/dev/null | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4
}

ui_aur_search() { curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=${1}" 2>/dev/null | grep -q '"resultcount":[1-9]'; }

ui_aur_search_version() { curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=${1}" 2>/dev/null | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4; }

ui_aur_info_json() { curl -sf "https://aur.archlinux.org/rpc/v5/info?arg[]=${1}" 2>/dev/null; }

ui_json_str() { echo "$1" | grep -o "\"${2}\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

ui_json_num() { echo "$1" | grep -o "\"${2}\":[0-9.]*" | head -1 | cut -d':' -f2; }

ui_aur_pkgbuild_url() { echo "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${1}"; }

ui_aur_fetch_pkgbuild() { curl -sf "$(ui_aur_pkgbuild_url "$1")" -o "$2" 2>/dev/null; }

ui_confirm() {
    local msg="$1" auto="${2:-}"
    [[ "$UI_AUTO_YES" -eq 1 || "$auto" == "1" ]] && return 0
    printf "%s [Y/n] " "$msg"; local resp; read -r resp
    case "$resp" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

ui_human_size() {
    local b="$1"
    awk -v b="$b" 'BEGIN {
        split("B KB MB GB TB PB", u, " ")
        i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        if (i == 1) printf "%d%s\n", b, u[i]
        else printf "%.1f%s\n", b, u[i]
    }'
}

ui_self_update() {
    ui_info "Checking for updates..."
    local latest; latest=$(curl -sf "https://api.github.com/repos/runvoid/u-install/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    [[ -z "$latest" ]] && { ui_err "GitHub API unavailable"; return 1; }
    [[ "$latest" == "v${UI_VERSION}" ]] && { ui_ok "u-install is up to date (v${UI_VERSION})"; return 0; }
    ui_info "New version: ${latest} (current: v${UI_VERSION})"
    ui_confirm "Download and install ${latest}?" || return 0
    local tmpdir; tmpdir=$(mktemp -d)
    curl -Lf "https://github.com/runvoid/u-install/archive/refs/tags/${latest}.tar.gz" -o "${tmpdir}/update.tar.gz" || { ui_err "Download failed"; rm -rf "$tmpdir"; return 1; }
    tar xzf "${tmpdir}/update.tar.gz" -C "$tmpdir"
    local extracted="${tmpdir}/u-install-${latest#v}"
    [[ -d "$extracted" ]] || { ui_err "Extraction failed"; rm -rf "$tmpdir"; return 1; }
    ui_info "Installing update..."
    local tools=(u-install u-uninstall u-update u-stats u-doctor u-search u-peek u-list u-export u-import u-help)
    for t in "${tools[@]}"; do
        cp "${extracted}/${t}" "${UI_BIN_DIR}/${t}"
        chmod +x "${UI_BIN_DIR}/${t}"
    done
    cp "${extracted}/lib/u-install.sh" "${UI_DATA_DIR}/lib/"
    rm -rf "$tmpdir"
    ui_ok "Updated to ${latest}. Restart your terminal."
}

ui_install_group() {
    local group="$1"
    local profile_file="${UI_DATA_DIR}/profiles/${group}.txt"
    [[ -f "$profile_file" ]] || { ui_err "Group not found: @${group}"; ui_info "Searched: ${profile_file}"; return 1; }
    ui_info "Installing group: @${group}"
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        local pkg="$line" pflag=""
        [[ "$line" == *"--"* ]] && { pkg="$(echo "$line" | awk '{print $1}')"; pflag="$(echo "$line" | awk '{print $2}')"; }
        ui_info "Group: installing ${pkg} ${pflag}"
        if [[ -n "$pflag" ]]; then
            "${UI_BIN_DIR}/u-install" "$pflag" "$pkg" -y || ui_warn "Group: failed to install ${pkg}"
        else
            "${UI_BIN_DIR}/u-install" "$pkg" -y || ui_warn "Group: failed to install ${pkg}"
        fi
    done < "$profile_file"
}

# --- Configuration export / import (.u format) ---------------------------
# A .u file is a portable snapshot of the installer configuration and the list
# of tracked packages, so one machine can be reproduced on another with
# `u-import`. The format is line-based and greppable (see UI_EXPORT_FORMAT).
#
#   # u-install export
#   # format: u2
#   [meta]      -> version / exported date / hostname / sha256 (integrity)
#   [config]      -> installer options (key = value), applied to u-install.conf
#   [packages]    -> "name|source|version" per line, reinstalled via u-install
#   [meta].sha256 -> checksum of the package list, verified on import

ui_export_write() {
    ui_ensure_db
    printf '# u-install export\n'
    printf '# format: %s\n' "$UI_EXPORT_FORMAT"
    printf '\n[meta]\n'
    printf 'version=%s\n' "$UI_VERSION"
    printf 'exported=%s\n' "$(date +%Y-%m-%d)"
    printf 'hostname=%s\n' "${HOSTNAME:-unknown}"
    printf '\n[config]\n'
    if [[ -f "$UI_CONFIG_FILE" ]]; then
        grep -E '^[[:alnum:]_]+[[:space:]]*=' "$UI_CONFIG_FILE" || true
    fi
    printf '\n[packages]\n'
    local pkg src _ ver
    while IFS='|' read -r pkg src _; do
        [[ -z "$pkg" ]] && continue
        ver="$(ui_installed_version "$pkg" "$src")"
        printf '%s|%s|%s\n' "$pkg" "$src" "$ver"
    done < <(ui_db_list)
}

# Best-effort lookup of the currently-installed version of a package, used to
# pin versions in exported .u files. Returns an empty string when unknown.
ui_installed_version() {
    local pkg="$1" src="$2" distro
    case "$src" in
        nix)
            ui_has_nix || { echo ""; return 0; }
            nix-env -q 2>/dev/null | grep -m1 -- "^${pkg}-" | sed "s/^${pkg}-//" || true
            ;;
        *)
            distro="$(ui_detect_distro)"
            case "$distro" in
                arch)            pacman -Q "$pkg" 2>/dev/null | awk 'NR==1{print $2}' || true ;;
                debian)          dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || true ;;
                fedora|yum|suse) rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null || true ;;
                *)               echo "" ;;
            esac
            ;;
    esac
}

# Pipe data in, get its sha256 hex digest out (empty if no hasher available).
ui_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    fi
}

# Insert (or refresh) a sha256 of the [packages] section into [meta]. The
# checksum covers the package list only, so adding it to [meta] is stable.
ui_uf_sign() {
    local file="$1" sum tmp
    sum="$(ui_uf_section "$file" packages | ui_sha256)"
    [[ -z "$sum" ]] && return 0
    tmp="$(mktemp)"
    awk -v s="sha256=${sum}" '
        /^sha256=/ { next }
        { print }
        $0 == "[meta]" && !ins { print s; ins=1 }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Verify a signed .u file. Returns 0 on match, 1 on mismatch, 2 when the file
# is unsigned or no hasher is available (i.e. verification is not possible).
ui_uf_verify() {
    local file="$1" stored actual
    stored="$(ui_uf_section "$file" meta | awk -F= '/^sha256=/{print $2}')"
    [[ -z "$stored" ]] && return 2
    command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || return 2
    actual="$(ui_uf_section "$file" packages | ui_sha256)"
    [[ "$stored" == "$actual" ]]
}

ui_uf_format() {
    grep -m1 '^# format:' "$1" 2>/dev/null | awk '{print $3}'
}

ui_uf_section() {
    local file="$1" section="$2"
    awk -v s="[$section]" '
        $0 == s { inside = 1; next }
        /^\[/   { inside = 0; next }
        inside {
            line = $0
            sub(/^[ \t]+/, "", line)
            sub(/[ \t]+$/, "", line)
            if (line == "" || line ~ /^#/) next
            print line
        }
    ' "$file"
}

ui_import_apply_config() {
    local uf="$1" body
    body="$(ui_uf_section "$uf" config)"
    [[ -z "$body" ]] && return 1
    ui_ensure_dirs
    { printf '[options]\n'; printf '%s\n' "$body"; } > "$UI_CONFIG_FILE"
    return 0
}
