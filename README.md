# u-install

Universal package manager wrapper for Linux.

![ShellCheck](https://github.com/runvoid/u-install/actions/workflows/shellcheck.yml/badge.svg)

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
| `u-peek <pkg>` | Inspect AUR metadata without cloning/building |
| `u-uninstall <pkg>` | Remove package |
| `u-list` | List tracked packages (`--native`/`--nix`/`--aur`) |
| `u-export [file.u]` | Export config + package list to a portable `.u` file |
| `u-import <file.u>` | Reproduce config + packages from a `.u` file |
| `u-update` | Update system, Nix, AUR |
| `u-stats` | Show statistics |
| `u-doctor` | System health check |

Every command also supports `-V`/`--version` and `-h`/`--help`.

## Portable setup (`.u` files)

Move your whole u-install setup to another machine, NixOS-style: one file
carries both the installer configuration and the list of tracked packages.

```bash
# On machine A — snapshot config + packages:
u-export configuration.u

# Copy configuration.u to machine B, then:
u-import configuration.u          # apply config and (re)install everything
u-import --packages-only conf.u   # skip config, install packages only
u-import --config-only conf.u     # only restore installer settings
```

A `.u` file is plain text with three sections — `[meta]`, `[config]` and
`[packages]` (`name|source` per line) — so it is easy to read, diff and edit
by hand.

## Development

Shell scripts are linted with [ShellCheck](https://www.shellcheck.net/) and the
library is covered by [bats](https://github.com/bats-core/bats-core) unit tests.
Both run in CI on every push; to run them locally:

```bash
shellcheck install lib/u-install.sh u-*
bats tests/
```

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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT
