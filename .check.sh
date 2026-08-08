#!/usr/bin/env bash
# Local verification that ignores CRLF (the working copy is CRLF on Windows;
# .gitattributes normalizes to LF on commit, and CI runs on LF).
set -u
work="$(mktemp -d)"
mkdir -p "$work/lib" "$work/tests"
for f in u-install u-uninstall u-update u-stats u-doctor u-search u-peek u-list u-export u-import u-help install; do
    tr -d '\r' < "$f" > "$work/$f"
done
tr -d '\r' < lib/u-install.sh > "$work/lib/u-install.sh"

fail=0
for f in "$work"/u-* "$work/install" "$work/lib/u-install.sh"; do
    bash -n "$f" || { echo "SYNTAX_FAIL: $f"; fail=1; }
done
[[ $fail -eq 0 ]] && echo "SYNTAX_OK"

# --- Functional test of the new .u logic (stand-in for the bats suite) ------
export HOME="$work/home"; mkdir -p "$HOME"
# shellcheck source=/dev/null
source "$work/lib/u-install.sh"

ui_db_add neovim native
ui_db_add firefox nix
uf="$work/configuration.u"
ui_export_write > "$uf"

[[ "$(ui_uf_format "$uf")" == "u2" ]] && echo "PASS format=u2" || echo "FAIL format"
ui_uf_section "$uf" packages | head -1 | grep -q '^neovim|native|' && echo "PASS pkg line has version field" || echo "FAIL pkg line"

ui_uf_sign "$uf"
grep -q '^sha256=' "$uf" && echo "PASS signed" || echo "FAIL not signed"
ui_uf_verify "$uf"; [[ $? -eq 0 ]] && echo "PASS verify clean" || echo "FAIL verify clean"
printf 'evil|native|\n' >> "$uf"
ui_uf_verify "$uf"; [[ $? -eq 1 ]] && echo "PASS verify detects tamper" || echo "FAIL tamper not detected"

echo "u-help preview:"
HOME="$HOME" bash "$work/u-help" | head -5

rm -rf "$work"
