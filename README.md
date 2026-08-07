# u-install

Universal package manager wrapper for Linux.

## Quick Install

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
./install
```

## Commands

| Command | Description |
|---------|-------------|
| `u-install <pkg>` | Install from native, Nix, or AUR |
| `u-install --nix <pkg>` | Force Nix |
| `u-install --aur <pkg>` | Force AUR |
| `u-install --native <pkg>` | Force native PM |
| `u-install @<group>` | Install a group (e.g. `@dev-tools`) |
| `u-install --profile <name>` | Install from profile file |
| `u-install --self-update` | Update u-install itself |
| `u-search <pkg>` | Search across all sources |
| `u-uninstall <pkg>` | Remove package |
| `u-update` | Update system, Nix, AUR |
| `u-stats` | Show statistics |
| `u-doctor` | System health check |

## Supported Distributions

**Arch-based:** Arch, Manjaro, EndeavourOS, Garuda, Artix, ArcoLinux, BlackArch, Parabola, Hyperbola, KaOS, Chakra, ArchLabs, Obarun

**Debian-based:** Debian, Ubuntu, Mint, Pop!_OS, Zorin, KDE neon, elementary, Deepin, Kali, Parrot, Raspberry Pi OS, Q4OS, antiX, MX, Lubuntu, Xubuntu, Kubuntu, Pardus

**Fedora-based:** Fedora, RHEL, CentOS Stream, Rocky, AlmaLinux, Oracle Linux, Amazon Linux, openEuler, EuroLinux, Miracle Linux, Springdale

**Others:** openSUSE, Alpine, Void, Gentoo, Solus, Slackware, CRUX, Clear Linux, Guix, Termux, NixOS

## Configuration

`~/.config/u-install/u-install.conf`

```ini
[options]
parallel_downloads = 3
aur_build_dir = ~/.local/share/u-install/aur
auto_yes = false
prefer_source = auto
colors = true
log_level = info
max_aur_builds_parallel = 2
cleanup_after_build = false
nix_channel = nixpkgs
aur_security_check = true
```

## License

MIT
