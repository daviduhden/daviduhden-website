/*!
 * Language Redirect Script
 *
 * Copyright (c) 2024-2025 David Uhden Collado <david@uhden.dev>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

// Main entry: run after DOM is loaded
(function () {
    // Key for localStorage to disable auto-redirect after user switches language
    const disableKey = 'langRedirectDisabled';
    // Detect if we are in an article subdirectory (affects relative paths)
    const isArticlesPath = window.location.pathname.includes('/articles/');
    // Set path prefixes for root and articles
    const rootPrefix = isArticlesPath ? '../' : './';
    const articlePrefix = isArticlesPath ? '' : 'articles/';

    // When user clicks a language switch, disable auto-redirect for future visits
    function disableAutoRedirect() {
        try {
            localStorage.setItem(disableKey, 'true');
        } catch (e) {
            // Ignore storage failures (e.g., privacy mode)
        }
    }

    // Attach click handler to all .lang-switch elements
    const langSwitchButtons = document.querySelectorAll('.lang-switch');
    langSwitchButtons.forEach(function (button) {
        button.addEventListener('click', disableAutoRedirect);
    });

    // Check if redirect is disabled
    let redirectDisabled = false;
    try {
        redirectDisabled = localStorage.getItem(disableKey) === 'true';
    } catch (e) {
        redirectDisabled = false;
    }
    if (redirectDisabled) {
        return;
    }

    // Main pages (index, blog, license) for each language
    const pages = {
        index: {
            es: rootPrefix + 'index-es.html',
            en: rootPrefix + 'index.html'
        },
        blog: {
            es: rootPrefix + 'blog-es.html',
            en: rootPrefix + 'blog.html'
        },
        license: {
            es: rootPrefix + 'licencia.html',
            en: rootPrefix + 'license.html'
        }
    };

    // Article mapping will be loaded from data/articles.json when available.
    // Structure expected:
    // {
    //   "gpl": { "en": "gpl.html", "es": "gpl-es.html", "title_en": "...", "title_es": "..." },
    //   ...
    // }

    const articlesJsonPath = rootPrefix + 'data/articles.json';

    function buildMapsFromData(data) {
        const articlePages = {};
        const articleFileToSlug = {};
        Object.keys(data).forEach(function (slug) {
            const info = data[slug] || {};
            const enFile = info.en || (slug + '.html');
            const esFile = info.es || (slug + '-es.html');
            articlePages[slug] = { es: articlePrefix + esFile, en: articlePrefix + enFile };
            articleFileToSlug[enFile] = slug;
            articleFileToSlug[esFile] = slug;
        });
        return { articlePages, articleFileToSlug };
    }

    // fallback static mapping (kept for robustness if JSON unavailable)
    const fallbackMapping = {
        gpl: { en: articlePrefix + 'gpl.html', es: articlePrefix + 'gpl-es.html' },
        openbsd: { en: articlePrefix + 'openbsd.html', es: articlePrefix + 'openbsd-es.html' },
        systems: { en: articlePrefix + 'systems.html', es: articlePrefix + 'sistemas.html' },
        unix: { en: articlePrefix + 'unix.html', es: articlePrefix + 'unix-es.html' }
    };

    const fallbackFileToSlug = {
        'gpl.html': 'gpl', 'gpl-es.html': 'gpl',
        'openbsd.html': 'openbsd', 'openbsd-es.html': 'openbsd',
        'systems.html': 'systems', 'sistemas.html': 'systems',
        'unix.html': 'unix', 'unix-es.html': 'unix'
    };

    // Get current file name (e.g., 'index.html')
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    // Detect browser language (default to 'en' if not Spanish)
    const userLang = navigator.language.substring(0, 2) === 'es' ? 'es' : 'en';

    // Returns true if the page is an index page
    function isIndexPage(pageName) {
        return pageName.toLowerCase().includes('index');
    }
    // Returns true if the page is a blog page
    function isBlogPage(pageName) {
        return pageName.toLowerCase().includes('blog');
    }
    // Returns true if the page is a license page
    function isLicensePage(pageName) {
        const lower = pageName.toLowerCase();
        return lower.includes('license') || lower.includes('licencia');
    }

    // Core redirect logic; accepts maps
    function performRedirect(articlePages, articleFileToSlug) {
        // If on an article, redirect to the correct language version if needed
        if (articleFileToSlug[currentPage]) {
            const slug = articleFileToSlug[currentPage];
            const targetPage = articlePages[slug] ? articlePages[slug][userLang] : null;
            const targetFile = targetPage ? targetPage.split('/').pop() : null;
            if (targetFile && targetFile !== currentPage) {
                window.location.href = targetPage;
                return true;
            }
        }

        // If on a main page, redirect to the correct language version if needed
        if (isIndexPage(currentPage) && currentPage !== pages.index[userLang].split('/').pop()) {
            window.location.href = pages.index[userLang];
            return true;
        } else if (isBlogPage(currentPage) && currentPage !== pages.blog[userLang].split('/').pop()) {
            window.location.href = pages.blog[userLang];
            return true;
        } else if (isLicensePage(currentPage) && currentPage !== pages.license[userLang].split('/').pop()) {
            window.location.href = pages.license[userLang];
            return true;
        }
        return false;
    }

    // Load article mapping JSON and then perform redirect; fall back to static maps
    fetch(articlesJsonPath, { cache: 'no-cache' })
        .then(function (resp) {
            if (!resp.ok) throw new Error('No JSON');
            return resp.json();
        })
        .then(function (data) {
            const maps = buildMapsFromData(data);
            performRedirect(maps.articlePages, maps.articleFileToSlug);
        })
        .catch(function () {
            // Use hardcoded fallback if JSON unavailable
            performRedirect(fallbackMapping, fallbackFileToSlug);
        });
})();