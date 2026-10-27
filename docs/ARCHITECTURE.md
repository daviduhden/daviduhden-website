# Website architecture and maintenance map

## Site model

This repository is the source for a hand-authored static site. Published HTML
is checked in and served directly; there is no template engine, package
manifest, asset compilation step, or deployment definition here. English and
Spanish pages are separate files, with language alternates linked in each
page's metadata and visible language switch. Relative internal links are
intentional because the same content is served from HTTPS, Tor, and I2P mirrors.

`templates/` holds manual examples and is not consumed by a generator.
`data/articles.json` is a manually maintained article-pair/title registry used
by `t/integrity.t`; the feed and sitemap scripts discover HTML independently.
`feeds/*.xml` and `sitemap.xml` are generated committed artifacts. The scripts
under `scripts/` maintain those files and provide optional media conversion and
validation helpers. No published page loads JavaScript. The standalone
`redirect.js` language preference helper is linked from license pages, while
JSON-LD in the home pages is data, not executable JavaScript.

## Dependency map

```text
hand-authored page HTML ──loads──> styles.css
       │                         └─ article pages use relative stylesheet paths
       ├── article header metadata ──> scripts/rebuild-feeds.pl ──> feeds/*.xml
       ├── public HTML paths ─────────> scripts/rebuild-sitemap.pl ──> sitemap.xml
       ├── paired titles/files ───────> data/articles.json ──checked by t/integrity.t
       └── license pages link to standalone redirect.js for download

ddgnoai/index.html ──loads──> ddgnoai/styles.css
       └── OpenSearch description ──> ddgnoai/opensearch.xml

scripts/validate-agent-knowledge.py ──read-only policy and instruction gate
scripts/*.pl and scripts/*.sh ──manual maintenance; archive.yml runs in GitHub Actions
```

The feed generator reads page language, the first article `<h1>`, description
metadata/lede text, and `<time datetime>`. It converts the selected time to an
RFC 2822 date and sorts by date descending with slug ascending as a stable tie
breaker. Missing or invalid dates fall back to file modification time, which
can make output depend on checkout timestamps; authored pages should keep a
valid `<time datetime>`. Feed links and GUIDs remain root-relative by default so
one artifact serves all mirrors. The sitemap generator scans public HTML,
excludes `archive/` and `templates/`, maps `index.html` to a directory URL, and
emits no guessed modification dates. Both generators write through a temporary
file in the destination directory and rename it into place.

## Styles and browser behavior

`styles.css` is hand-maintained and shared by the site's pages. Its custom
properties in `:root` define the light palette, spacing, widths, radii, shadows,
and focus treatment. Layout and component rules consume those tokens. The
article table of contents uses CSS counters and semantic list markup; its
`toc-level-3` and `toc-level-4` classes must stay aligned with the heading depth
and list markup authored in article pages. `@media (max-width: 60em)` changes
the TOC to one column and relaxes table whitespace. Image sizing is fluid, and
the home portrait uses `clamp()` rather than a fixed size. Reduced-motion,
print, and forced-colors rules are part of the existing accessibility behavior.

`ddgnoai/styles.css` is a separate stylesheet for the local search landing page;
it does not inherit `styles.css`. `ddgnoai/opensearch.xml` supplies browser
search-engine metadata for that page. Search submissions and suggestions use
DuckDuckGo's remote `noai.duckduckgo.com` endpoints, so search terms are sent to
that service when the feature is used. Do not assume rules from the main sheet
apply to this sub-site.

`redirect.js` is a standalone browser helper linked from the license pages; no
published page loads it automatically. If run, it reads `navigator.languages`
(or `navigator.language`) and chooses Spanish when any preferred language starts
with `es`, otherwise English. It redirects only through the existing
`.lang-switch` alternate link, and avoids redirecting when the URL has a query
or fragment, when the referrer is same-origin, or when the document already
matches the preferred language. It stores no preference and makes no network
request of its own. The selector and `hreflang` values therefore form a
contract with page markup; adding storage or changing redirect conditions would
change privacy or navigation behavior.

The pages use local styles and assets and do not include third-party scripts,
fonts, analytics, or remote embeds. No Content Security Policy or HTTP response
header configuration is present in this repository; hosting-layer headers
cannot be inferred from these sources.

## Configuration and automation

| File | Consumer and effect |
| --- | --- |
| `dprint.json` | Pins the dprint formatter's TypeScript, CSS, and JSON plugins and sets 80-column/LF formatting. JSON does not allow comments; keep the explanation here. |
| `.stylelintrc.json` | Enables CSS syntax and duplicate-selector/property checks. The duplicate-property exception preserves adjacent fallback declarations with different syntaxes. JSON does not allow comments. |
| `.htmltest.yml` | Configures offline HTML checks for structure, internal links, anchors, images, and metadata. External, mail, and telephone targets are excluded; custom protocols are ignored. |
| `.perlcriticrc` | Sets Perl::Critic severity 3 and documents each disabled policy beside the exception. |
| `.gitattributes` | Sends archive tarballs and disk images through Git LFS and prevents text conversion for those binary objects. |
| `.gitignore` | Excludes temporary reports and scratch files under `tmp/`. |
| `robots.txt` | Permits crawler access and advertises the HTTPS sitemap; it is a crawl directive, not an access-control mechanism. |
| `data/articles.json` | Associates article keys with paired filenames and localized titles; it is validated against pages but is not a generator input. |
| `scripts/openbsd-tools.txt` | Informational mapping from validator/conversion tools to OpenBSD ports; scripts do not parse it. |
| `ddgnoai/opensearch.xml` | Declares the search and suggestions endpoints used by browser search integration. |
| `.github/workflows/agent-knowledge-validation.yml` | Read-only pull request tests and agent-knowledge range gate; see `docs/agent-knowledge-validation.md`. |
| `.github/workflows/archive.yml` | Runs daily or by manual dispatch. It creates and signs a source archive, removes older tarball history, and force-pushes the archival update. It is not a site test, build, or publishing workflow. Its triggers and write permissions are operationally significant. |

The workflow installs tools and accesses `SIGNIFY_KEY` only in its GitHub
Actions environment. It attempts source retrieval through clearnet, then Tor,
then a distribution package. The repository exposes no web-server, hosting,
deployment, CSP, or response-header configuration. The agent-knowledge
workflow is the only PR validation workflow; the archive workflow is not part
of local validation.

The archive excludes GitHub and maintainer documentation, repository metadata,
agent instructions, development tooling, tests, caches, and archive output. It
also retains the established exclusion for the large `files/*.img` download.
These paths remain tracked in GitHub. The Debian sync uses a full source tree
and preserves public assets, including the downloadable image, while applying
the internal-file exclusions to both staged source and the existing document
root.

## Maintenance boundaries

- Edit article pages as the content source. Keep language pairs, canonical and
  alternate metadata, visible language links, and relative asset paths aligned.
- Update `data/articles.json` when article filenames or `<h1>` titles change;
  tests validate both directions of this mapping.
- Regenerate feeds and sitemap with their Perl scripts only when source pages
  change. Never hand-edit generated XML.
- Treat `redirect.js` class names and `hreflang` attributes as a shared
  HTML/JavaScript contract.
- Preserve skip links, focus styles, `main#site-main`, semantic tables, image
  alternatives, fluid image rules, and reduced-motion/forced-colors styles.
- `validate-website.pl` defaults to in-place apply mode. Use `--check` or
  `--check-all` for read-only checks; the generator scripts write tracked files.
- `t/00-syntax.t` parses maintenance scripts; `t/integrity.t` checks live
  content relationships; generator tests use temporary fixtures; and
  `t/reproducible.t` verifies generated outputs in a temporary repository copy.
- The archive workflow changes Git history and force-pushes `main`; the files
  under `archive/` are generated signed artifacts and must not be edited by hand.
