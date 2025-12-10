#!/bin/bash
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

ROOT="${1:-$(dirname "$0")/..}"

ensure_tidy() {
    if command -v tidy >/dev/null 2>&1; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        echo "tidy not found; attempting installation with apt-get ..." >&2
        cmd=(apt-get install -y tidy)
        if command -v sudo >/dev/null 2>&1; then
            cmd=(sudo "${cmd[@]}")
        fi
        if "${cmd[@]}"; then
            return 0
        fi
        echo "error: apt-get failed to install tidy" >&2
    else
        echo "error: tidy is not installed and apt-get is unavailable" >&2
    fi

    return 1
}

ensure_tidy || exit 1

find "$ROOT" -type f -name '*.html' -print0 |
while IFS= read -r -d '' file; do
  tidy -indent -quiet -wrap 0 -utf8 \
    --indent-spaces 2 \
    --tidy-mark no \
    --preserve-entities yes \
    --vertical-space yes \
    -modify "$file" || echo "warning: tidy issues in $file" >&2
done
