# Agent Instructions

This repository is the source for David Uhden Collado's static website at
`https://uhden.dev` and its Tor and I2P mirrors. Read `docs/ARCHITECTURE.md` for the source and
maintenance map. Load the matching skill from
`.agents/skills/` before editing. This file is the short entry point; the skills
contain the reproducible procedures.

## Architecture

- **Hand-written static HTML, no build step.** HTML is committed and served as
  is. There is no CMS, template engine, Makefile, `cpanfile`, `package.json`, or
  asset pipeline.
- **Bilingual pages.** English and Spanish files are paired by filename. The
  usual pattern is `page.html` / `page-es.html`, with translated exceptions such
  as `services.html` / `servicios.html`, `license.html` / `licencia.html`, and
  `articles/systems.html` / `articles/sistemas.html`.
- **`templates/` contains reference boilerplates, not generator inputs.** No
  script reads them. They are excluded from the sitemap but are still present in
  the tree, so do not link to them from public pages.
- **`data/articles.json` is article metadata.** It maps each article key to its
  English and Spanish filenames and titles. It is currently read only by
  `t/integrity.t`; the feed and sitemap generators scan the filesystem directly.
- **`feeds/*.xml` and `sitemap.xml` are generated, committed artifacts.** Never
  hand-edit them. Regenerate them with the Perl scripts and review the diff.
- **`scripts/` contains maintenance tooling.** `rebuild-feeds.pl` and
  `rebuild-sitemap.pl` write generated files. `update-feeds.pl` is an
  interactive single-entry helper. `validate-website.pl` formats, validates,
  checks links, and can run the test suite and optional linters.
- **`t/` is a plain TAP suite.** Run it with `prove t` from the repository root.
  Write tests use temporary fixtures and do not modify tracked site files.
- **CI is archival only.** `.github/workflows/archive.yml` creates a signed
  source snapshot, stores it with Git LFS, rewrites history to drop the previous
  tar, and force-pushes `main`. It does not lint, test, build, or deploy. Its
  tar excludes repository documentation, VCS metadata, agent guidance,
  development settings, tests, caches, and the large disk image. Keep these
  files tracked in GitHub and out of public page content.
- **Publishing is not defined in this repository.** Do not assume GitHub Pages,
  an FTP/rsync target, or any other deployment mechanism exists. Do not add or
  run a deployment.

### Layout

| Path | Role |
| --- | --- |
| `index.html`, `blog.html`, `services.html`, `license.html` | English root pages |
| `index-es.html`, `blog-es.html`, `servicios.html`, `licencia.html` | Spanish counterparts |
| `articles/*.html` | Long-form articles and their translations |
| `templates/*.html` | Manual reference boilerplates; excluded from sitemap |
| `data/articles.json` | Article pair registry and title metadata |
| `feeds/blog.xml`, `feeds/blog-es.xml` | Generated RSS 2.0 feeds |
| `sitemap.xml` | Generated sitemap |
| `styles.css`, `ddgnoai/styles.css` | Site styles; ISC-like headers |
| `scripts/*.pl`, `scripts/*.sh` | Perl generators/validator and shell helpers |
| `t/*.t`, `t/lib/TestSite.pm` | TAP tests and fixture helpers |
| `.github/workflows/archive.yml` | Daily archive and signing workflow |
| `archive/`, `files/*.img` | Git LFS objects; do not edit by hand |
| `dprint.json`, `.perlcriticrc`, `.stylelintrc.json`, `.htmltest.yml` | Tool configuration |
| `README.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/` | GitHub and maintainer documentation; excluded from archives and server sync |

## Conventions

- HTML is formatted with `tidy` at 80 columns, two-space indentation, preserved
  entities, and LF line endings. CSS, JavaScript, and JSON are formatted with
  `dprint` at 80 columns and LF.
- Use UTF-8 and a correct `<html lang="en">` or `<html lang="es">`. Keep exactly
  one `<h1>` per page and preserve heading order.
- Root pages use relative paths such as `./styles.css`; article pages use
  `./../styles.css` and `./../index.html`. Do not introduce root-absolute
  internal links such as `/styles.css`; the mirrors rely on relative paths.
- Canonical URLs are absolute under `https://uhden.dev/`. `og:url` must equal the
  canonical. Head `hreflang` alternates are absolute; the visible language
  switch is relative and marked with `rel="alternate"`.
- Feed item links and GUIDs are root-relative by default. That is intentional so
  one feed works on the clear, Tor, and I2P mirrors.
- Preserve the skip link, `<main id="site-main" tabindex="-1">`, localized
  navigation labels, `<time datetime>`, table captions and scopes, and image
  `alt` text. Mark the active root navigation item with
  `aria-current="page"`; the validator accepts tidy 5.8's known false positive
  for that attribute.
- Keep blog listing dates and order aligned with each article's `<time>` value
  and its feed. `t/integrity.t` enforces this.
- Start `<pre><code>` blocks with the first code character. Never add a leading
  newline or indentation; it renders as a blank first line. `t/integrity.t`
  enforces this.
- Images use fluid sizing: keep `max-width: 100%`, `height: auto`, and the
  `.home-portrait` `clamp()` rule. Never add fixed `width`/`height` attributes or
  fixed pixel widths to images.
- Preserve copyright and license notices. Site pages use
  `© 2024-2026 David Uhden Collado` in footers and license pages; scripts,
  styles, and `redirect.js` carry ISC-like notices with `Copyright (c)`. Do not
  remove or rewrite them.
- Keep the site free of third-party scripts, fonts, analytics, and remote
  assets. The only inline scripts are the JSON-LD blocks on the two home pages.

## Commands that actually exist

Run commands from the repository root.

| Purpose | Command |
| --- | --- |
| Run the test suite | `prove t` |
| Run one test verbosely | `prove -v t/integrity.t` |
| Check formatting and validation only | `perl scripts/validate-website.pl --check` |
| Run the full local gate | `perl scripts/validate-website.pl --check-all` |
| Check internal links separately | `perl scripts/validate-website.pl --check --check-links` |
| Check external links (network) | `perl scripts/validate-website.pl --check --check-links --check-links-external` |
| Regenerate feeds | `perl scripts/rebuild-feeds.pl` |
| Regenerate sitemap | `perl scripts/rebuild-sitemap.pl` |
| Insert one feed entry interactively | `perl scripts/update-feeds.pl [--replace]` |
| Perl static analysis | `perlcritic scripts/*.pl` |
| CSS lint | `stylelint styles.css ddgnoai/styles.css --config .stylelintrc.json` |
| Formatting check with dprint | `dprint check` |
| Offline HTML link check | `htmltest -c .htmltest.yml` |
| Spell check | `perl scripts/validate-website.pl --check --check-spelling` |

There is no `make`, no dependency manifest, and no build command. Only add a
command to this table after verifying it against the repository.

## Validation layers

| Layer | What it means here |
| --- | --- |
| Static analysis | `--check` runs `tidy`, `xmllint`, `dprint`, and `jq`; `perlcritic`, `stylelint`, and `shellcheck` are optional. This does not execute the site. |
| Build | None. The committed files are the artifact. |
| Tests | `prove t` runs the TAP suite. `--check-all` also runs `prove` plus internal link checks and optional linters. |
| Real check | Manual browser inspection of the changed pages. There is no preview server or deployment automation in this repository. |
| Network check | `--check-links-external` performs HTTP link checks. Tests, `htmltest`, and `lychee` are offline by design; `dprint` may resolve pinned plugins on first use. |

Do not report "tests pass" when a tool was skipped. `t/links.t` skips entirely
without `tidy`; `--check-all` skips missing optional linters; `perlcritic` is not
always installed.

## Safety and scope

- Start with `git status --short`. Do not revert, clean, format, or overwrite
  changes you did not make.
- Never run `scripts/validate-website.pl` without `--check` or `--check-all`.
  Its default mode is `--apply`, which rewrites tracked files.
- The feed and sitemap generators rewrite tracked files. Run them only when the
  task is to update those artifacts, and inspect `git diff` afterward.
- Do not run `scripts/html2ogg.sh` or `scripts/svg2png.sh` for documentation
  work. They create media files next to their inputs.
- Do not install packages, change system configuration, edit `archive/` or
  `files/*.img`, trigger the archive workflow, commit, push, or force-push.
  If archive exclusions are updated, preserve every existing trigger and
  signing step.
- Do not enable external link checking, third-party embeds, or network-dependent
  tests without explicit approval.
- Do not rewrite article content, historical dates, or translations as a side
  effect of an unrelated task. Report pre-existing inconsistencies instead.
- Keep public keys public; never add private keys, tokens, or secrets to the
  repository.

## Pre-existing changes and failures

If the working tree is already dirty, identify which files are yours. Preserve
unrelated edits. If a generated artifact is already modified, determine whether
it is stale before regenerating it; do not assume your change caused the diff.
If a test fails because of existing content, report the exact failing test and
the file it names. Do not "fix" content outside the requested scope.

## Skills

| Skill | Load it when |
| --- | --- |
| `static-site-content` | Adding or editing an HTML page, article, navigation, metadata, or local asset |
| `bilingual-page-consistency` | Touching either side of an English/Spanish pair, or changing filenames, hreflang, or anchors |
| `perl-site-generation` | Changing `scripts/*.pl`, generator behavior, or the validator |
| `feeds-and-sitemaps` | Adding or updating an article, or changing feeds, dates, metadata, or `sitemap.xml` |
| `web-quality-and-publishing` | Running validation/lint, reviewing accessibility or web security, or answering CI/archive/publishing questions |

## Continuous Agent & Skills Maintenance

Every repository change MUST trigger an Agent & Skills Maintenance Review.
Agent instructions and skills are living repository artifacts. Before
completing any repository modification, review all applicable `AGENTS.md`
files, specialized agents, and `SKILL.md` files. Update the affected knowledge
artifacts to reflect the implementation, correct outdated instructions, and
incorporate reusable knowledge. A task is incomplete until knowledge
synchronization has been performed and validated. Never skip synchronization
silently or claim that unexecuted checks have passed.

After each change:

1. Identify and review the applicable agents and skills, even when no update
   initially appears necessary.
2. Update relevant operational guidance, reusable procedures, references,
   commands, and paths; remove stale or contradictory instructions.
3. Do not use whitespace-only, timestamp-only, empty, or otherwise cosmetic
   edits to satisfy synchronization. For a project change, at least one
   relevant knowledge artifact must receive a substantive update.
4. Run `python3 scripts/validate-agent-knowledge.py --scope worktree` and the
   applicable project checks. For a pull request, CI compares the base and head
   revisions with `--scope range --base BASE_SHA --head HEAD_SHA`.
5. Review the validator output and final diff, then report the synchronization
   result. Warnings require human review; a structural pass does not establish
   semantic relevance.

Run the validator tests with
`python3 -m unittest discover -s tests/agent_knowledge_validator -p 'test_*.py'`.
The validator is read-only and uses Python 3.11+ and the standard library. It
must not be confused with project-specific validation or installation tools.
See [Agent Knowledge Validation Contract](docs/agent-knowledge-validation.md)
for AK001–AK006, JSON schema, exit codes, configuration, and maintenance rules.

All repositories must implement the same Agent Knowledge Validation CLI
contract, rule identifiers, output conventions and exit codes. Repository-
specific validations may extend the canonical behavior but must not silently
redefine it. Any change to the validator contract must be reflected in the
repository's agent instructions, related skills and tests.
