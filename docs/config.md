---
layout: default
title: Configuration
nav_order: 5
---

# Configuration

Config file: `~/.config/u-install/u-install.conf`

## Default Options

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

## Option Reference

| Option | Values | Description |
|--------|--------|-------------|
| `parallel_downloads` | number | Max concurrent downloads |
| `aur_build_dir` | path | Where AUR packages are cloned and built |
| `auto_yes` | `true` / `false` | Skip all confirmation prompts |
| `prefer_source` | `auto` / `native` / `nix` / `aur` | Default source priority |
| `colors` | `true` / `false` | Enable colored output |
| `log_level` | `debug` / `info` / `warn` | Verbosity level |
| `max_aur_builds_parallel` | number | Max concurrent AUR builds |
| `cleanup_after_build` | `true` / `false` | Remove AUR build dir after install |
| `nix_channel` | string | Nix channel to use (default: `nixpkgs`) |
| `aur_security_check` | `true` / `false` | Scan PKGBUILD for suspicious patterns |
