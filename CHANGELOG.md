# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-08-16

Maintenance and housekeeping release: every command now reports live progress,
four new lifecycle commands (`u-upgrade`, `u-outdated`, `u-history`, `u-clean`),
self-regenerating docs, a hardened `.u` format (`u3`) — and the full audit
fix-list (20 issues) found during a WSL test-drive of 1.3.0.

### Added
- `u-upgrade <pkg>` — upgrade a single tracked package through its recorded
  source (native / Nix / AUR), with `--dry-run`; `u-update` remains for
  everything at once.
- `u-outdated` — compare installed versions of tracked packages against
  their sources and flag updates (`--native`/`--nix`/`--aur` filters).
- `u-history` — append-only journal of every install/remove/upgrade
  (`date|action|package|source`); `u-history [N]`, `--all`, `--pkg <name>`.
- `u-clean` — reclaim disk space: search cache, cached AUR clones, old Nix
  generations (`nix-collect-garbage -d`) and native orphans (pacman/apt/
  zypper/xbps), showing sizes and asking before each step; supports
  `--dry-run`.
- Live progress bars with percentages on ttys (`[####----] 40% installing
  neovim`) in `u-install`, `u-uninstall`, `u-sync`, `u-update --nix`,
  `u-upgrade`, `u-outdated`; automatically disabled when stderr is not a
  terminal or when output is piped.
- `docs/commands.html` is now generated from each command's real `--help`
  by `tools/gen-docs.sh`; CI fails if the docs are stale
  (`bash tools/gen-docs.sh --check`).
- `.u` format `u3`: the `[meta]` sha256 now covers `[config]` AND
  `[packages]`. `u-import`/`u-sync` accept u3/u2/u1; a legacy u2 signature
  (packages only) is reported with a warning and an explicit confirmation
  before its `[config]` is applied.
- `u-sync` now verifies snapshot integrity before touching the system
  (previously only `u-import` did).
- `u-search --no-cache` to bypass the search cache; `u-export -f/--force`
  to overwrite an existing file without asking.
- Package names are now validated in `u-search` and `u-peek` too, and AUR
  RPC/PKGBUILD URLs are percent-encoded (`ui_urlencode`).

### Fixed
- `u-import` died **silently** (set -e) on unsigned `u1` files and on
  tampered files before it could print a message or ask — the advertised
  warn-and-confirm path was unreachable. Verification result is now
  captured safely.
- `ui_native_search_version` was broken on every distro using GNU awk
  (Arch, Fedora, openSUSE, Void, Solus): `awk -F': '` glues into one word
  with a trailing space, gawk aborts with `Usage:` and the version came out
  empty/garbage. Debian's mawk silently tolerated it. All 5 call sites
  rewritten as `awk -F ': '`.
- Removal via pacman was interactive (`pacman -Rns` without `--noconfirm`):
  with `-y`/in scripts/through `u-sync` the confirmation got EOF and the
  removal was silently cancelled. Same fix in `ui_aur_uninstall`; slackpkg
  now runs with `-default_answer=y`.
- `ui_diff_u` aborted on the first package missing from the second file
  (grep status under pipefail) — version-diff rows after it were never
  printed and `u-diff` always exited 1.
- Snapshot signatures ignored the `[config]` section (tampering with
  `aur_build_dir`/`auto_yes`/`prefer_source` was undetectable) — see u3 above.
- Search cache existed but was never wired in: `u-search` now caches probe
  results for an hour (and honours `--no-cache`).
- Root/WSL friendliness: privileged calls go through `ui_priv` — direct
  execution when already root, `doas` when present, `sudo` otherwise
  (previously hard-coded `sudo`, failing in minimal root environments).
- `install --uninstall` now removes the PATH/completion lines it added to
  shell rc files (a dangling `source` used to make every new shell print
  an error).
- `install` no longer `chmod +x`-es **every** file in `~/.local/bin`, only
  the u-* tools it installed.
- `u-export` refuses to overwrite a non-empty file without `-f/--force`.
- `u-sync` showed "Current packages: 1" for an empty database.
- Package names with regex metacharacters (`libstdc++5`, `foo[1]`, `a.b`)
  no longer break the tracking database: all lookups are literal
  (awk field comparisons) instead of interpolated grep patterns.
- `--dry-run` output covers all supported distros, not just arch/debian/
  fedora.
- `u-import`: removed a nonsense `$src != $pkg` condition when deciding
  whether to pass the `--<source>` flag.
- Removed the dead `parallel_downloads` / `max_aur_builds_parallel` config
  keys (parsed but never used anywhere).
- `update_check_interval_days` is validated as a number instead of blowing
  up the background check with an arithmetic error.
- The background update check no longer runs (and writes state) for
  `--help`/`--version`.
- `.check.sh`: u-help preview no longer prints "Run ./install first"
  (the sandbox now stages the library), and it verifies the `u3` format.
- Docs: `docs/u-format.html` example updated to u3/1.4.0; the command
  reference is generated (see above).

## [1.3.0] - 2026-08-16

Snapshot management (u-info / u-diff / u-sync), dry-run across the toolkit,
and a batch of safety fixes: critical-package protection, AUR name validation
and checksum-verified self-updates.

### Added
- `u-info <pkg>` — detailed info about a tracked package (source, version,
  install date, Nix store size) straight from the local database.
- `u-diff <a.u> <b.u>` — compare two `.u` snapshots: packages added, removed
  and version-pinned differently between two machines.
- `u-sync <file.u>` — bring the current machine in line with a snapshot:
  installs missing packages and (with confirmation) removes extras.
- `--dry-run` on `u-install`, `u-uninstall`, `u-update` and `u-sync` — show
  the exact commands that would run, change nothing.
- Hardened PKGBUILD security scan: detects `eval` with command substitution,
  sourcing from process/command substitution, base64-piped-to-shell, inline
  `python -c` / `perl -e` / `ruby -e` / `php -r`, `system()` calls and more.
- Search cache (1 hour TTL under `~/.local/share/u-install/cache`) so repeated
  `u-search`/probe calls don't re-hit the network.
- Background update check: `u-install` quietly polls GitHub Releases at most
  once every `update_check_interval_days` days and warns when a newer version
  exists (`auto_update_check = false` in the config disables it).
- `u-uninstall --force` — explicit opt-in required to remove a critical
  system package.
- Self-update integrity: if a release ships a `SHA256SUMS` asset, the tarball
  checksum is verified and a mismatch aborts the update; without sums you get
  a warning and an explicit confirmation prompt.

### Fixed
- `u-sync --dry-run` actually changed the system: the flag only printed a
  banner while `ui_sync_u` went on to install/remove packages (and `-y`
  silenced every prompt). The dry-run flag is now passed down and the sync
  only prints what it would do.
- Critical-package protection now works in `u-uninstall` (refuses with a
  clear error unless `--force`) and `u-install` (warning plus a mandatory
  `[yes/NO]` confirmation that `-y`/`--yes`/`auto_yes` cannot bypass).
- `u-update --nix` never matched critical packages: `nix-env -q` lists
  `name-version` (e.g. `linux-6.1.0`), which never equals `linux`. The
  version suffix is now stripped before the check (`nixpkgs-unstable`-style
  names are unaffected).
- Alpine: `u-search`/probing used `apk info`, which only sees **installed**
  packages — on a fresh Alpine nothing was ever found. Now `apk search -e`
  queries the repository, and the version is parsed from
  `apk search -v -e` output (`neovim-0.10.0-r0` → `0.10.0`, previously `r0`).
- Path traversal in AUR handling: package names are validated
  (`^[A-Za-z0-9][A-Za-z0-9@._+-]*$`) before any `rm -rf`/`git clone` in
  `ui_aur_install`, and at the entry of `u-install`/`u-uninstall`;
  `u-install --aur '../../etc'` now fails with an error and touches nothing.
- `ui_self_update` now also refreshes the `install` script and regenerates
  the shell completions (via `install --completions-only`), so all files end
  up on the same version.
- CI (ShellCheck workflow) and `.check.sh` now cover `u-info`, `u-diff` and
  `u-sync` — all 14 commands, `install` and the library are linted/checked.
- Filled the empty `profiles/dev-tools.txt` (git, neovim, ripgrep, fd, bat,
  htop, tmux), so `u-install @dev-tools` actually installs something.

## [1.2.1] - 2026-08-08

Adds a top-level `u-help` entry point and makes `.u` snapshots reproducible
(pinned versions + integrity checksum), on top of ShellCheck CI and Nix fixes.

### Added
- `u-help` — a top-level entry point that lists every `u-*` command with a
  one-line description; installed and self-updated alongside the others.
- **Reproducible `.u` snapshots (format `u2`)**: `u-export` now records the
  installed version of each package (`name|source|version`) and `u-import`
  reinstalls that exact version (best-effort; native package managers that
  support pinning). Use `u-import --latest` to ignore the pins. Older `u1`
  files are still accepted.
- **Integrity checks for `.u` files**: `u-export` embeds a `sha256` of the
  package list in `[meta]`, and `u-import` verifies it, refusing a tampered
  file unless confirmed. Falls back gracefully when no hasher is available.
- README: a version badge next to the ShellCheck badge.

### Changed
- Unified the `--help` output across all `u-*` commands (each now opens with a
  short description and lists `-V`/`--version` and `-h`/`--help`).
- `u-import` now exits non-zero if any package failed to install.

### Fixed
- `u-install`: auto-mode tried to **bootstrap Nix on every run** (even without
  `--nix`) because `ui_nix_search` called `ui_ensure_nix`. Search now only
  probes an already-installed Nix; the Nix installer runs solely for an
  explicit `--nix` request.
- `ui_ensure_nix`: preflight check for `xz`/`tar` with an actionable hint
  instead of the cryptic `sh: you do not have 'xz' installed` failure that
  left Nix half-installed.
- ShellCheck compliance: added `|| exit` to the `cd` calls in the AUR build
  subshells (SC2164), rewrote the library-load guard in every command to a
  real `if/else` (SC2015), and annotated the cross-file `UI_*` globals
  (SC2034); `.shellcheckrc` documents the intentionally-kept idioms.

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

