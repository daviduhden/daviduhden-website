---
name: feeds-and-sitemaps
description: Regenerate and verify RSS feeds and sitemap.xml after content or metadata changes while preserving relative links, language separation, and deterministic output.
---

# Feeds and sitemaps

## When to use this skill

Use this skill when you need to:

- add a new article or update an existing article's title, description, date, or
  filename;
- change anything under `feeds/` or `sitemap.xml`;
- investigate a feed parse error, missing item, wrong date, duplicate item, or
  sitemap omission;
- change the canonical host or mirror strategy;
- verify that generated artifacts are current.

The HTML content itself belongs to `static-site-content`; translation parity
belongs to `bilingual-page-consistency`; generator internals belong to
`perl-site-generation`.

## Data flow

```text
articles/*.html
  -> scripts/rebuild-feeds.pl
  -> feeds/blog.xml (English) and feeds/blog-es.xml (Spanish)

**/*.html
  -> scripts/rebuild-sitemap.pl
  -> sitemap.xml

t/integrity.t      checks registration, hreflang, feed targets, sitemap coverage
t/reproducible.t   compares working-tree artifacts with fresh generator output
```

`data/articles.json` is not read by either generator. It is test metadata for
`t/integrity.t`. The generators scan the filesystem.

## Article metadata the feed generator reads

For each `articles/*.html` file except `articles/index.html`:

- `<html lang="...">` selects `en` or `es`.
- The first `<h1>` inside `<header id="article-header">` becomes the title.
- `<meta name="description">` becomes the summary, falling back to `.lede` and
  then the first paragraph.
- The first `<time datetime="...">` becomes the publication date. If it is
  missing, the file modification time is used.
- The filename without `.html` becomes the slug and the feed link.

Keep those markers intact when editing an article.

## Procedure

1. Run `git status --short`. If `feeds/*.xml` or `sitemap.xml` are already
   modified, determine whether they are stale before regenerating.
2. Finish all article metadata and filename changes first.
3. Regenerate from the repository root:

   ```sh
   perl scripts/rebuild-feeds.pl
   perl scripts/rebuild-sitemap.pl
   ```

4. Inspect the diff:

   ```sh
   git diff -- feeds sitemap.xml
   ```

   Check feed item count, order, links, GUIDs, dates, descriptions,
   `lastBuildDate`, and sitemap additions/removals. Do not hand-edit the result.
5. Run the focused tests:

   ```sh
   prove t/rebuild-feeds.t
   prove t/rebuild-sitemap.t
   prove t/integrity.t
   prove t/reproducible.t
   ```

6. Run the full suite:

   ```sh
   prove t
   ```

7. Optionally run the non-mutating validator:

   ```sh
   perl scripts/validate-website.pl --check
   ```

8. Load the feed in a reader or browser and open a few sitemap URLs. That is the
   real check; the tests are regex- and byte-based and do not parse the XML with
   a full schema validator.

## Feed rules

- Output is RSS 2.0 with the Atom namespace for `atom:link rel="self"`.
- Channel title, link, and description are read from the existing feed and
  preserved. The generator does not invent channel metadata.
- Default item links and GUIDs are root-relative:

  ```xml
  <link>/articles/slug.html</link>
  <guid isPermaLink="false">/articles/slug.html</guid>
  ```

  This is intentional so one feed works on the clear, Tor, and I2P mirrors.
- Do not pass `--base-url` when regenerating committed feeds. It makes links
  absolute, breaks the root-relative pattern that `t/integrity.t` expects, and
  causes `t/reproducible.t` to fail. `--base-url` is only for a deployment that
  genuinely needs absolute URLs.
- GUIDs remain root-relative even with `--base-url`; a slug change therefore
  changes the GUID.
- Items are sorted by date descending, then slug ascending.
- `lastBuildDate` is the newest item's date, not the generation time. An empty
  feed keeps its existing `lastBuildDate`, or uses the Unix epoch if none is
  present. This keeps output deterministic.
- Dates are RFC 2822 in GMT. Numeric ISO offsets are handled.
- English and Spanish feeds stay language-separated. If no Spanish feed exists,
  all articles are treated as English.
- Feed detection prefers `feeds/blog.xml` and `feeds/blog-es.xml`; if those are
  absent it looks for `feeds/articles.xml` and `feeds/articles-es.xml`. If no
  supported feed exists, it fails.
- XML escaping is single-pass. Do not introduce double-encoded entities.
- Atomic writes preserve the file mode and leave no `.tmp-*` files.

## Sitemap rules

- The host is hardcoded as `https://uhden.dev` in
  `scripts/rebuild-sitemap.pl`. Changing it requires a code change, a review of
  every canonical URL, and a new generated sitemap.
- All `.html` files are included recursively except paths under `archive/` and
  `templates/`.
- `index.html` becomes `/`; `sub/index.html` becomes `/sub/`.
- Entries are sorted lexicographically and are deterministic.
- There is no `lastmod`, `changefreq`, or `priority`. Do not fabricate them.
- The XML declaration is exactly `<?xml version="1.0" encoding="UTF-8"?>`.
- `sitemap.xml` is hand-edited only by regenerating it. Manual edits fail
  `t/reproducible.t`.

## Validation summary

| Check | What it proves | Limit |
| --- | --- | --- |
| `t/rebuild-feeds.t` | Escaping, order, time zones, language separation, atomic writes, base URL behavior | Fixture content, not the real feeds |
| `t/rebuild-sitemap.t` | URL mapping, exclusions, sorting, mode preservation | Fixture content |
| `t/integrity.t` | Feed links target real articles, each blog feed is language-pure, every article is in the sitemap | Regex-based; only checks `blog.xml` and `blog-es.xml` |
| `t/reproducible.t` | Working-tree feeds and sitemap equal fresh generator output | Uses the working tree, not `git HEAD` |
| `--check` | XML is well-formed and formatted | Does not check feed semantics or external links |
| Manual reader/browser | Real consumption | Not automated |

## Frequent problems

- **Stale artifacts.** Editing an article title or date without regenerating
  leaves `feeds/*.xml` and possibly `sitemap.xml` stale. `t/reproducible.t` will
  fail.
- **`--base-url` in committed output.** Tests fail because item links are no
  longer root-relative.
- **Meta description parsing regressions.** The parser accepts the same quote
  character around an attribute value and does not stop at an apostrophe inside
  a double-quoted value. Keep the mixed-quote, reversed-attribute, and
  apostrophe cases in `t/rebuild-feeds.t`. If a description is truncated,
  regenerate and inspect the item text before changing article content.
- **Missing `<time>`.** The date falls back to mtime, which makes output depend
  on checkout time and breaks reproducibility.
- **Wrong language.** A Spanish article with `lang="en"` is placed in the English
  feed.
- **Hand-edited feeds.** The next rebuild overwrites the edit and
  `t/reproducible.t` fails.
- **Forgotten blog listing.** `blog.html` and `blog-es.html` are manually
  maintained and are not updated by the feed generator. Add the title and link,
  and use the same date and position as the feed item; `t/integrity.t` enforces
  both.
- **Out-of-order blog listing.** Feed order is date descending, then slug
  ascending. The blog listing must use the same order and the same article
  `<time>` date; `t/integrity.t` compares both.
- **Sitemap domain drift.** Canonicals, `robots.txt`, and the generator host must
  agree on `https://uhden.dev`.
- **Templates in the sitemap.** They are excluded by design; do not add them.
- **Articles in `archive/`.** Archived copies are excluded by design.
- **Duplicate or unstable GUIDs.** Do not change a slug casually; it changes the
  item link and GUID.

## References
- `docs/ARCHITECTURE.md` — source, generated-output, dependency, and workflow map.

- `AGENTS.md`
- `scripts/rebuild-feeds.pl`, `scripts/rebuild-sitemap.pl`
- `scripts/update-feeds.pl`
- `feeds/blog.xml`, `feeds/blog-es.xml`
- `sitemap.xml`, `robots.txt`
- `t/integrity.t`, `t/reproducible.t`
- `t/rebuild-feeds.t`, `t/rebuild-sitemap.t`
- `data/articles.json`

## Maintenance & Continuous Learning

Whenever this skill is used to change the repository, review this skill after
the implementation. Correct procedures that proved wrong, update commands,
paths, configuration and examples, incorporate reusable findings, and remove
outdated assumptions. Review the applicable root and nested `AGENTS.md` files,
specialized agents and related skills; update only the knowledge affected by
the work. Validate local references and run
`python3 scripts/validate-agent-knowledge.py --scope worktree` plus the
applicable project checks. For pull request comparisons, use the documented
`--scope range --base BASE_REF --head HEAD_REF` command. The canonical validator
is read-only and is required even when a task restricts execution of project
scripts; this does not authorize running installers or changing the host.
Report checks actually performed. A structural pass does not prove semantic
relevance, and a task is incomplete until synchronization is validated.
