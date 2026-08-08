# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-08

The biggest update since the initial release: portable machine-to-machine
setup, three new commands, full CI (lint + unit tests) and a batch of
correctness fixes.

### Added
- **Portable environment snapshots via the `.u` format (NixOS-style)** — carry
  your whole setup to another machine in a single file:
  - `u-export [file.u]` — write installer config + tracked packages to a
    portable `.u` file (default `configuration.u`).
  - `u-import <file.u>` — restore config and (re)install every listed package
    on another machine; supports `--config-only` / `--packages-only`.
  - Line-based, human-readable format (id `u1`) with `[meta]`, `[config]` and
    `[packages]` sections, backed by library helpers `ui_export_write`,
    `ui_uf_format`, `ui_uf_section` and `ui_import_apply_config`.
- `u-peek <pkg>` — inspect AUR package metadata (maintainer, last update, votes,
  popularity, out-of-date flag, PKGBUILD size and security flags) **without**
  cloning or building it.
- `u-list` — list packages tracked in the local database, with optional
  `--native` / `--nix` / `--aur` filters.
- `-V` / `--version` flag on every command (shared `ui_print_version` helper).
- **Continuous Integration**: ShellCheck workflow
  (`.github/workflows/shellcheck.yml`) with `.shellcheckrc`, and a bats unit
  test suite under `tests/` with its own `Tests` workflow (covers sizes, JSON
  parsing, the package database and the `.u` round-trip).
- `.gitattributes` normalizing all text files to LF (removes the
  "LF will be replaced by CRLF" warnings on Windows checkouts); `*.u` snapshots
  are git-ignored so personal exports are never committed.
- Library helpers: `ui_aur_info_json`, `ui_json_str`, `ui_json_num`,
  `ui_aur_pkgbuild_url`, `ui_aur_fetch_pkgbuild`, `ui_aur_security_scan`.

### Fixed
- `u-install`: silent exit on a fresh system — an empty package database made
  `grep` in `ui_db_get_source` return non-zero, which under `set -euo pipefail`
  aborted the whole script before installing anything. Added `|| true`.
- `u-install`: `--native` / `--nix` / `--aur` silently did nothing because the
  `((fc++))` counter returns exit code 1 when the value is 0 (killed by `set -e`).
  Replaced with `fc=$((fc+1))`.
- `u-doctor`: aborted before `[Summary]` for the same `((x++))` reason. All
  counters rewritten to `x=$((x+1))`.
- `install`: PATH line was appended to the shell rc file on **every** run
  (`! $(grep -q …)` always evaluated true). Now uses a proper `grep -qF` check.
- `install`: generated an invalid `export PATH=…` line for the fish shell.
  Now emits `fish_add_path` for fish.
- `install`: PATH was silently skipped when the shell rc file did not exist.
  The file is now created if missing.
- `u-uninstall`: fixed a broken Nix detection expression
  (`$(ui_has_nix; …)`) — now a clean `if ui_has_nix && nix-env -q …`.
- Group/profile installation no longer re-installs a package **without** its
  source flag when the flagged install fails (`&& … || …` replaced by `if/else`).

### Changed
- `ui_human_size` no longer depends on `bc` (not installed by default on
  Debian/Ubuntu); reimplemented with `awk`. Fixes `u-stats` on such systems.
- `ui_self_update` copies the command binaries via a loop (easier to maintain,
  and now also installs `u-peek`, `u-list`, `u-export` and `u-import`).

