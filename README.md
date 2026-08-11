# u-install ⚡

> **One command. Any distro. Any source.**

Stop memorizing `pacman -S`, `apt install`, `nix-env -iA`, and `git clone` into AUR.
Install `firefox`, `neovim`, or anything else the same way everywhere — from Arch to NixOS to your grandma's Debian.

[![ShellCheck](https://github.com/runvoid/u-install/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/runvoid/u-install/actions/workflows/shellcheck.yml)
[![Version](https://img.shields.io/badge/version-1.2.1-blue.svg)](https://github.com/runvoid/u-install/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![asciicast](https://asciinema.org/a/g7zQkLiVpkxhxNpn.svg)](https://asciinema.org/a/g7zQkLiVpkxhxNpn)

---

## 🎬 See it in action
<script src="https://asciinema.org/a/g7zQkLiVpkxhxNpn.js" id="asciicast-g7zQkLiVpkxhxNpn" async></script>

```bash
$ u-search neovim
SOURCE     PACKAGE   VERSION      STATUS
---------- --------- ------------ ----------
native     neovim    0.10.0       available
nix        neovim    0.10.0       available
aur        neovim    0.10.0       available

$ u-install neovim
[OK] Installed via native

$ u-export setup.u
[OK] Exported configuration and 42 package(s) to setup.u
```

---

## 🚀 Quick Install

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
chmod +x ./install
sudo ./install
```

Then restart your terminal (or `source ~/.bashrc` / `~/.zshrc`).

---

## 🤔 Why u-install?

| You want to... | yay | home-manager | u-install |
|----------------|-----|--------------|-----------|
| Install from native repos (apt, dnf, pacman...) | ❌ | ❌ | ✅ |
| Install from AUR | ✅ | ❌ | ✅ |
| Install from Nix | ❌ | ✅ | ✅ |
| Move your setup to a new machine in one file | ❌ | ✅ | ✅ |
| Run it *right now* without learning Nix/Flakes | ✅ | ❌ | ✅ |
| Pure bash, no runtimes, installs in 3 seconds | ❌ | ❌ | ✅ |

**u-install** is not a new package manager. It is a smart wrapper that picks the best source for your distro and remembers your choices.

---

## ✨ Features

- 🌍 **Universal** — 20+ distros: Arch, Debian, Fedora, Alpine, Void, Gentoo, NixOS, Termux, and more
- 🧠 **Auto-detect** — type `u-install firefox`, it finds the best source automatically
- 📦 **Portable** — `u-export` your setup, move to a new machine, `u-import` — done
- 🔒 **AUR Safety** — `u-peek` inspects AUR metadata and scans PKGBUILD for red flags *before* you build
- 🪶 **Lightweight** — pure Bash. No Python, no Node, no heavy runtimes
- 🔄 **Reproducible** — `.u` snapshots pin exact versions and verify integrity with SHA-256

---

## 📋 Commands

| Command | What it does |
|---------|-------------|
| `u-install <pkg>` | Install from native, Nix, or AUR (auto-detected) |
| `u-install --nix <pkg>` | Force Nix |
| `u-install --aur <pkg>` | Force AUR |
| `u-install --native <pkg>` | Force native PM |
| `u-install @<group>` | Install a group (e.g. `@dev-tools`) |
| `u-install --profile <name>` | Install from a profile file |
| `u-install --self-update` | Update u-install itself |
| `u-search <pkg>` | Search across all sources at once |
| `u-peek <pkg>` | Inspect AUR metadata without cloning/building |
| `u-uninstall <pkg>` | Remove package (source auto-detected) |
| `u-list` | List tracked packages (`--native`/`--nix`/`--aur`) |
| `u-export [file.u]` | Export config + packages to a portable `.u` file |
| `u-import <file.u>` | Restore config and reinstall everything |
| `u-update` | Update system, Nix, and AUR packages |
| `u-stats` | Show package statistics |
| `u-doctor` | Run system health check |
| `u-help` | Show all commands with descriptions |

Every command supports `-V`/`--version` and `-h`/`--help`.

---

## 📦 Portable setup (`.u` files)

Move your entire environment to another machine — NixOS-style, but for any distro.

```bash
# Machine A — snapshot everything:
u-export setup.u

# Copy setup.u to Machine B, then:
u-import setup.u                   # restore config + reinstall all packages
u-import --packages-only setup.u   # skip config, install packages only
u-import --config-only setup.u     # only restore installer settings
u-import --latest setup.u          # ignore pinned versions, take latest
```

A `.u` file is plain text with three sections — `[meta]`, `[config]`, `[packages]` — so you can `diff`, `git`, and edit it by hand. Each line is `name|source|version`, and `[meta]` carries a SHA-256 checksum to catch tampering.

---

## 🐧 Supported Distributions

| Family | Distros |
|--------|---------|
| **Arch-based** | Arch, Manjaro, EndeavourOS, Garuda, Artix, ArcoLinux, BlackArch, Parabola, Hyperbola, KaOS, Chakra, ArchLabs, Obarun |
| **Debian-based** | Debian, Ubuntu, Mint, Pop!_OS, Zorin, KDE neon, elementary, Deepin, Kali, Parrot, Raspberry Pi OS, Q4OS, antiX, MX, Lubuntu, Xubuntu, Kubuntu, Pardus |
| **Fedora-based** | Fedora, RHEL, CentOS Stream, Rocky, AlmaLinux, Oracle Linux, Amazon Linux, openEuler, EuroLinux, Miracle Linux, Springdale |
| **Others** | openSUSE, Alpine, Void, Gentoo, Solus, Slackware, CRUX, Clear Linux, Guix, Termux, NixOS |

---

## ⚙️ Configuration

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

---

## 🛠️ Development

Linted with [ShellCheck](https://www.shellcheck.net/), tested with [bats](https://github.com/bats-core/bats-core). CI runs on every push.

```bash
shellcheck install lib/u-install.sh u-*
bats tests/
```

---

## 📄 License

MIT © [runvoid](https://github.com/runvoid)
