# Contributing

Contributions should improve the accuracy, usability, accessibility, or maintainability of this static website while preserving its existing visual identity and mirror-friendly URL structure.

## Issues and pull requests

- Search existing issues before opening a new one. Include the affected page, browser or screen size when relevant, and clear reproduction steps for defects.
- Discuss substantial changes in an issue before implementation. Small corrections may be proposed directly in a pull request.
- Keep pull requests focused and explain the reason for the change, affected language versions, and checks performed.
- Do not include secrets, private data, generated archive artifacts, large unrelated formatting changes, or files copied from local editor and build environments.

## HTML, language, and content

- Follow the existing semantic HTML, metadata, heading hierarchy, and relative-link conventions. Avoid root-absolute internal links because the site is mirrored under different paths.
- Keep English and Spanish page pairs synchronized where both exist. Preserve each page's language declaration, translation links, canonical metadata, and descriptive link text.
- For articles, update the relevant entry in `data/articles.json` when the article title, URL, or publication metadata changes. Update generated feeds and `sitemap.xml` only through the existing scripts.
- Use meaningful alternative text for informative images, empty alternative text for decorative images, table headers for tabular data, and native keyboard-operable controls.

## CSS and JavaScript

- Main pages use `styles.css`; the DuckDuckGo OpenSearch landing page has its own `ddgnoai/styles.css`. Reuse the existing design tokens and responsive patterns in the main sheet.
- Preserve visible keyboard focus, skip-link behavior, forced-colors support, reduced-motion preferences, readable contrast, and layouts at narrow widths.
- Keep selectors appropriately scoped and avoid unnecessary specificity or overrides that affect unrelated pages.
- `redirect.js` is an optional standalone script and is not automatically loaded by pages. Do not add script loading or third-party resources without a clear, reviewed requirement.

## Checks before submitting

Run relevant existing checks listed in `AGENTS.md`; the Perl test suite is `prove -lr t`. Use the checked-in lint configuration. Review the final diff, validate affected links and metadata, and inspect both language versions at desktop and mobile widths where feasible. State which checks were not available or could not be run.

## Repository-only files

`README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, agent instructions, `docs/`, tests, and development settings are for repository contributors and are not public page content. Do not link them from site navigation or add them to article metadata. The archive and server synchronization filters omit known internal paths while leaving them tracked in Git. Do not broadly exclude Markdown or hidden files; some files that look internal may be required by the website.
