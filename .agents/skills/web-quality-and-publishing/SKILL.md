---
name: web-quality-and-publishing
description: Validate formatting, links, accessibility, security, and CI or archive behavior before publication, and distinguish offline checks from network or deployment actions.
---

# Web quality and publishing

## When to use this skill

Use this skill when you need to:

- choose the right validation command for a change;
- run formatting, link, spelling, accessibility, or security checks;
- interpret a skipped test or optional linter;
- change or review `.github/workflows/archive.yml`;
- answer questions about publication, the archive, or `uhden.dev`;
- prepare a change summary that separates static checks, tests, and real
  browser checks.

## Validation matrix

Run commands from the repository root.

| Layer | Command | What it runs | Mutates tracked files |
| --- | --- | --- | --- |
| Static formatting/validation | `perl scripts/validate-website.pl --check` | `tidy`, `xmllint`, `dprint`, `jq` | No |
| Internal links | `perl scripts/validate-website.pl --check --check-links` | HTML/CSS link extraction and resolution | No in `--check` mode |
| Full local gate | `perl scripts/validate-website.pl --check-all` | The above, `prove t/`, and optional linters | No tracked files; temporary reports |
| Tests | `prove t` | Eight TAP files | No tracked files |
| Perl lint | `perlcritic scripts/*.pl` | Perl::Critic with `.perlcriticrc` | No |
| CSS lint | `stylelint styles.css ddgnoai/styles.css --config .stylelintrc.json` | Stylelint rules | No |
| CSS/JS/JSON format check | `dprint check` | Pinned dprint plugins | No |
| HTML link check | `htmltest -c .htmltest.yml` | Offline links, anchors, images, metadata | No |
| Offline link check | `lychee --offline --no-progress --root-dir . --exclude-path .git --exclude-path archive --exclude-path tmp --exclude-path files .` | Internal links | No |
| External links | `perl scripts/validate-website.pl --check --check-links --check-links-external` | Network requests to remote URLs | No, but uses the network |
| Spelling | `perl scripts/validate-website.pl --check --check-spelling` | `hunspell` with `en_US`/`es_ES` | No |
| Browser | Open the changed pages manually | Layout, language switch, anchors, forms | No |

There is no build step. The committed files are the deployable artifact.

## Formatting and lint configuration

- `dprint.json`: 80-column width, LF line endings, pinned TypeScript, Malva
  (CSS), and JSON plugins. The validator uses an equivalent temporary config and
  skips dprint on OpenBSD because it is not ported.
- `.stylelintrc.json`: checks unknown at-rules, empty blocks, invalid hex colors,
  duplicate properties/selectors, invalid comments, unknown properties,
  pseudo-classes, pseudo-elements, units, and related syntax.
- `.perlcriticrc`: severity 3. Seven policies are disabled with written
  justifications. Read the file before adding suppressions.
- `.htmltest.yml`: offline checks for doctype, anchors, internal links, images,
  metadata, and generic markup. `CheckExternal` is false. It ignores `onion`,
  `i2p`, `mailto:`, `tel:`, `bitcoin:`, and `monero:` URLs.
- `tidy` is the HTML formatter and validator: 80 columns, two-space indent, no
  tidy mark, preserved entities, vertical space.

## Skips and coverage limits

Report skips explicitly. A green run is not proof that every layer ran.

- `t/links.t` calls `plan skip_all` when `tidy -v` fails. Without `tidy`, link
  checker behavior is untested.
- `t/00-syntax.t` skips shell syntax checks when `sh` is unavailable, but
  `t/shell.t` does not skip.
- `--check-all` prints a warning and skips a missing optional tool: `vnu`,
  `stylelint`, `shellcheck`, `perlcritic`, `htmltest`, or `lychee`.
- `prove` is skipped by `--check-all` if it is not installed.
- `curl` is required only for explicit external link checking.
- `hunspell` and the configured dictionaries are required only for spelling.
- `t/reproducible.t` tests the working tree, not `git HEAD`; uncommitted changes
  are included.
- The tests do not parse XML with a schema validator and do not fetch external
  links.
- `t/update-feeds.t` does not cover `--replace`.
- There is no CI job that runs any of these checks. They are local/manual.

## Accessibility checklist

Preserve the existing patterns:

- skip link at the top of the page, pointing to `#site-main`;
- one `<main id="site-main" tabindex="-1">`;
- one `<h1>` and a logical heading order;
- correct `<html lang>`;
- localized `aria-label` on primary navigation and TOCs;
- `aria-current="page"` on the active root navigation item;
- `aria-labelledby` on footnotes and useful-link asides;
- meaningful `alt` text on images;
- table `<caption>` and `<th scope>`;
- `<label for>` on form controls;
- `<time datetime="...">` with human-readable text;
- TOC links that resolve to real ids on the same page.

Known gaps that are not automatically checked: supplementary asides outside
`<main>`, color contrast, and focus order. Images intentionally use fluid CSS
sizing instead of fixed `width`/`height` attributes; keep that behavior. Improve
the page you are already changing; do not launch a site-wide accessibility
refactor as a side effect.

`tidy` 5.8 reports `aria-current` as a proprietary attribute because it predates
that ARIA state. `validate-website.pl` accepts only that specific diagnostic;
all other tidy warnings still fail validation. Do not remove `aria-current` to
silence the warning.

## Web security checklist

- Keep the site static and self-contained. Do not add third-party scripts,
  analytics, remote fonts, or CDN assets.
- The only inline scripts are the JSON-LD blocks on `index.html` and
  `index-es.html`. `redirect.js` exists but is not loaded by any page; do not
  wire it in without an explicit decision about client-side redirects.
- Keep local assets under `images/`, `feeds/`, and `styles.css`. Preserve the
  existing `favicon.ico` and PGP/SSH public keys.
- Tor and I2P links intentionally use `http://` and `.onion`/`.i2p` hosts. Do not
  remove them or "upgrade" them to HTTPS.
- `mailto:`, `bitcoin:`, and `monero:` links are intentional. Link tooling skips
  those schemes; do not add them to feeds or the sitemap.
- Canonical URLs are absolute; internal navigation is relative; feed links are
  root-relative. Do not collapse these choices into one scheme.
- There is no CSP meta tag, referrer policy, or SRI because there are no remote
  assets. Adding one is a design decision, not a routine formatting change.
- If you introduce `target="_blank"`, add `rel="noopener noreferrer"`.
- Never add private keys, tokens, secrets, or signing material. The files
  `pgp_public_key_rsa4096.asc`, `ssh_public_key.pub`, and
  `archive/daviduhden-website.pub` are public keys.
- The `ddgnoai/` page has a GET search form to `https://noai.duckduckgo.com/`.
  Preserve its label and hidden parameters unless the task is about that page.

## CI, archive, and publication

The only workflow is `.github/workflows/archive.yml`.

- It runs daily at midnight UTC and on manual dispatch. It does not run on
  `push` or `pull_request`.
- It checks out with full history and LFS, installs `clang`, `libbsd-dev`, and
  `git-filter-repo`, and builds or installs `signify`.
- It stops when the last commit is already an `Archive website...` bot commit.
- It creates a pax/gzip tar excluding `.git`, `.github`, `.gitattributes`,
  `archive/`, `files/*.img`, and `tmp_archive/`.
- It signs the `.sha256` checksum, not the tar. The private key is written to a
  temporary file with mode `0600` and removed with `shred -u`.
- It tracks `archive/*.tar.gz` with Git LFS, runs
  `git filter-repo --invert-paths` to remove the previous tar from history, and
  force-pushes `main` with the repository token.
- The third-party `actions/checkout` action is pinned by a full commit SHA.

Do not run, dispatch, or edit this workflow as part of content work. Do not
reproduce its force-push or history rewrite locally. If asked to change it,
preserve SHA pinning, least privilege, secret isolation, and the no-PR-trigger
property.

`archive/` is workflow-owned. Read-only verification is safe when the tools are
available:

```sh
cd archive
sha256sum -c daviduhden-website.tar.gz.sha256
signify -V -p daviduhden-website.pub \
  -m daviduhden-website.tar.gz.sha256 \
  -x daviduhden-website.tar.gz.sig
```

Publication to `uhden.dev` is not defined in this repository. There is no CNAME,
GitHub Pages workflow, deploy script, rsync target, or server configuration.
Do not invent a deployment command or claim a change was published. If the task
requires publication, ask the repository owner for the actual mechanism.

## Reporting results

In the final response, state:

- which commands actually ran;
- whether each passed, failed, or was skipped;
- which optional tools were missing;
- whether any network access occurred;
- which files changed and which generated artifacts were regenerated;
- which checks were manual browser checks;
- any pre-existing failures or inconsistencies found.

Do not write "all tests pass" when `t/links.t` skipped, optional linters were
absent, or the browser check was not performed.

## Frequent problems

- **Running the validator bare.** The default is `--apply`; it rewrites files.
- **Assuming `--check` runs tests.** It does not; use `prove t` or
  `--check-all`.
- **Assuming `--check-all` is exhaustive.** It skips missing tools and does not
  check external links or perform a browser check.
- **Expecting external links to be checked.** They are skipped unless
  `--check-links-external` is passed, which uses the network.
- **Expecting `t/links.t` to run.** It skips without `tidy`.
- **Expecting a CI gate.** There is no test or lint workflow.
- **Treating the archive as a deployment.** It is a signed source snapshot, not
  a release or deploy job.
- **Force-pushing or rewriting history locally.** Leave that to the workflow.
- **Leaving link reports.** The validator writes a temporary
  `validate-website-links-report-*.txt` in the system temporary directory; it is
  not a tracked artifact.
- **Adding a deploy workflow.** The correct action is to ask for the real
  publication process, not to guess one.

## References

- `AGENTS.md`
- `scripts/validate-website.pl`
- `.github/workflows/archive.yml`
- `dprint.json`, `.perlcriticrc`, `.stylelintrc.json`, `.htmltest.yml`
- `t/00-syntax.t`, `t/links.t`, `t/reproducible.t`, `t/shell.t`
- `archive/`, `.gitattributes`
- `robots.txt`, `sitemap.xml`
- `index.html`, `index-es.html`, `ddgnoai/index.html`
