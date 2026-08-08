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
    [ "$output" = "u2" ]
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


@test "ui_import_apply_config rewrites the options file" {
  uf="${BATS_TEST_TMPDIR}/in.u"
  printf '# format: u1\n[config]\nprefer_source = nix\nauto_yes = true\n[packages]\n' > "$uf"
  ui_import_apply_config "$uf"
  run cat "$UI_CONFIG_FILE"
  [ "${lines[0]}" = "[options]" ]
  grep -q "prefer_source = nix" "$UI_CONFIG_FILE"
  grep -q "auto_yes = true" "$UI_CONFIG_FILE"
}
