---
name: perl-site-generation
description: Maintain the Perl generators and website validator safely while preserving deterministic output, atomic writes, and the fixture-based test suite.
---

# Perl site generation

## When to use this skill

Use this skill when you need to:

- change `scripts/rebuild-feeds.pl`, `scripts/rebuild-sitemap.pl`, or
  `scripts/update-feeds.pl`;
- change `scripts/validate-website.pl`;
- add a maintenance script under `scripts/`;
- debug generator output, XML escaping, dates, file modes, or atomic writes;
- update the TAP tests that cover these scripts.

Use `feeds-and-sitemaps` for the content-level feed/sitemap workflow and
`web-quality-and-publishing` for the validation policy.

## Script inventory

| Script | Role | Writes tracked files |
| --- | --- | --- |
| `scripts/rebuild-feeds.pl` | Rebuilds every detected feed from article metadata. Optional `--base-url URL`. | Yes, `feeds/*.xml` |
| `scripts/rebuild-sitemap.pl` | Rebuilds `sitemap.xml` from public HTML. | Yes, `sitemap.xml` |
| `scripts/update-feeds.pl` | Interactive one-entry feed updater. Optional `--replace`. | Yes, feeds |
| `scripts/validate-website.pl` | Formats, validates, checks links/spelling, and can run tests and linters. | Yes, unless `--check` or `--check-all` |
| `scripts/html2ogg.sh` | Converts one HTML file to OGG speech. Interactive. | Yes, creates `.ogg` |
| `scripts/svg2png.sh` | Converts SVG files to PNG recursively. | Yes, creates `.png` |

All scripts are mode `0750`; tests are mode `0640`. Invoke tests with `prove` or
`perl`, not by executing them directly.

## Before changing a script

1. Read the script header, which contains its usage and license notice.
2. Run `git status --short`. Preserve unrelated changes.
3. Reproduce the current behavior in a temporary fixture. Do not experiment with
   the write scripts in the repository root.
4. Read the matching tests under `t/` and `t/lib/TestSite.pm`.

`TestSite::fixture` creates a temporary repository, copies the real scripts into
it, chmods them to `0755`, and writes fixture files. The scripts derive their root
from `$0`, so they operate on the fixture, not the real tree.
`TestSite::clone_repo` copies the working tree, including uncommitted changes, and
skips `.git`, `archive`, `files`, `images`, and `t` by default.

## Procedure

1. Make the smallest change that solves the problem.
2. Keep `use strict; use warnings;`, core Perl modules, and the existing
   script-relative root detection. Do not add a dependency manifest or require a
   non-core module without explicit approval.
3. Preserve atomic writes: same-directory `File::Temp`, UTF-8 output, mode
   preservation, `rename`, and cleanup of the temporary file on failure.
4. Preserve the ISC-like header and copyright notice in existing files.
5. Check syntax:

   ```sh
   prove t/00-syntax.t
   ```

   This compiles every `scripts/*.pl` with the same Perl that runs the tests and
   runs `sh -n` on every `scripts/*.sh` when `sh` is available.

6. Run focused tests, for example:

   ```sh
   prove t/rebuild-feeds.t
   prove t/rebuild-sitemap.t
   prove t/update-feeds.t
   prove t/links.t
   ```

7. If generator output changed, regenerate the tracked artifacts only when the
   task intends it, then run:

   ```sh
   prove t/reproducible.t
   ```

8. Run Perl::Critic when it is installed:

   ```sh
   perlcritic scripts/*.pl
   ```

   `.perlcriticrc` sets severity 3 and disables seven policies with written
   justifications. Do not add `## no critic` suppressions without a specific
   reason.

9. Run the full suite:

   ```sh
   prove t
   ```

10. Inspect `git diff` and confirm that only intended files changed. Generated
    output changes should be explained by the script change, not by formatting
    noise.

## Invariants to preserve

### Feeds

- Output is byte-reproducible across runs, time zones, and locales.
- Items are sorted by date descending, then slug ascending.
- `articles/index.html` is skipped.
- English and Spanish feeds remain language-separated based on `<html lang>`.
- XML escaping is single-pass. HTML entities are decoded once and re-escaped
  once; `&amp;amp;` is a bug.
- Invalid XML character references become U+FFFD.
- `lastBuildDate` is the newest item date, not the current time. An empty feed
  preserves its existing `lastBuildDate`, or uses the Unix epoch if absent.
- Item links and GUIDs stay root-relative unless `--base-url` is explicitly
  supplied; GUIDs stay root-relative even then.
- Feed detection prefers `blog.xml`/`blog-es.xml` over
  `articles.xml`/`articles-es.xml` and fails when no supported feed exists.
- Writes are atomic, preserve the existing file mode, and leave no `.tmp-*`
  files.

### Sitemap

- Includes all public HTML recursively except paths under `archive/` and
  `templates/`.
- `index.html` becomes the directory URL; `sub/index.html` becomes `/sub/`.
- Entries are sorted and deterministic.
- The XML declaration is exactly `<?xml version="1.0" encoding="UTF-8"?>`.
- No `lastmod`, `changefreq`, or `priority` is fabricated.
- The site host is currently hardcoded as `https://uhden.dev`.
- Writes are atomic, preserve mode, and leave no `.tmp-*` files.

### Validator

- Default mode is `--apply`, which rewrites files. Always use `--check` or
  `--check-all` in an agent workflow.
- Exit codes are `0` for success, `2` for formatting/validation failure, and `1`
  for tooling or usage errors.
- `--check-all` implies `--check` and internal link checking, runs `prove t/`,
  and runs optional linters when installed.
- Required tools depend on file types: `tidy` for HTML, `xmllint` for XML/SVG,
  `dprint` for CSS/JS/JSON, `jq` for JSON, `curl` for external links, and
  `hunspell` for spelling.
- Optional `--check-all` tools are `vnu`, `stylelint`, `shellcheck`, `perlcritic`,
  `htmltest`, and `lychee`. Missing tools are skipped, not fatal.
- tidy 5.8 reports `aria-current` as a proprietary attribute. The validator
  explicitly allows only that known diagnostic; every other warning still
  fails. Do not remove `aria-current` or mute tidy warnings globally.
- On OpenBSD, dprint is skipped because it is not ported.
- Link reports are written to the system temporary directory; they are not
  tracked artifacts.

## Shell scripts

`html2ogg.sh` uses `pandoc`, `espeak-ng`, and `ffmpeg`, asks for a language on
stdin, writes `<input>.ogg` next to the input, and overwrites an existing output.
`svg2png.sh` uses `rsvg-convert`, defaults to the current directory, writes
500px-wide PNGs next to each SVG, and skips existing PNGs. Both are tested with
stub binaries; the tests do not perform real media conversion.

Do not run either script as a validation step. They create files next to their
inputs.

## Frequent problems

- **Running generators in the repository root by accident.** They immediately
  rewrite tracked files. Use a fixture or a temporary copy unless the task is to
  regenerate.
- **Passing `--base-url` for committed feeds.** It changes links and the Atom
  self link, breaks the root-relative assumptions in `t/integrity.t`, and makes
  `t/reproducible.t` fail. Commit the default relative output.
- **Double XML escaping.** Decode entities once, then escape once.
- **Losing file mode.** Keep the existing `chmod` logic in the atomic writer.
- **Leaving temporary files.** Delete the temp file on every error path.
- **Missing `<time>`.** Feed dates fall back to file mtime and become
  nondeterministic.
- **Assuming tests use `HEAD`.** `t/reproducible.t` copies the current working
  tree, including uncommitted changes.
- **Expecting `perlcritic` to run.** It is optional and may be absent. Report it
  as skipped.
- **Assuming `t/links.t` ran.** It calls `plan skip_all` when `tidy -v` fails.
- **Testing `--replace`.** `t/update-feeds.t` does not cover `--replace`; add
  coverage if you change it.
- **Relying on `update-feeds.pl` metadata.** It inserts an item and then runs
  `rebuild-feeds.pl` if the script is executable; the rebuild re-derives title,
  description, and date from the article HTML. The article is the source of
  truth.
- **Modifying test sandboxing casually.** Changing `fixture` or `clone_repo` to
  use the real repository root would make write tests mutate tracked files.

## References

- `AGENTS.md`
- `scripts/rebuild-feeds.pl`, `scripts/rebuild-sitemap.pl`
- `scripts/update-feeds.pl`, `scripts/validate-website.pl`
- `scripts/html2ogg.sh`, `scripts/svg2png.sh`
- `t/00-syntax.t`, `t/rebuild-feeds.t`, `t/rebuild-sitemap.t`
- `t/update-feeds.t`, `t/reproducible.t`, `t/links.t`, `t/shell.t`
- `t/lib/TestSite.pm`
- `.perlcriticrc`, `dprint.json`, `scripts/openbsd-tools.txt`
