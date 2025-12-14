#!/bin/bash

if [[ -z "${ZSH_VERSION:-}" ]] && command -v zsh >/dev/null 2>&1; then
    exec zsh "$0" "$@"
fi

set -euo pipefail

# Script to format HTML files using tidy
#
# Copyright (c) 2025 David Uhden Collado <david@uhden.dev>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# Basic PATH (important when run from cron)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

if [[ -t 1 && "${NO_COLOR:-}" != "1" ]]; then
  GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
else
  GREEN=""; YELLOW=""; RED=""; RESET=""
fi

log()   { printf '%s %b[INFO]%b ✅ %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s %b[WARN]%b ⚠️ %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$YELLOW" "$RESET" "$*" >&2; }
error() { printf '%s %b[ERROR]%b ❌ %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$RED" "$RESET" "$*" >&2; }

ROOT="${1:-$(dirname "$0")/..}"

ensure_tidy() {
    if command -v tidy >/dev/null 2>&1; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        warn "tidy not found; attempting installation with apt-get ..."
        cmd=(apt-get install -y tidy)
        if command -v sudo >/dev/null 2>&1; then
            cmd=(sudo "${cmd[@]}")
        fi
        if "${cmd[@]}"; then
            return 0
        fi
        error "apt-get failed to install tidy"
    else
        error "tidy is not installed and apt-get is unavailable"
    fi

    return 1
}

format_html_files() {
    find "$ROOT" -type f -name '*.html' -print0 |
    while IFS= read -r -d '' file; do
        tidy -indent -quiet -wrap 80 -utf8 \
          --indent-spaces 2 \
          --tidy-mark no \
          --preserve-entities yes \
          --vertical-space yes \
          -modify "$file" || warn "tidy issues in $file"
    done
}

main() {
    ensure_tidy || exit 1
    format_html_files
}

main "$@"
