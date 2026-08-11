---
layout: default
title: Installation
nav_order: 2
---

# Installation

## Requirements

- `bash`
- `curl`
- `git`

Optional (for AUR on Arch-based distros):
- `base-devel`
- `makepkg`

## Quick Install

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
./install
```

The installer will:
1. Copy all `u-*` commands to `~/.local/bin`
2. Copy the shared library to `~/.local/share/u-install/lib/`
3. Create a default config at `~/.config/u-install/u-install.conf`
4. Add `~/.local/bin` to your shell's `PATH`

After installation, restart your terminal or run:

```bash
source ~/.bashrc   # or ~/.zshrc, ~/.config/fish/config.fish
```

## Verify

```bash
u-help
```

You should see the list of all available commands.
