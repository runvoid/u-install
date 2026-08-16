#!/usr/bin/env bash
# Regenerate the command reference in docs/commands.html from the real
# `--help` output of every u-* command, so the docs can never fall behind.
#
# Usage: bash tools/gen-docs.sh [--check]
#   --check   regenerate into a temp copy and exit 1 if docs/commands.html
#             would change (used by CI to enforce up-to-date docs).
set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$(pwd)"

commands=(u-install u-uninstall u-update u-upgrade u-search u-peek u-list u-outdated u-info u-diff u-sync u-history u-clean u-stats u-doctor u-export u-import u-help)

# The scripts source the library from $HOME at runtime; stage a throwaway
# HOME so --help works without a real installation.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home/.local/share/u-install/lib"
cp lib/u-install.sh "$tmpdir/home/.local/share/u-install/lib/"

html_escape() {
    # sed instead of ${var//</&lt;}: in newer bash (5.3) "&" in the
    # replacement refers to the match, breaking the expansion-based version.
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

gen_block() {
    local out="$1" cmd
    : > "$out"
    for cmd in "${commands[@]}"; do
        local help_out=""
        help_out="$(HOME="$tmpdir/home" bash "$repo_root/$cmd" --help 2>/dev/null || true)"
        if [[ -z "$help_out" ]]; then
            echo "WARN: no --help output for $cmd" >&2
            continue
        fi

        # First paragraph after the version header line = short description.
        local desc_line="" header_seen=0 collecting=0 line
        while IFS= read -r line; do
            if [[ "$header_seen" -eq 0 ]]; then
                header_seen=1
                continue
            fi
            if [[ "$collecting" -eq 0 ]]; then
                [[ -z "$line" ]] && continue
                collecting=1
            fi
            [[ -z "$line" ]] && break
            [[ -n "$desc_line" ]] && desc_line+=" "
            desc_line+="$line"
        done <<< "$help_out"
        [[ -z "$desc_line" ]] && desc_line="$cmd"

        {
            printf '      <div class="cmd-item">\n'
            printf '        <h3><code>%s</code></h3>\n' "$(html_escape "$cmd")"
            printf '        <p>%s</p>\n' "$(html_escape "$desc_line")"
            printf '        <div class="code-block"><pre><code>%s</code></pre></div>\n' "$(html_escape "$help_out")"
            printf '      </div>\n'
        } >> "$out"
    done
}

# Splice the block between the AUTOGEN markers, reading the insertion from a
# file (getline) so no awk string escaping can corrupt the HTML.
splice() {
    local src="$1" block="$2" dst="$3"
    awk -v block="$block" -v dst="$dst" '
        BEGIN { while ((getline line < block) > 0) repl = repl line "\n" }
        /<!-- AUTOGEN:COMMANDS:START -->/ { print > dst; inblock=1; printf "%s", repl > dst; next }
        /<!-- AUTOGEN:COMMANDS:END -->/   { inblock=0; print > dst; next }
        !inblock { print > dst }
    ' "$src"
}

target="docs/commands.html"
[[ -f "$target" ]] || { echo "ERROR: $target not found" >&2; exit 1; }

gen_block "$tmpdir/block.html"
[[ -s "$tmpdir/block.html" ]] || { echo "ERROR: generated empty command list" >&2; exit 1; }

if [[ "${1:-}" == "--check" ]]; then
    splice "$target" "$tmpdir/block.html" "$tmpdir/commands.new.html"
    if diff -q "$target" "$tmpdir/commands.new.html" >/dev/null; then
        echo "DOCS_OK: docs/commands.html is up to date"
    else
        echo "DOCS_STALE: docs/commands.html differs from --help output" >&2
        echo "Run: bash tools/gen-docs.sh" >&2
        diff "$target" "$tmpdir/commands.new.html" | head -20 >&2 || true
        exit 1
    fi
    exit 0
fi

splice "$target" "$tmpdir/block.html" "$tmpdir/commands.new.html"
mv "$tmpdir/commands.new.html" "$target"
echo "OK: regenerated command reference in $target"
