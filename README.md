# David Uhden Collado Website

This repository contains the hand-authored static website of David Uhden Collado, including English and Spanish pages, articles, service information, and a DuckDuckGo OpenSearch shortcut that avoids AI summaries. The site is served as files and has no package manifest, framework, or local compilation step.

## Repository layout

- `index.html` and `index-es.html` are the English and Spanish home pages; `blog*.html`, `services.html`, and `servicios.html` are other top-level pages.
- `articles/` contains paired language versions where available. Keep translations linked and dated consistently.
- `styles.css` is the shared site stylesheet. `ddgnoai/` is a separate OpenSearch landing page with its own `styles.css` and `opensearch.xml`.
- `images/`, `files/`, `feeds/`, `data/`, and `templates/` hold public assets, a downloadable disk image, generated feeds, article metadata, and reference templates.
- `scripts/` contains Perl and shell tools for updating feeds, rebuilding the sitemap, converting assets, and validating the site.
- `redirect.js` is a standalone optional browser script; published pages do not load it automatically.
- `.github/`, root Markdown documentation, agent instructions, `docs/`, test files, and development configuration are repository-only and are omitted from site archives and server synchronization.

## Technologies and requirements

The public site uses semantic HTML, CSS, local images, and the browser's OpenSearch support. Maintenance tools are Perl and shell scripts; the main site validation and test suite use the tools listed in `AGENTS.md`. No dependency installation is needed to browse the files locally: open `index.html` or serve the repository root with a static web server.

## Updating pages and articles

Edit the appropriate hand-authored HTML page. For articles, maintain the English and Spanish pages as separate files, preserve their cross-language links, and update the corresponding entries in `data/articles.json` when metadata changes. Rebuild feeds and the sitemap only with the existing scripts when their generated public files need updating. Keep references relative so the site works from its configured mirrors and subdirectories.

## Styles and browser behavior

Main pages load the root `styles.css`; the OpenSearch shortcut loads `ddgnoai/styles.css`. Preserve the light palette, responsive rules, skip link, keyboard focus indicators, forced-colors support, and reduced-motion behavior. The OpenSearch XML is linked from the landing page and is not interchangeable with a page stylesheet.

## Validation

Run the existing tests with `prove -lr t` from the repository root. Consult `AGENTS.md` for available HTML, CSS, JavaScript, Perl, and shell syntax checks. Review both English and Spanish pages and inspect desktop and narrow layouts. Do not run asset conversion scripts unless the corresponding generated asset is intentionally being updated.

## Archive and deployment

The scheduled or manually dispatched GitHub Actions workflow creates and signs a source archive; it does not build or deploy the site. It excludes repository documentation, VCS metadata, agent instructions, development tooling, tests, caches, generated archive output, and the large `files/*.img` download. The separate [`scripts` repository](https://github.com/daviduhden/scripts/blob/main/debian/sync-website.bash) contains the Debian synchronization script used for server updates. It deploys website files from GitHub while preserving public site assets such as the disk image; its repository settings and operational steps are documented there. Do not copy a Git checkout or `.git` metadata into a public document root.

## License

See `license.html` and `licencia.html` for the site's published license information. Individual scripts, stylesheets, and other assets may have separate notices; check each file before reuse.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. Use GitHub issues and pull requests for public project discussion. Report sensitive conduct concerns privately through the contact details published on the site.
