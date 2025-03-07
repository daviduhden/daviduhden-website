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

document.addEventListener('DOMContentLoaded', function () {
    // Mapping of pages for 'index' and 'blog' by language.
    // Spanish pages are 'index-es.html' and 'blog-es.html'
    // English pages are 'index.html' and 'blog.html'
    const pages = {
        index: {
            es: 'index-es.html',
            en: 'index.html'
        },
        blog: {
            es: 'blog-es.html',
            en: 'blog.html'
        }
    };

    // Get the current page name (if it's empty, assume index.html)
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';

    // Detect the browser's language: if it's Spanish ('es'), use 'es'; otherwise, use 'en'
    const userLang = navigator.language.substring(0, 2) === 'es' ? 'es' : 'en';

    // Function to determine if the current page corresponds to the index page
    function isIndexPage(pageName) {
        return pageName.toLowerCase().includes('index');
    }

    // Function to determine if the current page corresponds to the blog page
    function isBlogPage(pageName) {
        return pageName.toLowerCase().includes('blog');
    }

    // If on an index page and it's not the correct version based on the language, redirect to the correct version
    if (isIndexPage(currentPage) && currentPage !== pages.index[userLang]) {
        window.location.href = pages.index[userLang];
    }
    // If on a blog page and it's not the correct version based on the language, redirect to the correct version
    else if (isBlogPage(currentPage) && currentPage !== pages.blog[userLang]) {
        window.location.href = pages.blog[userLang];
    }
});