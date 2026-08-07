# u-install

Universal package manager wrapper for Linux.

Install software from native repositories, Nix, or AUR — with one command.
User-space packages do not require root.

## Quick Install

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
./install
```

Then restart your terminal and use:

```bash
u-install neovim
u-uninstall neovim
u-update
```

## Commands

| Command | Description |
|---------|-------------|
| `u-install <package>` | Install from native repo, Nix, or AUR |
| `u-install <package> --nix` | Force install via Nix |
| `u-install <package> --aur` | Force install via AUR (Arch-based) |
| `u-install <package> --native` | Force install via native PM |
| `u-install --profile <name>` | Install packages from a profile list |
| `u-uninstall <package>` | Remove an installed package |
| `u-update` | Update system, Nix, and AUR packages safely |
| `u-update --system` | Update only system packages |
| `u-update --nix` | Update only Nix packages |
| `u-update --aur` | Update only AUR packages |
| `u-stats` | Show installation statistics |
| `u-doctor` | Check system health and diagnostics |

## Configuration

Edit `~/.config/u-install/u-install.conf`:

```ini
[options]
parallel_downloads = 3
aur_build_dir = ~/.local/share/u-install/aur
auto_yes = false
prefer_source = auto
colors = true
log_level = info
max_aur_builds_parallel = 2
cleanup_after_build = true
nix_channel = nixpkgs
```

## Supported Distributions

### Arch-based (pacman + Nix + AUR)
Arch Linux, Manjaro, EndeavourOS, Garuda, Artix, ArcoLinux, BlackArch, Parabola, Hyperbola, KaOS, Chakra, ArchLabs, Obarun

### Debian-based (apt + Nix)
Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS, KDE neon, elementary OS, Deepin, Kali Linux, Parrot OS, Raspberry Pi OS, Q4OS, antiX, MX Linux, Lubuntu, Xubuntu, Kubuntu, Pardus

### Fedora-based (dnf + Nix)
Fedora, RHEL, CentOS Stream, Rocky Linux, AlmaLinux, Oracle Linux, Amazon Linux, openEuler, EuroLinux, Miracle Linux, Springdale Linux

### openSUSE (zypper + Nix)
Leap, Tumbleweed

### Alpine (apk + Nix)
Alpine Linux, postmarketOS

### Void (xbps + Nix)
Void Linux

### Gentoo (portage + Nix)
Gentoo, Calculate Linux, Funtoo

### Solus (eopkg + Nix)
Solus

### Slackware (slackpkg + Nix)
Slackware, Salix

### CRUX (prt-get + Nix)
CRUX

### Clear Linux (swupd + Nix)
Clear Linux OS

### Guix (guix + Nix fallback)
Guix System

### Termux (pkg + Nix)
Termux (Android)

### NixOS (nix native)
NixOS

### Generic / Unknown
Any Linux with Nix as fallback

## Safety

- System-critical packages (kernel, bootloader, glibc, drivers, systemd) are updated **only** through the native package manager.
- Nix installs are user-local (`~/.nix-profile`) and do not touch `/usr`.
- AUR is supported only on Arch-based systems with `base-devel` installed.

## Files

```
u-install/
├── config/
│   └── u-install.conf    # Default configuration
├── profiles/
│   └── example.txt       # Example package list
├── lib/
│   └── u-install.sh      # Common library
├── install               # Self-installer
├── u-install             # Install command
├── u-uninstall           # Uninstall command
├── u-update              # Update command
├── u-stats               # Statistics command
├── u-doctor              # Diagnostics command
├── README.md
└── LICENSE
```

## License

MIT
