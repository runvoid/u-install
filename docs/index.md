---
layout: default
title: Home
nav_order: 1
---

# u-install
{: .fs-9 }

Universal package manager wrapper for Linux. Install from native repos, Nix, or AUR.
{: .fs-6 .fw-300 }

[Get Started](#quick-start){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/runvoid/u-install){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## One command. Any distro.

No need to remember `apt`, `dnf`, `pacman`, or `nix-env`. One tool works everywhere.

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
./install
```

## Why u-install?

| Feature | What it means for you |
|---------|----------------------|
| **Universal** | Works on Arch, Debian, Fedora, Alpine, Void, Gentoo, NixOS, and 20+ more |
| **Simple** | `u-install firefox` — that's it. Source auto-detected |
| **Portable** | `u-export` your setup, move to a new machine, `u-import` — done |
| **Lightweight** | Pure bash. No heavy runtimes. Installs in seconds |
| **Safe** | Tracks what you installed and warns before touching critical packages |

## Quick Start

```bash
# Install a package (auto-detects best source)
u-install firefox

# Search across all sources
u-search neovim

# Export your entire setup
u-export my-setup.u

# Restore on another machine
u-import my-setup.u
```

## Supported Distributions

**Arch-based:** Arch, Manjaro, EndeavourOS, Garuda, Artix, ArcoLinux, BlackArch, and more  
**Debian-based:** Debian, Ubuntu, Mint, Pop!_OS, Zorin, Kali, Raspberry Pi OS, and more  
**Fedora-based:** Fedora, RHEL, CentOS Stream, Rocky, AlmaLinux, and more  
**Others:** openSUSE, Alpine, Void, Gentoo, Solus, Slackware, NixOS, Guix, Termux

---

MIT License · [runvoid](https://github.com/runvoid)
