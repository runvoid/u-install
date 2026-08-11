---
layout: default
title: Commands
nav_order: 3
has_children: true
---

# Commands

All commands follow the pattern `u-<verb>` and share the same flags:

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Assume yes to all prompts |
| `-V`, `--version` | Show version |
| `-h`, `--help` | Show help |

## Core Commands

### `u-install <pkg>`
Install a package. Auto-detects native repo, Nix, or AUR.

```bash
u-install firefox
u-install --nix nodejs
u-install --aur visual-studio-code-bin
u-install @dev-tools          # install a profile group
```

### `u-uninstall <pkg>`
Remove a tracked package.

```bash
u-uninstall firefox
```

### `u-update`
Update system, Nix, and AUR packages.

```bash
u-update
u-update --native-only
```

### `u-search <pkg>`
Search a package across all sources and show availability.

```bash
u-search neovim
```

### `u-list`
List packages tracked in the local database.

```bash
u-list
u-list --native
u-list --nix
u-list --aur
```

### `u-peek <pkg>`
Inspect AUR metadata without cloning or building.

```bash
u-peek brave-bin
```

### `u-stats`
Show statistics about tracked packages.

```bash
u-stats
```

### `u-doctor`
Diagnose the environment and configuration.

```bash
u-doctor
```

## Portable Setup

### `u-export [file.u]`
Export config + package list to a portable `.u` file.

```bash
u-export my-machine.u
```

### `u-import <file.u>`
Restore config and packages from a `.u` file.

```bash
u-import my-machine.u
u-import --latest my-machine.u   # ignore pinned versions
u-import --config-only my-machine.u
```
