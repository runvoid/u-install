#!/usr/bin/env bash
# Regenerate web/src/data/commands.json from the real `--help` output of
# every u-* command. The website (built by Vite into docs/) renders its
# command reference from this file, so the docs can never fall behind.
#
# Usage: bash tools/gen-docs.sh [--check]
#   --check   regenerate into a temp file and exit 1 if the committed
#             commands.json would change (used by CI).
set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$(pwd)"

commands=(u-install u-uninstall u-update u-upgrade u-search u-peek u-list u-outdated u-info u-diff u-sync u-history u-clean u-stats u-doctor u-export u-import u-help)
target="web/src/data/commands.json"
mkdir -p "$(dirname "$target")"

# The scripts source the library from $HOME at runtime; stage a throwaway
# HOME so --help works without a real installation.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home/.local/share/u-install/lib"
cp lib/u-install.sh "$tmpdir/home/.local/share/u-install/lib/"

version="$(HOME="$tmpdir/home" bash "$repo_root/u-install" --version | awk '{print $2}')"

json_escape() {
    # backslash, quote, then join lines with \n (pure sed/awk, no jq needed)
    printf '%s' "$1" \
        | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
        | awk '{ printf "%s\\n", $0 }' \
        | sed 's/\\n$//'
}

gen() {
    local out="$1" cmd
    printf '{\n' > "$out"
    printf '  "version": "%s",\n' "$version" >> "$out"
    printf '  "commands": [\n' >> "$out"
    local first=1
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

        [[ "$first" -eq 0 ]] && printf ',\n' >> "$out"
        first=0
        {
            printf '    {\n      "name": "%s",\n' "$cmd"
            printf '      "description": "%s",\n' "$(json_escape "$desc_line")"
            printf '      "help": "%s"\n    }' "$(json_escape "$help_out")"
        } >> "$out"
    done
    printf '\n  ]\n}\n' >> "$out"
}

if [[ "${1:-}" == "--check" ]]; then
    gen "$tmpdir/commands.json"
    if diff -q "$target" "$tmpdir/commands.json" >/dev/null; then
        echo "DOCS_OK: $target is up to date"
    else
        echo "DOCS_STALE: $target differs from --help output" >&2
        echo "Run: bash tools/gen-docs.sh && (cd web && npm run build)" >&2
        diff "$target" "$tmpdir/commands.json" | head -10 >&2 || true
        exit 1
    fi
    exit 0
fi

gen "$target"
echo "OK: regenerated $target"
