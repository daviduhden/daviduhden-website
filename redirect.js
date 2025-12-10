// @licstart The following is the license notice for the JavaScript code in this file.
// @license SPDX: ISC
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
// @licend The above is the entire license notice for the JavaScript code in this file.

document.addEventListener('DOMContentLoaded', function () {
    const disableKey = 'langRedirectDisabled';
    const isArticlesPath = window.location.pathname.includes('/articles/');
    const rootPrefix = isArticlesPath ? '../' : './';
    const articlePrefix = isArticlesPath ? '' : 'articles/';

    function disableAutoRedirect() {
        try {
            localStorage.setItem(disableKey, 'true');
        } catch (e) {
            // Ignore storage failures (e.g., privacy mode)
        }
    }

    const langSwitchButtons = document.querySelectorAll('.lang-switch');
    langSwitchButtons.forEach(function (button) {
        button.addEventListener('click', disableAutoRedirect);
    });

    let redirectDisabled = false;
    try {
        redirectDisabled = localStorage.getItem(disableKey) === 'true';
    } catch (e) {
        redirectDisabled = false;
    }

    if (redirectDisabled) {
        return;
    }

    const pages = {
        index: {
            es: rootPrefix + 'index-es.html',
            en: rootPrefix + 'index.html'
        },
        blog: {
            es: rootPrefix + 'blog-es.html',
            en: rootPrefix + 'blog.html'
        }
    };

    const articlePages = {
        gpl: {
            es: articlePrefix + 'gpl-es.html',
            en: articlePrefix + 'gpl.html'
        },
        openbsd: {
            es: articlePrefix + 'openbsd-es.html',
            en: articlePrefix + 'openbsd.html'
        },
        systems: {
            es: articlePrefix + 'sistemas.html',
            en: articlePrefix + 'systems.html'
        },
        unix: {
            es: articlePrefix + 'unix-es.html',
            en: articlePrefix + 'unix.html'
        }
    };

    const articleFileToSlug = {
        'gpl.html': 'gpl',
        'gpl-es.html': 'gpl',
        'openbsd.html': 'openbsd',
        'openbsd-es.html': 'openbsd',
        'systems.html': 'systems',
        'sistemas.html': 'systems',
        'unix.html': 'unix',
        'unix-es.html': 'unix'
    };

    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const userLang = navigator.language.substring(0, 2) === 'es' ? 'es' : 'en';

    function isIndexPage(pageName) {
        return pageName.toLowerCase().includes('index');
    }

    function isBlogPage(pageName) {
        return pageName.toLowerCase().includes('blog');
    }

    if (articleFileToSlug[currentPage]) {
        const slug = articleFileToSlug[currentPage];
        const targetPage = articlePages[slug] ? articlePages[slug][userLang] : null;
        const targetFile = targetPage ? targetPage.split('/').pop() : null;
        if (targetFile && targetFile !== currentPage) {
            window.location.href = targetPage;
            return;
        }
    }

    if (isIndexPage(currentPage) && currentPage !== pages.index[userLang].split('/').pop()) {
        window.location.href = pages.index[userLang];
    } else if (isBlogPage(currentPage) && currentPage !== pages.blog[userLang].split('/').pop()) {
        window.location.href = pages.blog[userLang];
    }
});