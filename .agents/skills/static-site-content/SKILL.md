---
name: static-site-content
description: Add or edit hand-written HTML pages, articles, navigation, metadata, and local assets, then register the content and run the appropriate checks.
---

# Static site content

## When to use this skill

Use this skill when you need to:

- add or edit a root page such as `index.html`, `blog.html`, `services.html`, or
  `license.html`;
- add or edit an article under `articles/`;
- change navigation, footer, page metadata, canonical URLs, or social metadata;
- add or replace a local image or stylesheet reference;
- register a new article for the bilingual index, blog listing, feeds, or
  sitemap.

Use `bilingual-page-consistency` as well whenever a page has an English/Spanish
counterpart. Use `feeds-and-sitemaps` for the generation step, and
`web-quality-and-publishing` for validation or publishing questions.

## Before editing

1. Read `AGENTS.md`.
2. Run `git status --short`. Preserve unrelated changes; do not reset or clean.
3. Identify the counterpart page. Check `data/articles.json` for articles and the
   filename mapping in `bilingual-page-consistency`.
4. Read the nearest existing page of the same type. Follow its structure rather
   than inventing a new layout.
5. Check whether `feeds/*.xml` or `sitemap.xml` are already modified. If they
   are, find out why before regenerating them.

## Page structure

All public pages are hand-written. The shared skeleton is:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>...</title>
  <link rel="icon" href="./favicon.ico" type="image/x-icon">
  <link rel="stylesheet" href="./styles.css">
  <!-- optional RSS link, description, canonical, hreflang, Open Graph -->
</head>
<body>
  <a class="skip-link" href="#site-main">Skip to main content</a>
  <header id="site-header">...</header>
  <main id="site-main" tabindex="-1">...</main>
  <footer id="site-footer">...</footer>
</body>
</html>
```

Rules that the repository already follows:

- Use UTF-8, one `<h1>` per page, and a heading order without skipped levels.
- Root pages use `./` paths. Files in `articles/` use `./../` for shared assets
  and `./../index.html` for site navigation. Sibling article links are
  `./other-article.html`.
- Do not introduce root-absolute internal paths such as `/styles.css`. The Tor
  and I2P mirrors are served from other origins.
- Canonical URLs are absolute under `https://uhden.dev/`. The English home page
  canonical is `https://uhden.dev/`; other pages use their exact filename.
- `og:url` must equal the canonical. `og:type` is `article` for articles and
  `website` for other pages.
- Head `hreflang` alternates are absolute. The visible language switch is
  relative and uses `class="lang-switch" rel="alternate" hreflang="..."`.
- Keep the skip link, `<main id="site-main" tabindex="-1">`, localized
  navigation labels, table `<caption>` and `scope` attributes, form labels,
  `<time datetime>`, and meaningful image `alt` text.
- Keep assets local. Do not add CDN scripts, remote fonts, trackers, or
  third-party embeds.
- Keep images fluid. Rely on the existing `max-width: 100%`, `height: auto`, and
  `.home-portrait` `clamp()` rules. Do not add fixed `width`/`height` attributes
  or fixed pixel widths; the image must scale with the viewport.

Title separators and RSS link titles vary by page type in the existing site.
Follow the nearest page instead of normalizing the whole site.

## Article structure

An article uses the same outer page skeleton plus this inner structure:

```html
<main id="site-main" tabindex="-1">
  <article>
    <header id="article-header">
      <p class="kicker">Category</p>
      <h1>Article title</h1>
      <p class="meta">By David Uhden Collado - Updated
        <time datetime="2026-08-28">August 28, 2026</time></p>
      <p class="lede">One-sentence summary.</p>
    </header>
    <nav class="toc" aria-label="Table of contents">...</nav>
    <section>
      <h2 id="section-id">Section heading</h2>
      ...
    </section>
  </article>
</main>
```

The feed generator depends on these markers:

- `<html lang="...">` selects the feed language.
- The first `<h1>` inside `<header id="article-header">` becomes the feed title.
- The first `<time datetime="...">` becomes the feed date. Do not omit it; the
  generator otherwise falls back to the file modification time, which is not
  reproducible.
- `<meta name="description">` is the preferred feed summary. If it is absent,
  the generator falls back to `.lede` and then the first paragraph.
- The filename without `.html` becomes the slug.

Keep the TOC links and section `id` values in sync. Spanish pages use localized
ids; do not copy English anchors into a Spanish page.

Start code blocks with the first code character immediately after `<code>`.
Do not put a newline, tab, or indentation before it; that whitespace is
significant inside `<pre>` and renders as a blank first line. `t/integrity.t`
checks every `<pre><code>` block in root pages, articles, templates, and
`ddgnoai/`.

Optional footnotes and useful-link asides are placed after `</main>` and before
the footer, as in `articles/systems.html`, `articles/unix.html`,
`articles/ryf-fsdg.html`, and `articles/openbsd.html`. Follow the pattern only
when the article needs it.

`templates/articles.html` and `templates/articles-es.html` are reference
boilerplates. No script consumes them. They contain a TL;DR example that the
current articles do not use, so do not copy it blindly.

`ddgnoai/index.html` is an English-only utility page with its own stylesheet and
OpenSearch description. Preserve its differences; do not force it into the
bilingual page layout.

## Adding an article

1. Create the English article and its Spanish counterpart. Use the existing
   filename convention (`slug.html` / `slug-es.html`, or a translated pair such
   as `systems.html` / `sistemas.html`).
2. Add both filenames and both titles to `data/articles.json`. The
   `title_en`/`title_es` values must exactly match the visible `<h1>` text after
   tags and whitespace are normalized.
3. Add reciprocal head `hreflang` links and the visible language switch. Use the
   exact counterpart filename.
4. Add an entry to both `blog.html` and `blog-es.html`. The blog listing is
   manual, but `t/integrity.t` checks that its dates and order match the article
   `<time>` values and the generated feeds.
5. Regenerate feeds and sitemap using `feeds-and-sitemaps`.
6. Run the validation commands below.
7. Open both pages in a browser and check layout, navigation, anchors, tables,
   and language switching.

## Validation

Run from the repository root:

```sh
perl scripts/validate-website.pl --check
prove t/integrity.t
prove t/reproducible.t
prove t
```

- `--check` is static formatting and validation. It does not run tests.
- `t/integrity.t` checks article registration, `<h1>` title matches, reciprocal
  hreflang, feed targets, and sitemap coverage.
- `t/reproducible.t` checks that committed feeds and sitemap match the
  generators.
- `prove t` is the full regression suite.
- The real check is manual browser inspection. There is no build or preview
  server in the repository.

If you changed only prose inside an existing article and did not touch metadata,
you may not need to regenerate feeds or the sitemap. If you changed the title,
description, date, filename, or language, regenerate and re-run
`t/reproducible.t`.

## Frequent problems

- **New article not registered.** `t/integrity.t` fails because every
  `articles/*.html` file must appear in `data/articles.json`.
- **Title mismatch.** `title_en`/`title_es` must match the `<h1>` exactly,
  including punctuation and accents.
- **Missing reciprocity.** Both pages need a head `hreflang` link to the exact
  counterpart filename.
- **Copied anchors.** Spanish section ids are localized; copying English ids
  breaks the Spanish TOC or creates misleading deep links.
- **Forgotten blog entry.** `blog.html` and `blog-es.html` are not generated.
  `t/integrity.t` catches a missing entry through the order/date comparison, but
  you must still add the human-readable title and link manually.
- **Hand-edited generated files.** Editing `feeds/*.xml` or `sitemap.xml` makes
  `t/reproducible.t` fail.
- **Missing `<time>`.** Without it, feed dates fall back to file mtimes.
- **Meta description extraction.** The generator accepts mixed quote styles and
  attribute order, including apostrophes inside the description. Keep the
  regression coverage in `t/rebuild-feeds.t` if you change the parser.
- **Absolute internal links.** They work on the clear site but break on the Tor
  and I2P mirrors.
- **Template drift.** Do not add the template's TL;DR section or
  `toc-level-2` classes unless the task explicitly asks for them.

## References

- `AGENTS.md`
- `templates/articles.html`, `templates/articles-es.html`
- `index.html`, `blog.html`, `articles/gpl.html`
- `data/articles.json`
- `t/integrity.t`, `t/reproducible.t`
- `scripts/validate-website.pl`
- `dprint.json`, `.stylelintrc.json`, `.htmltest.yml`
