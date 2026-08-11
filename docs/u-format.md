---
layout: default
title: ".u File Format"
nav_order: 4
parent: Commands
---

# `.u` File Format

The `.u` format is a portable snapshot of your u-install setup. One file carries both the installer configuration and the list of tracked packages.

## Structure

```
# u-install export
# format: u2

[meta]
version=1.2.1
exported=2026-08-08
hostname=my-pc
sha256=abc123...

[config]
parallel_downloads = 3
auto_yes = false
prefer_source = auto

[packages]
firefox|native|123.0-1
neovim|nix|0.9.5
brave-bin|aur|1.60.0
```

## Sections

### `[meta]`
- `version` — u-install version that created the file
- `exported` — date of export
- `hostname` — source machine name
- `sha256` — integrity checksum of the `[packages]` section

### `[config]`
Key-value pairs copied from `u-install.conf`. Applied to the target machine on import.

### `[packages]`
One package per line: `name|source|version`
- `name` — package name
- `source` — `native`, `nix`, or `aur`
- `version` — pinned version (optional in older `u1` format)

## Version Pinning

When `u-export` records a version, `u-import` tries to install that exact version. This is best-effort:
- **Debian/Ubuntu**: `apt-get install pkg=version` — supported
- **Fedora**: `dnf install pkg-version` — supported
- **Arch**: pinning not supported by pacman — installs latest
- **Nix/AUR**: installs latest (pinning not supported)

Use `--latest` to skip pinning entirely.

## Integrity

`u-export` embeds a `sha256` checksum of the package list. `u-import` verifies it and refuses tampered files unless you confirm.
