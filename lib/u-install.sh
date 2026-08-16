#!/usr/bin/env bash
# u-install common library v1.4.1
# shellcheck shell=bash
# shellcheck disable=SC2034

UI_NAME="u-install"
UI_VERSION="1.4.1"
UI_CONFIG_DIR="${HOME}/.config/u-install"
UI_CONFIG_FILE="${UI_CONFIG_DIR}/u-install.conf"
UI_DATA_DIR="${HOME}/.local/share/u-install"
UI_DB="${UI_DATA_DIR}/db/installed"
UI_HISTORY_FILE="${UI_DATA_DIR}/history.log"
UI_AUR_DIR="${HOME}/.local/share/u-install/aur"
UI_BIN_DIR="${HOME}/.local/bin"
UI_EXPORT_FORMAT="u3"
UI_CACHE_DIR="${UI_DATA_DIR}/cache"
UI_LAST_CHECK_FILE="${UI_DATA_DIR}/.last_update_check"

UI_AUTO_YES=0
UI_PREFER_SOURCE="auto"
UI_COLORS=1
UI_LOG_LEVEL="info"
UI_CLEANUP_AFTER_BUILD=0
UI_NIX_CHANNEL="nixpkgs"
UI_AUR_SECURITY_CHECK=1
UI_AUTO_UPDATE_CHECK=1
UI_UPDATE_CHECK_INTERVAL_DAYS=7

ui_setup_colors() {
    local utf=0
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]*) utf=1 ;; esac
    if [[ -t 1 && "$UI_COLORS" -eq 1 ]]; then
        UI_RED='\033[0;31m'
        UI_GREEN='\033[0;32m'
        UI_YELLOW='\033[1;33m'
        UI_BLUE='\033[0;34m'
        UI_CYAN='\033[0;36m'
        UI_DIM='\033[2m'
        UI_NC='\033[0m'
    else
        UI_RED=''
        UI_GREEN=''
        UI_YELLOW=''
        UI_BLUE=''
        UI_CYAN=''
        UI_DIM=''
        UI_NC=''
    fi
    # Status glyphs (v1.4.1): unicode when the locale supports it, ASCII otherwise.
    if [[ "$utf" -eq 1 ]]; then
        UI_G_OK='✓'
        UI_G_FAIL='✗'
        UI_G_WARN='⚠'
        UI_G_ARROW='→'
        UI_G_SKIP='–'
        UI_G_INFO='·'
    else
        UI_G_OK='+'
        UI_G_FAIL='x'
        UI_G_WARN='!'
        UI_G_ARROW='->'
        UI_G_SKIP='-'
        UI_G_INFO='.'
    fi
}

# Colorize a status word for table output (colors are empty off-tty).
ui_fmt_status() {
    case "$1" in
        available|"up to date") printf "${UI_GREEN}%-s${UI_NC}" "$1" ;;
        UPDATE)                printf "${UI_YELLOW}%-s${UI_NC}" "$1" ;;
        "not found")           printf "${UI_DIM}%-s${UI_NC}" "$1" ;;
        *)                     printf "${UI_CYAN}%-s${UI_NC}" "$1" ;;
    esac
}

ui_info()  { ui_progress_break; [[ "$UI_LOG_LEVEL" =~ ^(debug|info)$ ]] && printf "${UI_CYAN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_ok()    { ui_progress_break; [[ "$UI_LOG_LEVEL" =~ ^(debug|info)$ ]] && printf "${UI_GREEN}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_warn()  { ui_progress_break; [[ "$UI_LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && printf "${UI_YELLOW}[${UI_NAME}]${UI_NC} %s\n" "$1"; }
ui_err()   { ui_progress_break; printf "${UI_RED}[${UI_NAME}]${UI_NC} %s\n" "$1" >&2; }
ui_debug() { ui_progress_break; [[ "$UI_LOG_LEVEL" == "debug" ]] && printf "${UI_BLUE}[${UI_NAME}:debug]${UI_NC} %s\n" "$1"; }
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
                aur_build_dir) UI_AUR_DIR="$value" ;;
                auto_yes) [[ "$value" == "true" ]] && UI_AUTO_YES=1 || UI_AUTO_YES=0 ;;
                prefer_source) UI_PREFER_SOURCE="$value" ;;
                colors) [[ "$value" == "true" ]] && UI_COLORS=1 || UI_COLORS=0 ;;
                log_level) UI_LOG_LEVEL="$value" ;;
                cleanup_after_build) [[ "$value" == "true" ]] && UI_CLEANUP_AFTER_BUILD=1 || UI_CLEANUP_AFTER_BUILD=0 ;;
                nix_channel) UI_NIX_CHANNEL="$value" ;;
                aur_security_check) [[ "$value" == "true" ]] && UI_AUR_SECURITY_CHECK=1 || UI_AUR_SECURITY_CHECK=0 ;;
                auto_update_check) [[ "$value" == "true" ]] && UI_AUTO_UPDATE_CHECK=1 || UI_AUTO_UPDATE_CHECK=0 ;;
                update_check_interval_days)
                    if [[ "$value" =~ ^[0-9]+$ ]]; then
                        UI_UPDATE_CHECK_INTERVAL_DAYS="$value"
                    else
                        ui_warn "Config: update_check_interval_days must be a number; ignoring '${value}'"
                    fi
                    ;;
            esac
        done < "$UI_CONFIG_FILE"
    fi
    ui_setup_colors
}

ui_ensure_dirs() { mkdir -p "${UI_DATA_DIR}/db" "${UI_AUR_DIR}" "${UI_CONFIG_DIR}" "${UI_CACHE_DIR}"; }
ui_ensure_db()   { ui_ensure_dirs; [[ -f "$UI_DB" ]] || touch "$UI_DB"; }

ui_db_add() {
    local pkg="$1" src="$2"
    ui_ensure_db
    if awk -F'|' -v p="$pkg" '$1 == p {found=1} END {exit !found}' "$UI_DB"; then
        awk -F'|' -v p="$pkg" '$1 != p' "$UI_DB" > "${UI_DB}.tmp" && mv "${UI_DB}.tmp" "$UI_DB"
    fi
    echo "${pkg}|${src}|$(date +%Y-%m-%d)" >> "$UI_DB"
    ui_history_log install "$pkg" "$src"
}

ui_db_remove() {
    local pkg="$1" old_src
    ui_ensure_db
    old_src=$(awk -F'|' -v p="$pkg" '$1 == p {print $2; exit}' "$UI_DB" 2>/dev/null || true)
    if awk -F'|' -v p="$pkg" '$1 == p {found=1} END {exit !found}' "$UI_DB"; then
        awk -F'|' -v p="$pkg" '$1 != p' "$UI_DB" > "${UI_DB}.tmp" && mv "${UI_DB}.tmp" "$UI_DB"
        [[ -n "$old_src" ]] && ui_history_log remove "$pkg" "$old_src"
    fi
}

# Literal, regex-safe lookups: package names may contain +, ., [, ] etc.
ui_db_get_source() { ui_ensure_db; awk -F'|' -v p="$1" '$1 == p {v=$2} END {if (v != "") print v}' "$UI_DB" 2>/dev/null || true; }
ui_db_list()       { ui_ensure_db; cat "$UI_DB"; }
ui_db_count()      { ui_ensure_db; wc -l < "$UI_DB" | tr -d ' '; }
ui_db_count_by_source() { ui_ensure_db; awk -F'|' -v s="$1" '$2 == s {n++} END {print n+0}' "$UI_DB" 2>/dev/null || true; }

# --- History journal (v1.4.0) ---
ui_history_log() {
    local action="$1" pkg="$2" src="${3:-}"
    ui_ensure_dirs
    printf '%s|%s|%s|%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$action" "$pkg" "$src" >> "$UI_HISTORY_FILE"
}

ui_history_show() {
    local n="${1:-20}" pkg="${2:-}"
    [[ -f "$UI_HISTORY_FILE" ]] || { ui_info "No history yet."; return 0; }
    if [[ -n "$pkg" ]]; then
        awk -F'|' -v p="$pkg" '$3 == p' "$UI_HISTORY_FILE" | tail -n "$n"
    else
        tail -n "$n" "$UI_HISTORY_FILE"
    fi
}

# --- Small generic helpers (v1.4.0) ---
ui_count_lines() { if [[ -n "$1" ]]; then printf '%s\n' "$1" | wc -l; else echo 0; fi; }

# True when a "name|..." (or plain name) list contains the exact name.
ui_list_has() { printf '%s\n' "$1" | awk -F'|' -v p="$2" '$1 == p {f=1} END {exit !f}'; }

ui_urlencode() {
    local s="$1" out="" c i
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in
            [A-Za-z0-9.~_-]) out+="$c" ;;
            *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
        esac
    done
    printf '%s' "$out"
}

# Run a privileged command: directly when already root, doas when available
# (Alpine-style), sudo otherwise.
ui_priv() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        sudo "$@"
    fi
}

# Inline progress bar with a percentage, drawn on a tty only (stderr).
# Log functions call ui_progress_break, so bar and log lines never merge.
UI_PROGRESS_ACTIVE=0
ui_progress() {
    local cur="$1" total="$2" label="$3" pct bar="" i
    [[ -t 2 ]] || return 0
    if [[ "$total" -gt 0 ]]; then pct=$((cur * 100 / total)); else pct=100; fi
    for ((i = 0; i < 20; i++)); do
        if [[ "$i" -lt $((pct / 5)) ]]; then bar+="#"; else bar+="-"; fi
    done
    printf '\r\033[K  [%s] %3d%% %s' "$bar" "$pct" "$label" >&2
    UI_PROGRESS_ACTIVE=1
    return 0
}
ui_progress_break() {
    if [[ "$UI_PROGRESS_ACTIVE" -eq 1 && -t 2 ]]; then printf '\r\033[K' >&2; fi
    UI_PROGRESS_ACTIVE=0
    return 0
}
ui_progress_end() { ui_progress_break; }

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

# Guard against path traversal and injection before a package name is used in
# paths (AUR clone dir), URLs or package-manager arguments.
ui_valid_pkg_name() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9@._+-]*$ ]]
}

ui_has_nix() { command -v nix-env >/dev/null 2>&1; }

# nix-env -q prints "name-version" (e.g. "linux-6.1.0"); strip the version
# suffix to get the bare package name. Names whose suffix does not start with
# a digit ("nixpkgs-unstable") are left untouched.
ui_nix_strip_version() { printf '%s\n' "$1" | sed -E 's/-[0-9][0-9A-Za-z._+-]*$//'; }

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

# --- Enhanced AUR Security Scan (v1.3.0) ---
ui_aur_security_scan() {
    local pkgbuild="$1"
    [[ -f "$pkgbuild" ]] || return 0

    # Original checks
    grep -Eq 'curl.*\|.*(bash|sh|zsh)' "$pkgbuild" 2>/dev/null && echo "pipes remote download to shell"
    grep -Eq 'wget.*\|.*(bash|sh|zsh)' "$pkgbuild" 2>/dev/null && echo "pipes remote download to shell"
    grep -Eq 'rm -rf /($|[^/])' "$pkgbuild" 2>/dev/null && echo "dangerous rm -rf / pattern"
    grep -Eq 'dd if=/dev/zero' "$pkgbuild" 2>/dev/null && echo "disk wiping command"
    grep -Eq 'mkfs\.' "$pkgbuild" 2>/dev/null && echo "disk formatting command"
    grep -Eq '> /dev/sd[a-z]' "$pkgbuild" 2>/dev/null && echo "writes to block device"
    grep -Eq 'sudo ' "$pkgbuild" 2>/dev/null && echo "uses sudo in build"

    # New v1.3.0 checks
    grep -Eq 'eval\s*\$?\(' "$pkgbuild" 2>/dev/null && echo "eval with command substitution"
    grep -Eq 'eval\s*".*\$\(' "$pkgbuild" 2>/dev/null && echo "eval with embedded command substitution"
    grep -Eq 'source\s*<\s*\(' "$pkgbuild" 2>/dev/null && echo "sources from process substitution"
    grep -Eq 'source\s*\$\(' "$pkgbuild" 2>/dev/null && echo "sources from command substitution"
    grep -Eq 'base64\s*-d.*\|' "$pkgbuild" 2>/dev/null && echo "base64 decode piped to shell"
    grep -Eq 'base64\s*--decode.*\|' "$pkgbuild" 2>/dev/null && echo "base64 decode piped to shell"
    grep -Eq 'python[0-9]?\s+-c' "$pkgbuild" 2>/dev/null && echo "inline python execution"
    grep -Eq 'perl\s+-e' "$pkgbuild" 2>/dev/null && echo "inline perl execution"
    grep -Eq 'ruby\s+-e' "$pkgbuild" 2>/dev/null && echo "inline ruby execution"
    grep -Eq 'php\s+-r' "$pkgbuild" 2>/dev/null && echo "inline php execution"
    grep -Eq 'curl.*-o-.*\|.*sh' "$pkgbuild" 2>/dev/null && echo "curl to stdout piped to shell"
    grep -Eq 'wget.*-qO-.*\|.*sh' "$pkgbuild" 2>/dev/null && echo "wget to stdout piped to shell"
    grep -Eq '\bsystem\s*\(' "$pkgbuild" 2>/dev/null && echo "system() call detected"
    grep -Eq '\bexec\s+' "$pkgbuild" 2>/dev/null && echo "exec call detected"
    grep -Eq 'curl.*\|.*bash' "$pkgbuild" 2>/dev/null && echo "curl piped to bash"
    grep -Eq 'wget.*\|.*bash' "$pkgbuild" 2>/dev/null && echo "wget piped to bash"
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
    ui_valid_pkg_name "$pkg" || { ui_err "Invalid package name: '${pkg}'"; return 1; }
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

ui_aur_uninstall() { command -v pacman >/dev/null 2>&1 || { ui_err "pacman required"; return 1; }; ui_priv pacman -Rns --noconfirm "$1"; }

ui_aur_update() {
    local pkg="$1"
    local aur_path="${UI_AUR_DIR}/${pkg}"
    [[ -d "${aur_path}/.git" ]] || { ui_warn "AUR cache for '${pkg}' not found"; return 0; }
    (cd "$aur_path" || exit 1; git fetch origin; local_hash=$(git rev-parse HEAD); remote_hash=$(git rev-parse origin/HEAD)
    [[ "$local_hash" == "$remote_hash" ]] && { ui_info "AUR '${pkg}' is up to date"; return 0; }
    ui_info "Updating AUR '${pkg}'..."; git pull; makepkg --noconfirm -si)
    [[ "$UI_CLEANUP_AFTER_BUILD" -eq 1 ]] && rm -rf "$aur_path"
}

ui_aur_check_updates() {
    local pkg="$1"
    local aur_path="${UI_AUR_DIR}/${pkg}"
    [[ -d "${aur_path}/.git" ]] || { echo "unknown"; return; }
    (cd "$aur_path" || exit 1; git fetch origin >/dev/null 2>&1
    [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/HEAD)" ]] && echo "outdated" || echo "current")
}

ui_detect_distro() {
    # Check /etc/os-release first for accuracy
    if [[ -f /etc/os-release ]]; then
        local id id_like
        id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        id_like=$(grep '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' || true)
        case "$id" in
            arch|manjaro|endeavouros|garuda|artix|arcolinux|blackarch|parabola|hyperbola|kaos|chakra|archlabs|obarun) echo "arch"; return ;;
            debian|ubuntu|mint|pop|zorin|elementary|deepin|kali|parrot|raspbian|q4os|antix|mx|lubuntu|xubuntu|kubuntu|pardus) echo "debian"; return ;;
            fedora|rhel|centos|rocky|almalinux|oracle|amazon|openeuler|eurolinux|miracle|springdale) echo "fedora"; return ;;
            opensuse|suse) echo "suse"; return ;;
            alpine) echo "alpine"; return ;;
            void) echo "void"; return ;;
            gentoo) echo "gentoo"; return ;;
            solus) echo "solus"; return ;;
            slackware) echo "slackware"; return ;;
            nixos) echo "nixos"; return ;;
        esac
        case "$id_like" in
            *arch*) echo "arch"; return ;;
            *debian*) echo "debian"; return ;;
            *fedora*|*rhel*) echo "fedora"; return ;;
            *suse*) echo "suse"; return ;;
        esac
    fi
    # Fallback to package manager detection
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

ui_native_install() {
    local pkg="$1" ver="${2:-}" distro; distro=$(ui_detect_distro)
    local spec="$pkg"
    case "$distro" in
        arch)   [[ -n "$ver" ]] && ui_warn "pacman: version pinning unsupported; installing latest '${pkg}'"; ui_info "Installing '${pkg}' via pacman..."; ui_priv pacman -S --needed --noconfirm "$pkg" ;;
        debian) [[ -n "$ver" ]] && spec="${pkg}=${ver}"; ui_info "Installing '${spec}' via apt..."; ui_priv apt-get install -y "$spec" ;;
        fedora|yum) [[ -n "$ver" ]] && spec="${pkg}-${ver}"; if command -v dnf >/dev/null 2>&1; then ui_info "Installing '${spec}' via dnf..."; ui_priv dnf install -y "$spec"; else ui_info "Installing '${spec}' via yum..."; ui_priv yum install -y "$spec"; fi ;;
        suse)   [[ -n "$ver" ]] && spec="${pkg}=${ver}"; ui_info "Installing '${spec}' via zypper..."; ui_priv zypper install -y "$spec" ;;
        alpine) ui_info "Installing '${pkg}' via apk..."; ui_priv apk add "$pkg" ;;
        void)   ui_info "Installing '${pkg}' via xbps..."; ui_priv xbps-install -y "$pkg" ;;
        gentoo) ui_info "Installing '${pkg}' via emerge..."; ui_priv emerge "$pkg" ;;
        solus)  ui_info "Installing '${pkg}' via eopkg..."; ui_priv eopkg install -y "$pkg" ;;
        slackware) ui_info "Installing '${pkg}' via slackpkg..."; ui_priv slackpkg install "$pkg" ;;
        crux)   ui_info "Installing '${pkg}' via prt-get..."; ui_priv prt-get install "$pkg" ;;
        clear)  ui_info "Installing '${pkg}' via swupd..."; ui_priv swupd bundle-add "$pkg" ;;
        guix)   ui_info "Installing '${pkg}' via guix..."; guix package -i "$pkg" ;;
        termux) ui_info "Installing '${pkg}' via pkg..."; pkg install -y "$pkg" ;;
        nixos)  ui_info "Installing '${pkg}' via nix-env..."; nix-env -iA "nixpkgs.${pkg}" ;;
        *)      ui_err "Unknown distribution"; return 1 ;;
    esac
}

ui_native_uninstall() {
    local pkg="$1" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   ui_info "Removing '${pkg}' via pacman..."; ui_priv pacman -Rns --noconfirm "$pkg" ;;
        debian) ui_info "Removing '${pkg}' via apt..."; ui_priv apt-get remove --purge -y "$pkg" ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then ui_info "Removing '${pkg}' via dnf..."; ui_priv dnf remove -y "$pkg"; else ui_info "Removing '${pkg}' via yum..."; ui_priv yum remove -y "$pkg"; fi ;;
        suse)   ui_info "Removing '${pkg}' via zypper..."; ui_priv zypper remove -y "$pkg" ;;
        alpine) ui_info "Removing '${pkg}' via apk..."; ui_priv apk del "$pkg" ;;
        void)   ui_info "Removing '${pkg}' via xbps..."; ui_priv xbps-remove -y "$pkg" ;;
        gentoo) ui_info "Removing '${pkg}' via emerge..."; ui_priv emerge --unmerge "$pkg" ;;
        solus)  ui_info "Removing '${pkg}' via eopkg..."; ui_priv eopkg remove -y "$pkg" ;;
        slackware) ui_info "Removing '${pkg}' via slackpkg..."; ui_priv slackpkg -default_answer=y remove "$pkg" ;;
        crux)   ui_info "Removing '${pkg}' via prt-get..."; ui_priv prt-get remove "$pkg" ;;
        clear)  ui_info "Removing '${pkg}' via swupd..."; ui_priv swupd bundle-remove "$pkg" ;;
        guix)   ui_info "Removing '${pkg}' via guix..."; guix package -r "$pkg" ;;
        termux) ui_info "Removing '${pkg}' via pkg..."; pkg uninstall -y "$pkg" ;;
        nixos)  ui_info "Removing '${pkg}' via nix-env..."; nix-env -e "$pkg" ;;
        *)      ui_err "Unknown distribution"; return 1 ;;
    esac
}

ui_native_update() {
    local distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   ui_info "Updating system via pacman..."; ui_priv pacman -Syu --noconfirm ;;
        debian) ui_info "Updating system via apt..."; ui_priv apt-get update && ui_priv apt-get full-upgrade -y ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then ui_info "Updating system via dnf..."; ui_priv dnf upgrade --refresh -y; else ui_info "Updating system via yum..."; ui_priv yum update -y; fi ;;
        suse)   ui_info "Updating system via zypper..."; ui_priv zypper refresh && ui_priv zypper dup -y ;;
        alpine) ui_info "Updating system via apk..."; ui_priv apk upgrade ;;
        void)   ui_info "Updating system via xbps..."; ui_priv xbps-install -Su ;;
        gentoo) ui_info "Updating system via emerge..."; ui_priv emerge --sync && ui_priv emerge -uDU @world ;;
        solus)  ui_info "Updating system via eopkg..."; ui_priv eopkg upgrade -y ;;
        slackware) ui_info "Updating system via slackpkg..."; ui_priv slackpkg update && ui_priv slackpkg upgrade-all ;;
        crux)   ui_info "Updating system via prt-get..."; ui_priv prt-get sysup ;;
        clear)  ui_info "Updating system via swupd..."; ui_priv swupd update ;;
        guix)   ui_info "Updating system via guix..."; guix pull && guix package -u ;;
        termux) ui_info "Updating system via pkg..."; pkg update && pkg upgrade -y ;;
        nixos)  ui_info "Updating system via nixos-rebuild..."; ui_priv nixos-rebuild switch --upgrade ;;
        *)      ui_warn "Unknown distribution. Skipping system update." ;;
    esac
}

# Parse "name-version-rN" output of `apk search -v -e` into the bare version.
# "neovim-0.10.0-r0" with pkg=neovim yields "0.10.0" (not the "-r0" revision).
ui_alpine_parse_version() {
    local pkg="$1" out="$2"
    local ver="${out#"${pkg}-"}"
    ver="${ver%-r[0-9]*}"
    printf '%s\n' "$ver"
}

ui_native_search() {
    local pkg="$1" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)   pacman -Ss "^${pkg}$" >/dev/null 2>&1 ;;
        debian) apt-cache show "$pkg" >/dev/null 2>&1 ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then dnf info "$pkg" >/dev/null 2>&1; else yum info "$pkg" >/dev/null 2>&1; fi ;;
        suse)   zypper info "$pkg" >/dev/null 2>&1 ;;
        alpine) apk search -e "$pkg" 2>/dev/null | grep -q . ;;
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
        arch)   pacman -Si "$pkg" 2>/dev/null | awk -F ': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        debian) apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2; exit}' ;;
        fedora|yum) if command -v dnf >/dev/null 2>&1; then dnf info "$pkg" 2>/dev/null | awk -F ': ' '/^Version/{print $2; exit}' | tr -d ' '; else yum info "$pkg" 2>/dev/null | awk -F ': ' '/^Version/{print $2; exit}' | tr -d ' '; fi ;;
        suse)   zypper info "$pkg" 2>/dev/null | awk -F ': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        alpine) local aline; aline="$(apk search -v -e "$pkg" 2>/dev/null | head -n1)"; [[ -n "$aline" ]] && ui_alpine_parse_version "$pkg" "$aline" || true ;;
        void)   xbps-query -R "$pkg" 2>/dev/null | awk -F ': ' '/^pkgver/{print $2; exit}' | tr -d ' ' ;;
        gentoo) emerge -s "^${pkg}$" 2>/dev/null | grep -m1 "${pkg}-" | sed 's/.*-//' | awk '{print $1}' ;;
        solus)  eopkg info "$pkg" 2>/dev/null | awk -F ': ' '/^Version/{print $2; exit}' | tr -d ' ' ;;
        *)      echo "" ;;
    esac
}

ui_nix_search() { local pkg="$1"; ui_has_nix || return 1; nix-env -qaP --json "^${pkg}$" 2>/dev/null | grep -q "$pkg"; }

ui_nix_search_version() {
    local pkg="$1"
    ui_has_nix || { echo ""; return; }
    nix-env -qaP --json "^${pkg}$" 2>/dev/null | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4
}

ui_aur_rpc_url() { printf 'https://aur.archlinux.org/rpc/v5/info?arg%%5B%%5D=%s' "$(ui_urlencode "$1")"; }

ui_aur_search() { curl -sf "$(ui_aur_rpc_url "$1")" 2>/dev/null | grep -q '"resultcount":[1-9]'; }

ui_aur_search_version() { curl -sf "$(ui_aur_rpc_url "$1")" 2>/dev/null | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4; }

ui_aur_info_json() { curl -sf "$(ui_aur_rpc_url "$1")" 2>/dev/null; }

ui_json_str() { echo "$1" | grep -o "\"${2}\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

ui_json_num() { echo "$1" | grep -o "\"${2}\":[0-9.]*" | head -1 | cut -d':' -f2; }

ui_aur_pkgbuild_url() { printf 'https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=%s' "$(ui_urlencode "$1")"; }

ui_aur_fetch_pkgbuild() { curl -sf "$(ui_aur_pkgbuild_url "$1")" -o "$2" 2>/dev/null; }

ui_confirm() {
    local msg="$1" auto="${2:-}"
    [[ "$UI_AUTO_YES" -eq 1 || "$auto" == "1" ]] && return 0
    printf "%s [Y/n] " "$msg"; local resp; read -r resp
    case "$resp" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

# Confirmation for dangerous actions: never bypassed by -y/--yes or auto_yes.
# Requires the literal word "yes" (any case); anything else, including EOF, declines.
ui_confirm_critical() {
    local msg="$1" resp
    printf "%s [yes/NO] " "$msg"
    read -r resp || return 1
    [[ "$resp" =~ ^[Yy][Ee][Ss]$ ]]
}

# Confirmation that defaults to NO: empty input or EOF declines (for
# destructive actions like overwriting files). Still bypassed by -y/auto_yes.
ui_confirm_no() {
    local msg="$1" auto="${2:-}"
    [[ "$UI_AUTO_YES" -eq 1 || "$auto" == "1" ]] && return 0
    printf "%s [y/N] " "$msg"; local resp; read -r resp || return 1
    case "$resp" in [Yy]*) return 0 ;; *) return 1 ;; esac
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
    local tarball_name="u-install-${latest#v}.tar.gz"
    # Prefer a tarball explicitly attached to the release; fall back to the
    # auto-generated source archive.
    if ! curl -sfL "https://github.com/runvoid/u-install/releases/download/${latest}/${tarball_name}" -o "${tmpdir}/${tarball_name}" 2>/dev/null; then
        curl -Lf "https://github.com/runvoid/u-install/archive/refs/tags/${latest}.tar.gz" -o "${tmpdir}/${tarball_name}" || { ui_err "Download failed"; rm -rf "$tmpdir"; return 1; }
    fi

    # --- Integrity check: verify the tarball against the release SHA256SUMS ---
    if curl -sfL "https://github.com/runvoid/u-install/releases/download/${latest}/SHA256SUMS" -o "${tmpdir}/SHA256SUMS" 2>/dev/null; then
        local expected
        expected=$(awk -v f="$tarball_name" '$2 == f || $2 == "./" f || $2 ~ ("/" f "$") {print $1; exit}' "${tmpdir}/SHA256SUMS")
        if [[ -n "$expected" ]]; then
            local actual; actual=$(ui_sha256_file "${tmpdir}/${tarball_name}")
            if [[ -z "$actual" || "$actual" != "$expected" ]]; then
                ui_err "Checksum mismatch for ${tarball_name}: expected ${expected}, got ${actual:-unknown}. Aborting."
                rm -rf "$tmpdir"
                return 1
            fi
            ui_ok "Checksum verified."
        else
            ui_warn "SHA256SUMS has no entry for ${tarball_name}."
            ui_confirm "Continue without checksum verification?" || { rm -rf "$tmpdir"; return 0; }
        fi
    else
        ui_warn "Release ${latest} has no SHA256SUMS asset; cannot verify tarball integrity."
        ui_confirm "Continue without checksum verification?" || { rm -rf "$tmpdir"; return 0; }
    fi

    tar xzf "${tmpdir}/${tarball_name}" -C "$tmpdir" || { ui_err "Extraction failed"; rm -rf "$tmpdir"; return 1; }
    local extracted="${tmpdir}/u-install-${latest#v}"
    if [[ ! -f "${extracted}/lib/u-install.sh" ]]; then
        local lib_found; lib_found=$(find "$tmpdir" -maxdepth 4 -type f -path '*/lib/u-install.sh' -print -quit 2>/dev/null)
        [[ -n "$lib_found" ]] && extracted="$(dirname "$(dirname "$lib_found")")"
    fi
    [[ -f "${extracted}/lib/u-install.sh" ]] || { ui_err "Extraction failed"; rm -rf "$tmpdir"; return 1; }
    ui_info "Installing update..."
    local tools=(u-install u-uninstall u-update u-upgrade u-stats u-doctor u-search u-peek u-list u-export u-import u-help u-info u-diff u-sync u-outdated u-history u-clean)
    for t in "${tools[@]}"; do
        if [[ -f "${extracted}/${t}" ]]; then
            cp "${extracted}/${t}" "${UI_BIN_DIR}/${t}"
            chmod +x "${UI_BIN_DIR}/${t}"
        fi
    done
    mkdir -p "${UI_DATA_DIR}/lib"
    cp "${extracted}/lib/u-install.sh" "${UI_DATA_DIR}/lib/"
    # Keep the installer script and shell completions in sync with the new version.
    if [[ -f "${extracted}/install" ]]; then
        cp "${extracted}/install" "${UI_DATA_DIR}/install"
        chmod +x "${UI_DATA_DIR}/install"
        ui_info "Regenerating shell completions..."
        bash "${UI_DATA_DIR}/install" --completions-only || ui_warn "Failed to regenerate completions"
    fi
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

# --- Dry-run helpers (v1.3.0) ---
ui_dry_run_native() {
    local pkg="$1" ver="${2:-}" distro; distro=$(ui_detect_distro)
    case "$distro" in
        arch)      echo "pacman -S --needed --noconfirm $pkg" ;;
        debian)    [[ -n "$ver" ]] && echo "apt-get install -y ${pkg}=${ver}" || echo "apt-get install -y $pkg" ;;
        fedora|yum) [[ -n "$ver" ]] && echo "dnf install -y ${pkg}-${ver}" || echo "dnf install -y $pkg" ;;
        suse)      [[ -n "$ver" ]] && echo "zypper install -y ${pkg}=${ver}" || echo "zypper install -y $pkg" ;;
        alpine)    echo "apk add $pkg" ;;
        void)      echo "xbps-install -y $pkg" ;;
        gentoo)    echo "emerge $pkg" ;;
        solus)     echo "eopkg install -y $pkg" ;;
        slackware) echo "slackpkg install $pkg" ;;
        crux)      echo "prt-get install $pkg" ;;
        clear)     echo "swupd bundle-add $pkg" ;;
        guix)      echo "guix package -i $pkg" ;;
        termux)    echo "pkg install -y $pkg" ;;
        nixos)     echo "nix-env -iA nixpkgs.$pkg" ;;
        *)         echo "<unsupported distro>" ;;
    esac
}

ui_dry_run_nix() { echo "nix-env -iA ${UI_NIX_CHANNEL}.$1"; }
ui_dry_run_aur() { echo "git clone https://aur.archlinux.org/$1.git && makepkg -si"; }

# --- u-info helper (v1.3.0) ---
ui_info_pkg() {
    local pkg="$1"
    local src; src=$(ui_db_get_source "$pkg")
    [[ -z "$src" ]] && { ui_err "'${pkg}' not tracked by u-install"; return 1; }

    local ver="" size="" date=""
    date=$(awk -F'|' -v p="$pkg" '$1 == p {d=$3} END {if (d != "") print d}' "$UI_DB" 2>/dev/null || true)

    case "$src" in
        native)
            local distro; distro=$(ui_detect_distro)
            case "$distro" in
                arch)   ver=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}') ;;
                debian) ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null) ;;
                fedora|yum|suse) ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null) ;;
            esac
            ;;
        nix)
            ver=$(nix-env -q 2>/dev/null | awk -v p="$pkg" 'index($0, p "-") == 1 {print substr($0, length(p) + 2); exit}')
            size=$(ui_nix_pkg_size "$pkg")
            ;;
        aur)
            ver=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
            ;;
    esac

    printf "  Package:  %s\n" "$pkg"
    printf "  Source:   %s\n" "$src"
    printf "  Version:  %s\n" "${ver:-unknown}"
    printf "  Installed: %s\n" "${date:-unknown}"
    [[ -n "$size" && "$size" != "0" ]] && printf "  Size:     %s\n" "$(ui_human_size "$size")"
}

# --- u-diff helper (v1.3.0) ---
ui_diff_u() {
    local f1="$1" f2="$2"
    local pkgs1 pkgs2
    pkgs1=$(ui_uf_section "$f1" packages | sort)
    pkgs2=$(ui_uf_section "$f2" packages | sort)

    printf "\n  %-24s %-8s %-15s %s\n" "PACKAGE" "SOURCE" "V1" "V2"
    printf "  %-24s %-8s %-15s %s\n" "------------------------" "--------" "---------------" "---------------"

    # Packages only in f1
    while IFS='|' read -r pkg src ver; do
        [[ -z "$pkg" ]] && continue
        if ! ui_list_has "$pkgs2" "$pkg"; then
            printf "  %-24s %-8s %-15s ${UI_RED}%-s${UI_NC}\n" "$pkg" "$src" "${ver:-latest}" "-removed-"
        fi
    done <<< "$pkgs1"

    # Packages only in f2
    while IFS='|' read -r pkg src ver; do
        [[ -z "$pkg" ]] && continue
        if ! ui_list_has "$pkgs1" "$pkg"; then
            printf "  %-24s %-8s ${UI_GREEN}%-15s${UI_NC} %s\n" "$pkg" "$src" "-missing-" "${ver:-latest}"
        fi
    done <<< "$pkgs2"

    # Packages in both (version diff)
    while IFS='|' read -r pkg src ver; do
        [[ -z "$pkg" ]] && continue
        local ver2; ver2=$(printf '%s\n' "$pkgs2" | awk -F'|' -v p="$pkg" '$1 == p {print $3; exit}')
        if [[ -n "$ver2" && "$ver" != "$ver2" ]]; then
            printf "  %-24s %-8s %-15s %s\n" "$pkg" "$src" "${ver:-latest}" "${ver2:-latest}"
        fi
    done <<< "$pkgs1"
    return 0
}

# --- u-sync helper (v1.3.0) ---
# Interactive checkbox screen for ui_sync_u (v1.4.1). Reads missing/extra
# and toggles the sel_m/sel_e arrays in the caller's scope.
ui_sync_review() {
    local box_on="${UI_GREEN}[x]${UI_NC}" box_off="${UI_DIM}[ ]${UI_NC}"
    local i n m_count="${#missing[@]}"
    while true; do
        printf "\n  Review sync changes:\n"
        n=0
        if [[ ${#missing[@]} -gt 0 ]]; then
            printf "    Install:\n"
            for i in "${!missing[@]}"; do
                n=$((n+1))
                local p s v; IFS='|' read -r p s v <<< "${missing[$i]}"
                local box="$box_off"; [[ "${sel_m[$i]}" -eq 1 ]] && box="$box_on"
                printf "      %s %d) %s ${UI_G_ARROW} %s%s\n" "$box" "$n" "$p" "${s:-native}" "${v:+ @ ${v}}"
            done
        fi
        if [[ ${#extra[@]} -gt 0 ]]; then
            printf "    Remove:\n"
            for i in "${!extra[@]}"; do
                n=$((n+1))
                local p s2; IFS='|' read -r p s2 <<< "${extra[$i]}"
                local box="$box_off"; [[ "${sel_e[$i]}" -eq 1 ]] && box="$box_on"
                printf "      %s %d) ${UI_RED}%s${UI_NC} ${UI_G_ARROW} %s\n" "$box" "$n" "-$p" "${s2:-native}"
            done
        fi
        printf "\n  Toggle: numbers ${UI_G_ARROW} Enter/a apply ${UI_G_ARROW} n none ${UI_G_ARROW} q cancel\n  > "
        local inp; read -r inp || return 1
        case "$inp" in
            q|Q) return 1 ;;
            a|A|"") return 0 ;;
            n|N)
                for i in "${!sel_m[@]}"; do sel_m[i]=0; done
                for i in "${!sel_e[@]}"; do sel_e[i]=0; done
                return 0
                ;;
            *)
                local tok
                for tok in $inp; do
                    [[ "$tok" =~ ^[0-9]+$ ]] || continue
                    if [[ "$tok" -ge 1 && "$tok" -le "$m_count" ]]; then
                        i=$((tok-1))
                        [[ "${sel_m[$i]}" -eq 1 ]] && sel_m[i]=0 || sel_m[i]=1
                    elif [[ "$tok" -ge 1 && "$tok" -le $((m_count + ${#extra[@]})) ]]; then
                        i=$((tok - m_count - 1))
                        [[ "${sel_e[$i]}" -eq 1 ]] && sel_e[i]=0 || sel_e[i]=1
                    fi
                done
                ;;
        esac
    done
}

ui_sync_u() {
    local uf="$1" auto_yes="${2:-0}" dry_run="${3:-0}"
    local current_pkgs sync_pkgs missing=() extra=() count=0 removed=0 fail=0 idx=0
    local -a sel_m=() sel_e=()

    current_pkgs=$(ui_db_list | cut -d'|' -f1 | sort)
    sync_pkgs=$(ui_uf_section "$uf" packages | cut -d'|' -f1 | sort)

    # Find missing packages
    while IFS='|' read -r pkg src ver; do
        [[ -z "$pkg" ]] && continue
        if ! ui_list_has "$current_pkgs" "$pkg"; then
            missing+=("$pkg|$src|$ver")
        fi
    done < <(ui_uf_section "$uf" packages)

    # Find extra packages
    while IFS='|' read -r pkg src ver; do
        [[ -z "$pkg" ]] && continue
        if ! ui_list_has "$sync_pkgs" "$pkg"; then
            extra+=("$pkg|$src")
        fi
    done < <(ui_db_list)

    printf "\n  Sync analysis:\n"
    printf "  Current packages: %s\n" "$(ui_count_lines "$current_pkgs")"
    printf "  Target packages:  %s\n" "$(ui_count_lines "$sync_pkgs")"
    printf "  Missing:          %s\n" "${#missing[@]}"
    printf "  Extra:            %s\n" "${#extra[@]}"

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "\n  Missing packages:\n"
        for m in "${missing[@]}"; do
            local p s v; IFS='|' read -r p s v <<< "$m"
            printf "    ${UI_GREEN}%s${UI_NC} %s (%s)\n" "+" "$p" "$s"
        done
    fi

    if [[ ${#extra[@]} -gt 0 ]]; then
        printf "\n  Extra packages (not in .u file):\n"
        for e in "${extra[@]}"; do
            local p s; IFS='|' read -r p s <<< "$e"
            printf "    ${UI_RED}%s${UI_NC} %s (%s)\n" "-" "$p" "$s"
        done
    fi

    # --- Decide what to apply ---
    for m in "${missing[@]}"; do sel_m+=(1); done
    for e in "${extra[@]}"; do sel_e+=(1); done

    if [[ "$dry_run" -eq 1 ]]; then
        if [[ ${#missing[@]} -gt 0 ]]; then
            printf "\n  Would install (dry run):\n"
            for m in "${missing[@]}"; do
                local p s v target; IFS='|' read -r p s v <<< "$m"
                target="$p"
                [[ -n "$v" ]] && target="${p}=${v}"
                if [[ -n "$s" ]]; then
                    printf "    + u-install --%s %s -y\n" "$s" "$target"
                else
                    printf "    + u-install %s -y\n" "$target"
                fi
            done
        fi
        if [[ ${#extra[@]} -gt 0 ]]; then
            printf "\n  Would remove (dry run):\n"
            for e in "${extra[@]}"; do
                local p; IFS='|' read -r p _ <<< "$e"
                printf "    - u-uninstall %s -y\n" "$p"
            done
        fi
    elif [[ "${#missing[@]}" -gt 0 || "${#extra[@]}" -gt 0 ]]; then
        if [[ "$auto_yes" -eq 1 ]]; then
            : # apply everything, no questions
        elif [[ -t 0 ]]; then
            if ! ui_sync_review; then
                ui_info "Sync cancelled. No changes were made."
                return 0
            fi
        else
            # Non-interactive without -y: keep the classic two prompts
            # (EOF defaults to yes, as before).
            local i
            if [[ ${#missing[@]} -gt 0 ]] && ! ui_confirm "Install missing packages?"; then
                for i in "${!sel_m[@]}"; do sel_m[i]=0; done
            fi
            if [[ ${#extra[@]} -gt 0 ]] && ! ui_confirm "Remove extra packages?"; then
                for i in "${!sel_e[@]}"; do sel_e[i]=0; done
            fi
        fi
    fi

    # --- Apply selected ---
    if [[ "$dry_run" -ne 1 ]]; then
        local total=0 i
        for i in "${!sel_m[@]}"; do [[ "${sel_m[$i]}" -eq 1 ]] && total=$((total+1)); done
        idx=0
        for i in "${!missing[@]}"; do
            [[ "${sel_m[$i]}" -eq 1 ]] || continue
            local p s v target; IFS='|' read -r p s v <<< "${missing[$i]}"
            target="$p"
            [[ -n "$v" ]] && target="${p}=${v}"
            idx=$((idx+1))
            ui_progress "$idx" "$total" "installing ${p}"
            ui_info "Installing ${p}..."
            if [[ -n "$s" ]]; then
                "${UI_BIN_DIR}/u-install" "--${s}" "$target" -y || { ui_warn "Failed: ${p}"; fail=$((fail+1)); }
            else
                "${UI_BIN_DIR}/u-install" "$target" -y || { ui_warn "Failed: ${p}"; fail=$((fail+1)); }
            fi
            count=$((count+1))
        done
        [[ "$total" -gt 0 ]] && ui_progress_end

        total=0
        for i in "${!sel_e[@]}"; do [[ "${sel_e[$i]}" -eq 1 ]] && total=$((total+1)); done
        idx=0
        for i in "${!extra[@]}"; do
            [[ "${sel_e[$i]}" -eq 1 ]] || continue
            local p; IFS='|' read -r p _ <<< "${extra[$i]}"
            idx=$((idx+1))
            ui_progress "$idx" "$total" "removing ${p}"
            ui_info "Removing ${p}..."
            "${UI_BIN_DIR}/u-uninstall" "$p" -y || ui_warn "Failed to remove: ${p}"
            removed=$((removed+1))
        done
        [[ "$total" -gt 0 ]] && ui_progress_end
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        ui_info "Dry run complete. No changes were made."
    else
        printf "\n  Sync summary: ${UI_GREEN}${UI_G_OK}${UI_NC} %d installed ${UI_G_INFO} ${UI_RED}${UI_G_FAIL}${UI_NC} %d failed ${UI_G_INFO} ${UI_YELLOW}${UI_G_SKIP}${UI_NC} %d removed\n" "$count" "$fail" "$removed"
    fi
    return 0
}

# --- Auto-update check (v1.3.0) ---
ui_check_for_updates() {
    [[ "$UI_AUTO_UPDATE_CHECK" -eq 0 ]] && return 0

    local interval_sec=$((UI_UPDATE_CHECK_INTERVAL_DAYS * 86400))
    local now; now=$(date +%s)

    if [[ -f "$UI_LAST_CHECK_FILE" ]]; then
        local last_check; last_check=$(cat "$UI_LAST_CHECK_FILE" 2>/dev/null || echo 0)
        [[ "$((now - last_check))" -lt "$interval_sec" ]] && return 0
    fi

    echo "$now" > "$UI_LAST_CHECK_FILE"

    local latest; latest=$(curl -sf --max-time 3 \
        "https://api.github.com/repos/runvoid/u-install/releases/latest" 2>/dev/null \
        | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

    [[ -z "$latest" ]] && return 0
    latest="${latest#v}"

    if [[ "$latest" != "$UI_VERSION" ]]; then
        ui_warn "Update available: u-install v${latest} (you have v${UI_VERSION})"
        ui_info "Run: u-install --self-update"
    fi
}

# --- Search cache (v1.3.0) ---
ui_search_cached() {
    local source="$1" pkg="$2"
    local cache_file="${UI_CACHE_DIR}/${source}_${pkg}.cache"
    local cache_ttl=3600  # 1 hour

    if [[ -f "$cache_file" ]]; then
        local age; age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [[ "$age" -lt "$cache_ttl" ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

ui_search_cache_write() {
    local source="$1" pkg="$2" result="$3"
    mkdir -p "$UI_CACHE_DIR"
    echo "$result" > "${UI_CACHE_DIR}/${source}_${pkg}.cache"
}

ui_clear_search_cache() { rm -rf "${UI_CACHE_DIR:?}"/*; }

# --- Export / Import (.u format) ---
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

ui_installed_version() {
    local pkg="$1" src="$2" distro
    case "$src" in
        nix)
            ui_has_nix || { echo ""; return 0; }
            nix-env -q 2>/dev/null | awk -v p="$pkg" 'index($0, p "-") == 1 {print substr($0, length(p) + 2); exit}'
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

ui_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    fi
}

ui_sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}

ui_uf_sign() {
    local file="$1" sum tmp
    # v1.4.0 (format u3): the signature covers [config] AND [packages].
    sum="$( { ui_uf_section "$file" config; ui_uf_section "$file" packages; } | ui_sha256)"
    [[ -z "$sum" ]] && return 0
    tmp="$(mktemp)"
    awk -v s="sha256=${sum}" '
        /^sha256=/ { next }
        { print }
        $0 == "[meta]" && !ins { print s; ins=1 }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Exit codes: 0 = verified (config+packages), 1 = mismatch, 2 = unsigned or
# no hasher, 3 = legacy u2 signature that covers [packages] only.
ui_uf_verify() {
    local file="$1" stored actual
    stored="$(ui_uf_section "$file" meta | awk -F= '/^sha256=/{print $2}')"
    [[ -z "$stored" ]] && return 2
    command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || return 2
    actual="$( { ui_uf_section "$file" config; ui_uf_section "$file" packages; } | ui_sha256)"
    [[ "$stored" == "$actual" ]] && return 0
    actual="$(ui_uf_section "$file" packages | ui_sha256)"
    [[ "$stored" == "$actual" ]] && return 3
    return 1
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
