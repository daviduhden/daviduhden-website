---
name: bilingual-page-consistency
description: Keep English and Spanish pages structurally consistent with correct filenames, hreflang links, language switches, and metadata without overwriting intentional translation differences.
---

# Bilingual page consistency

## When to use this skill

Use this skill when you need to:

- edit only one side of an English/Spanish pair;
- add a new translated page or article;
- change a filename, page title, description, date, navigation label, or anchor
  that exists in both languages;
- review whether two pages are equivalent;
- fix a broken language switch or reciprocal `hreflang` link.

Also load `static-site-content` for page structure and `feeds-and-sitemaps` when
metadata or dates affect generated files.

## Pairing map

The repository uses two naming conventions: an `-es` suffix and translated
filenames. Always take the mapping from the existing files and
`data/articles.json`, not from the suffix alone.

| English | Spanish |
| --- | --- |
| `index.html` | `index-es.html` |
| `blog.html` | `blog-es.html` |
| `services.html` | `servicios.html` |
| `license.html` | `licencia.html` |
| `articles/gpl.html` | `articles/gpl-es.html` |
| `articles/openbsd.html` | `articles/openbsd-es.html` |
| `articles/openbsd-install-fat32.html` | `articles/openbsd-install-fat32-es.html` |
| `articles/ryf-fsdg.html` | `articles/ryf-fsdg-es.html` |
| `articles/unix.html` | `articles/unix-es.html` |
| `articles/systems.html` | `articles/sistemas.html` |
| `templates/articles.html` | `templates/articles-es.html` (reference only) |
| `ddgnoai/index.html` | none; English-only utility page |

## What must match

Keep **structural and factual parity**, not literal wording:

- the same page role and equivalent sections;
- the same commands, code blocks, filenames, URLs, and dates;
- the same document metadata fields, localized where appropriate;
- one `<h1>` with the same meaning, registered in `data/articles.json` for
  articles;
- equivalent navigation items, footer license link, and language switch;
- equivalent tables, captions, footnotes, and useful-link asides.

Do **not** make the Spanish page a copy of the English prose. Do not replace a
nuanced translation with machine translation or with the English text. Existing
articles intentionally use natural Spanish wording, Spanish headings, and
localized anchor ids.

## Procedure

1. Read `AGENTS.md` and run `git status --short`.
2. Identify the pair from the table or `data/articles.json`.
3. Compare the two pages section by section: `<head>` metadata, navigation,
   `<h1>`, headings, links, code, dates, asides, and footer. Compare structure
   and facts, not sentence-by-sentence prose.
4. Apply the content change on both sides. Preserve intentional differences in
   wording and examples.
5. If a filename or title changed, update `data/articles.json` for both
   languages. `title_en` and `title_es` must match the visible `<h1>` exactly.
6. Update the reciprocal head links:

   ```html
   <!-- English page -->
   <link rel="alternate" hreflang="es" href="https://uhden.dev/articles/slug-es.html">

   <!-- Spanish page -->
   <link rel="alternate" hreflang="en" href="https://uhden.dev/articles/slug.html">
   ```

7. Update the visible switch in both navigation menus:

   ```html
   <a class="lang-switch" href="./slug-es.html" rel="alternate"
      hreflang="es">Español</a>
   ```

   The Spanish page links to the English file with `hreflang="en">English`.

8. Localize anchor ids and TOC targets. Spanish pages do not share English
   fragment ids; cross-language fragment links must be remapped explicitly.
9. If the article was added or its title/date changed, update both
   `blog.html` and `blog-es.html`.
10. Regenerate feeds and sitemap with `feeds-and-sitemaps`.
11. Run the validation commands below and inspect both pages in a browser.

## Rules and limits

- The language switch text is `Español` on English pages and `English` on
  Spanish pages. Keep `rel="alternate"` and the target-language `hreflang`.
- Canonical URLs are self-referential per page. The English home page uses
  `https://uhden.dev/`; the Spanish home page uses
  `https://uhden.dev/index-es.html`.
- `hreflang="x-default"` is not used in this site. Do not add it without an
  explicit decision.
- Do not add a language switch to `ddgnoai/index.html`; it is intentionally
  English-only.
- The templates are not public content and are excluded from the sitemap. Do not
  treat their language switch to the home page as an article pattern.
- Tests check that a reciprocal `hreflang` string exists somewhere in the file.
  That means a nav switch alone can satisfy the test even if the head link is
  missing. Verify both manually.

## Consistency invariants

These are now enforced or intentionally maintained. Keep them in sync:

- `licencia.html` lists the same script files as `license.html`, including
  `./scripts/rebuild-sitemap.pl`.
- `index-es.html` has a JSON-LD `WebSite` `url` matching its canonical,
  `https://uhden.dev/index-es.html`.
- Spanish headings use sentence case, including the headings in
  `articles/gpl-es.html`.
- `blog.html` and `blog-es.html` use the same dates and order as their article
  `<time>` values and generated feeds. `t/integrity.t` checks both.
- The active root navigation item uses `aria-current="page"`. Images use fluid
  CSS sizing rather than fixed `width`/`height` attributes.
- Supplementary asides still sit outside `<main>`; improve the page you are
  touching rather than performing a broad refactor without a request.

## Validation

Run from the repository root:

```sh
perl scripts/validate-website.pl --check
prove t/integrity.t
prove t/reproducible.t
prove t
```

- `t/integrity.t` checks article registration, exact `<h1>` matches, and
  reciprocal hreflang for article pairs.
- `t/reproducible.t` checks generated feeds and sitemap after regeneration.
- `prove t` is the full suite.
- Manual browser inspection is the real check: language switch, navigation,
  anchors, tables, and layout in both languages.

## Frequent problems

- **Suffix assumption.** `systems.html` maps to `sistemas.html`, not
  `systems-es.html`.
- **One-sided edit.** Updating only the English title/date leaves the Spanish
  page and feed inconsistent.
- **Head link missing.** The nav switch is not a substitute for the head
  `hreflang` alternate.
- **Wrong target language.** On the Spanish page, `hreflang` must be `en`, not
  `es`.
- **Copied anchors.** English ids copied into Spanish break localized TOCs.
- **Untranslated metadata.** `<title>`, description, Open Graph text, and
  `aria-label` values should be natural Spanish on Spanish pages.
- **Code drift.** Commands and code blocks should stay identical unless the
  platform or translation genuinely requires a difference.
- **Blog listing drift.** The listing is manual and untested; update both files.
- **Overwriting intentional differences.** Do not turn a translation into a
  duplicate of the English article.

## References

- `AGENTS.md`
- `data/articles.json`
- `index.html`, `index-es.html`
- `articles/systems.html`, `articles/sistemas.html`
- `templates/articles.html`, `templates/articles-es.html`
- `t/integrity.t`
- `scripts/rebuild-feeds.pl`, `scripts/rebuild-sitemap.pl`
