#!/usr/bin/env bats
# Unit tests for the pure helper functions in lib/u-install.sh.
# These do not require any package manager and run fully offline.

load test_helper

@test "ui_human_size: bytes stay as B" {
  run ui_human_size 0
  [ "$status" -eq 0 ]
  [ "$output" = "0B" ]
  run ui_human_size 512
  [ "$output" = "512B" ]
}

@test "ui_human_size: kilobytes" {
  run ui_human_size 1024
  [ "$output" = "1.0KB" ]
  run ui_human_size 1536
  [ "$output" = "1.5KB" ]
}

@test "ui_human_size: megabytes and gigabytes" {
  run ui_human_size 1048576
  [ "$output" = "1.0MB" ]
  run ui_human_size 1073741824
  [ "$output" = "1.0GB" ]
}

@test "ui_json_str extracts a string field" {
  json='{"Name":"neovim","Version":"0.9.5-1","Maintainer":"someone"}'
  run ui_json_str "$json" Version
  [ "$output" = "0.9.5-1" ]
}

@test "ui_json_num extracts a numeric field" {
  json='{"NumVotes":1234,"Popularity":5.6}'
  run ui_json_num "$json" NumVotes
  [ "$output" = "1234" ]
}

@test "database add / get / count / remove" {
  ui_db_add pkgA native
  ui_db_add pkgB nix
  run ui_db_count
  [ "$output" = "2" ]
  run ui_db_get_source pkgA
  [ "$output" = "native" ]
  run ui_db_count_by_source nix
  [ "$output" = "1" ]
  ui_db_remove pkgA
  run ui_db_count
  [ "$output" = "1" ]
}

@test "ui_db_get_source is empty (and succeeds) for an unknown package" {
  run ui_db_get_source ghost
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "ui_uf_section parses a section body and skips comments/blanks" {
  uf="${BATS_TEST_TMPDIR}/sample.u"
  printf '[meta]\nversion=1\n\n[packages]\n# a comment\nneovim|native\n\nfirefox|nix\n' > "$uf"
  run ui_uf_section "$uf" packages
  [ "${lines[0]}" = "neovim|native" ]
  [ "${lines[1]}" = "firefox|nix" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "export then re-read round-trips format, config and packages" {
  mkdir -p "$(dirname "$UI_CONFIG_FILE")"
  printf '[options]\nprefer_source = auto\n' > "$UI_CONFIG_FILE"
  ui_db_add neovim native
  ui_db_add firefox nix
  uf="${BATS_TEST_TMPDIR}/configuration.u"
    ui_export_write > "$uf"
    run ui_uf_format "$uf"
    [ "$output" = "u3" ]
    run ui_uf_section "$uf" packages
    # Format is u2: "name|source|version"; versions are empty here because the
    # packages are not actually installed in the test's temporary HOME.
    [ "${lines[0]}" = "neovim|native|" ]
    [ "${lines[1]}" = "firefox|nix|" ]
    run ui_uf_section "$uf" config
    [ "$output" = "prefer_source = auto" ]
}

@test "ui_uf_sign then ui_uf_verify detects tampering" {
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        skip "no sha256 hasher available"
    fi
    ui_db_add neovim native
    uf="${BATS_TEST_TMPDIR}/signed.u"
    ui_export_write > "$uf"
    ui_uf_sign "$uf"
    grep -q '^sha256=' "$uf"
    run ui_uf_verify "$uf"
    [ "$status" -eq 0 ]
    # Tamper with the package list; the stored checksum must no longer match.
    printf 'evil|native|\n' >> "$uf"
    run ui_uf_verify "$uf"
    [ "$status" -eq 1 ]
}

@test "u3 signature covers [config]: tampering with config is detected" {
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        skip "no sha256 hasher available"
    fi
    mkdir -p "$(dirname "$UI_CONFIG_FILE")"
    printf '[options]\nprefer_source = auto\n' > "$UI_CONFIG_FILE"
    ui_db_add neovim native
    uf="${BATS_TEST_TMPDIR}/cfg.u"
    ui_export_write > "$uf"
    ui_uf_sign "$uf"
    run ui_uf_verify "$uf"
    [ "$status" -eq 0 ]
    sed -i 's/prefer_source = auto/prefer_source = aur/' "$uf"
    run ui_uf_verify "$uf"
    [ "$status" -eq 1 ]
}

@test "legacy u2 signature (packages only) verifies as legacy" {
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        skip "no sha256 hasher available"
    fi
    mkdir -p "$(dirname "$UI_CONFIG_FILE")"
    printf '[options]\nprefer_source = auto\n' > "$UI_CONFIG_FILE"
    ui_db_add neovim native
    uf="${BATS_TEST_TMPDIR}/legacy.u"
    ui_export_write > "$uf"
    # emulate the old u2 signing: hash [packages] only
    sum="$(ui_uf_section "$uf" packages | ui_sha256)"
    awk -v s="sha256=${sum}" '
        /^sha256=/ { next }
        $0 == "[meta]" && !ins { print; print s; ins=1; next }
        { print }
    ' "$uf" > "${uf}.new" && mv "${uf}.new" "$uf"
    # with a non-empty [config] the u3 hash differs from the legacy one
    run ui_uf_verify "$uf"
    [ "$status" -eq 3 ]
}

@test "database handles regex metacharacters in package names" {
    ui_db_add 'libstdc++5' native
    ui_db_add 'foo[1]' nix
    run ui_db_get_source 'libstdc++5'
    [ "$output" = "native" ]
    run ui_db_get_source 'foo[1]'
    [ "$output" = "nix" ]
    run ui_db_count
    [ "$output" = "2" ]
    # 'foo' must not collide with 'foo[1]'
    run ui_db_get_source 'foo'
    [ "$output" = "" ]
    ui_db_remove 'libstdc++5'
    run ui_db_count
    [ "$output" = "1" ]
}

@test "ui_urlencode percent-encodes special characters" {
    run ui_urlencode "neovim"
    [ "$output" = "neovim" ]
    run ui_urlencode "a b"
    [ "$output" = "a%20b" ]
    run ui_urlencode "pkg+plus"
    [ "$output" = "pkg%2Bplus" ]
    run ui_urlencode "../x&y=z"
    [ "$output" = "..%2Fx%26y%3Dz" ]
}

@test "ui_list_has matches whole names, not substrings" {
    list=$'foo|native|1\nafoo|nix|2\nfoo-bar|aur|3'
    ui_list_has "$list" "foo"
    ui_list_has "$list" "afoo"
    if ui_list_has "$list" "fo"; then fail "substring matched"; fi
    if ui_list_has "$list" "missing"; then fail "missing matched"; fi
    ui_list_has "" "foo" && fail "empty list matched" || true
}

@test "ui_count_lines: empty input is zero" {
    run ui_count_lines ""
    [ "$output" = "0" ]
    run ui_count_lines $'a\nb\nc'
    [ "$output" = "3" ]
}

@test "history journal records installs and removals" {
    ui_db_add cowsay native
    ui_db_remove cowsay
    run ui_history_show 10
    echo "$output" | grep -q '|install|cowsay|native'
    echo "$output" | grep -q '|remove|cowsay|native'
    run ui_history_show 10 cowsay
    [ "${#lines[@]}" -eq 2 ]
}

@test "ui_progress is silent when stderr is not a tty" {
    run ui_progress 1 2 "testing"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    run ui_progress_end
    [ "$status" -eq 0 ]
}


@test "ui_import_apply_config rewrites the options file" {
    uf="${BATS_TEST_TMPDIR}/in.u"
    printf '# format: u1\n[config]\nprefer_source = nix\nauto_yes = true\n[packages]\n' > "$uf"
    ui_import_apply_config "$uf"
    run cat "$UI_CONFIG_FILE"
    [ "${lines[0]}" = "[options]" ]
    grep -q "prefer_source = nix" "$UI_CONFIG_FILE"
    grep -q "auto_yes = true" "$UI_CONFIG_FILE"
}

@test "ui_valid_pkg_name accepts sane package names" {
    ui_valid_pkg_name neovim
    ui_valid_pkg_name gcc-libs
    ui_valid_pkg_name python2-pip
    ui_valid_pkg_name nodejs@20
    ui_valid_pkg_name libstdc++5
}

@test "ui_valid_pkg_name rejects traversal and malformed names" {
    if ui_valid_pkg_name '../../etc'; then fail "path traversal accepted"; fi
    if ui_valid_pkg_name '..'; then fail "dotdot accepted"; fi
    if ui_valid_pkg_name '/bin/sh'; then fail "absolute path accepted"; fi
    if ui_valid_pkg_name 'pkg;rm -rf /'; then fail "shell metacharacters accepted"; fi
    if ui_valid_pkg_name ''; then fail "empty name accepted"; fi
    if ui_valid_pkg_name '-evil'; then fail "leading dash accepted"; fi
}

@test "ui_alpine_parse_version turns 'neovim-0.10.0-r0' into '0.10.0'" {
    run ui_alpine_parse_version neovim "neovim-0.10.0-r0"
    [ "$status" -eq 0 ]
    [ "$output" = "0.10.0" ]
    run ui_alpine_parse_version ripgrep "ripgrep-14.1.0-r1"
    [ "$output" = "14.1.0" ]
}

@test "ui_nix_strip_version strips the version suffix but keeps non-versioned names" {
    run ui_nix_strip_version "linux-6.1.0"
    [ "$output" = "linux" ]
    run ui_nix_strip_version "neovim-0.10.0"
    [ "$output" = "neovim" ]
    run ui_nix_strip_version "nixpkgs-unstable"
    [ "$output" = "nixpkgs-unstable" ]
}

@test "ui_is_critical flags system packages only" {
    ui_is_critical linux
    ui_is_critical sudo
    ui_is_critical systemd
    if ui_is_critical neovim; then fail "neovim flagged as critical"; fi
}

@test "ui_confirm_critical declines on EOF even with auto_yes" {
    UI_AUTO_YES=1
    if ui_confirm_critical "Really?" < /dev/null; then
        fail "critical confirm bypassed by auto_yes"
    fi
    unset UI_AUTO_YES
}

@test "ui_confirm_no declines on EOF, accepts explicit y, honors auto_yes" {
    if ui_confirm_no "Overwrite?" < /dev/null; then
        fail "clobber guard said yes on EOF"
    fi
    printf 'y\n' | { ui_confirm_no "Overwrite?"; }
    UI_AUTO_YES=1
    ui_confirm_no "Overwrite?" < /dev/null
    unset UI_AUTO_YES
}

@test "ui_confirm_critical accepts only a literal yes" {
    printf 'yes\n' | { ui_confirm_critical "Really?"; }
    printf 'Yes\n' | { ui_confirm_critical "Really?"; }
    if printf 'y\n' | { ui_confirm_critical "Really?"; }; then
        fail "short 'y' accepted for critical confirm"
    fi
}

@test "ui_sync_u dry run reports actions but executes nothing" {
    marker="${BATS_TEST_TMPDIR}/marker"
    mkdir -p "${UI_BIN_DIR}"
    cat > "${UI_BIN_DIR}/u-install" <<FAKE
#!/usr/bin/env bash
echo "CALLED_INSTALL \$*" >> "${marker}"
FAKE
    cat > "${UI_BIN_DIR}/u-uninstall" <<FAKE
#!/usr/bin/env bash
echo "CALLED_UNINSTALL \$*" >> "${marker}"
FAKE
    chmod +x "${UI_BIN_DIR}/u-install" "${UI_BIN_DIR}/u-uninstall"

    ui_db_add htop native
    uf="${BATS_TEST_TMPDIR}/sync.u"
    printf '# u-install export\n# format: u2\n\n[meta]\nversion=1\n\n[config]\n\n[packages]\nneovim|native|\nripgrep|nix|14.1.0\n' > "$uf"

    # dry_run=1 with auto_yes=1: analysis only, no calls to u-install/u-uninstall
    run ui_sync_u "$uf" 1 1
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Would install"
    echo "$output" | grep -q "u-install --nix ripgrep=14.1.0 -y"
    echo "$output" | grep -q "Would remove"
    echo "$output" | grep -q "u-uninstall htop -y"
    [ ! -f "$marker" ]

    # Sanity check on the harness: without dry_run the fakes do get called
    run ui_sync_u "$uf" 1 0
    [ "$status" -eq 0 ]
    [ -f "$marker" ]
    grep -q "CALLED_INSTALL" "$marker"
    grep -q "CALLED_UNINSTALL" "$marker"
}
