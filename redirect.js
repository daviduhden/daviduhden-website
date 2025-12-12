/*!
 * Language Redirect Script (improved)
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

(() => {
  'use strict';

  // =========================
  // Config
  // =========================
  const DISABLE_KEY = 'langRedirectDisabledUntil'; // timestamp (ms)
  const DISABLE_DAYS = 30; // how long to respect manual language choice
  const JSON_CACHE_KEY = 'articlesMapCache:v1';
  const JSON_CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6 hours

  // Main pages (filenames only; URLs are built later)
  const MAIN_PAGES = {
    index: { es: 'index-es.html', en: 'index.html' },
    blog: { es: 'blog-es.html', en: 'blog.html' },
    license: { es: 'licencia.html', en: 'license.html' }
  };

  // Fallback static mapping (filenames only; URLs are built later)
  const FALLBACK_ARTICLES = {
    gpl: { en: 'gpl.html', es: 'gpl-es.html' },
    openbsd: { en: 'openbsd.html', es: 'openbsd-es.html' },
    systems: { en: 'systems.html', es: 'sistemas.html' },
    unix: { en: 'unix.html', es: 'unix-es.html' }
  };

  // =========================
  // Safe storage helpers
  // =========================
  const now = () => Date.now();

  function safeLocalStorageGet(key) {
    try { return localStorage.getItem(key); } catch { return null; }
  }
  function safeLocalStorageSet(key, value) {
    try { localStorage.setItem(key, value); } catch { /* ignore */ }
  }

  // Disable auto redirect for a while after the user explicitly switches language
  function disableAutoRedirect() {
    const until = now() + DISABLE_DAYS * 24 * 60 * 60 * 1000;
    safeLocalStorageSet(DISABLE_KEY, String(until));
  }

  function isRedirectDisabled() {
    const untilStr = safeLocalStorageGet(DISABLE_KEY);
    const until = untilStr ? Number(untilStr) : 0;
    return Number.isFinite(until) && until > now();
  }

  // =========================
  // Language + URL helpers
  // =========================
  function preferredLang() {
    // If any preferred language starts with "es", pick Spanish, otherwise English.
    const langs = (navigator.languages && navigator.languages.length)
      ? navigator.languages
      : [navigator.language || 'en'];
    return langs.some(l => String(l).toLowerCase().startsWith('es')) ? 'es' : 'en';
  }

  function currentFileName(url) {
    // /path/ -> index.html ; /path/file.html -> file.html
    const p = url.pathname;
    if (p.endsWith('/')) return 'index.html';
    const last = p.split('/').pop() || 'index.html';
    try { return decodeURIComponent(last); } catch { return last; }
  }

  function buildBaseUrls(url) {
    const parts = url.pathname.split('/').filter(Boolean);

    // Current supported structure:
    //   /articles/*
    //
    // Future structure idea (year/month folders):
    //   /articles/2025/*
    //   /articles/2025/12/*
    //
    // If you move to year-based routes, the current `new URL('../', url)` is not enough,
    // because you may need to go up multiple levels to reach the site root.
    //
    // --- Future-proof rootBase calculation (drop-in replacement) ---
    // const articlesIndex = parts.indexOf('articles');
    // const isInArticles = articlesIndex !== -1;
    // let rootBase;
    //
    // if (isInArticles) {
    //   // How deep are we under /articles/ ?
    //   // Example: /articles/foo.html         -> depthAfterArticles = 1 -> up = "../"
    //   // Example: /articles/2025/foo.html    -> depthAfterArticles = 2 -> up = "../../"
    //   // Example: /articles/2025/12/foo.html -> depthAfterArticles = 3 -> up = "../../../"
    //   const depthAfterArticles = parts.length - (articlesIndex + 1);
    //
    //   // If the URL ends with "/", we're inside a directory (e.g. /articles/2025/),
    //   // so we need one extra "../" to reach root compared to a file URL.
    //   const needsExtraUp = url.pathname.endsWith('/') ? 1 : 0;
    //   const up = '../'.repeat(depthAfterArticles + needsExtraUp);
    //
    //   rootBase = new URL(up || './', url);
    // } else {
    //   rootBase = new URL('./', url);
    // }
    // --- End future-proof rootBase calculation ---

    // Current behavior (OK for /articles/* only):
    const isInArticles = parts.includes('articles');
    const rootBase = isInArticles ? new URL('../', url) : new URL('./', url);

    // Build base URLs
    const articlesBase = isInArticles ? new URL('./', url) : new URL('articles/', rootBase);
    const jsonUrl = new URL('data/articles.json', rootBase);

    return { isInArticles, rootBase, articlesBase, jsonUrl };
  }

  function redirectTo(targetUrl, currentUrl) {
    // Preserve query + hash (utm params, anchors, etc.)
    targetUrl.search = currentUrl.search;
    targetUrl.hash = currentUrl.hash;

    if (targetUrl.href !== currentUrl.href) {
      // replace() avoids cluttering history and helps prevent back/forward loops
      window.location.replace(targetUrl.href);
      return true;
    }
    return false;
  }

  // =========================
  // Mapping helpers
  // =========================
  function makeMainFileToKeyMap() {
    const map = Object.create(null);
    for (const key of Object.keys(MAIN_PAGES)) {
      for (const lang of Object.keys(MAIN_PAGES[key])) {
        map[MAIN_PAGES[key][lang]] = key;
      }
    }
    return map;
  }

  function buildArticleMaps(dataObj) {
    // dataObj: { slug: { en: "x.html", es: "x-es.html", ... }, ... }
    const pagesBySlug = Object.create(null);
    const fileToSlug = Object.create(null);

    for (const slug of Object.keys(dataObj || {})) {
      const info = dataObj[slug] || {};
      const enFile = info.en || `${slug}.html`;
      const esFile = info.es || `${slug}-es.html`;

      pagesBySlug[slug] = { en: enFile, es: esFile };
      fileToSlug[enFile] = slug;
      fileToSlug[esFile] = slug;
    }
    return { pagesBySlug, fileToSlug };
  }

  function buildFallbackArticleMaps() {
    const pagesBySlug = Object.create(null);
    const fileToSlug = Object.create(null);

    for (const slug of Object.keys(FALLBACK_ARTICLES)) {
      const { en, es } = FALLBACK_ARTICLES[slug];
      pagesBySlug[slug] = { en, es };
      fileToSlug[en] = slug;
      fileToSlug[es] = slug;
    }
    return { pagesBySlug, fileToSlug };
  }

  // =========================
  // Cache for articles.json
  // =========================
  function readJsonCache() {
    try {
      const raw = sessionStorage.getItem(JSON_CACHE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') return null;
      if (!parsed.savedAt || (now() - parsed.savedAt) > JSON_CACHE_TTL_MS) return null;
      return parsed.data || null;
    } catch {
      return null;
    }
  }

  function writeJsonCache(data) {
    try {
      sessionStorage.setItem(JSON_CACHE_KEY, JSON.stringify({ savedAt: now(), data }));
    } catch {
      /* ignore */
    }
  }

  async function loadArticleData(jsonUrlHref) {
    const cached = readJsonCache();
    if (cached) return cached;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2500);

    try {
      const resp = await fetch(jsonUrlHref, { cache: 'no-cache', signal: controller.signal });
      if (!resp.ok) throw new Error('articles.json not available');
      const data = await resp.json();
      writeJsonCache(data);
      return data;
    } finally {
      clearTimeout(timeout);
    }
  }

  // =========================
  // Boot
  // =========================
  const url = new URL(window.location.href);
  const { rootBase, articlesBase, jsonUrl } = buildBaseUrls(url);
  const file = currentFileName(url);
  const lang = preferredLang();

  // Always install the language-switch handler (delegation), even if we return early.
  // This works even if buttons are added later or inside templates.
  document.addEventListener('DOMContentLoaded', () => {
    document.addEventListener('click', (e) => {
      const el = e.target && e.target.closest ? e.target.closest('.lang-switch') : null;
      if (el) disableAutoRedirect();
    }, { passive: true });
  });

  // Respect the user's manual choice for a while
  if (isRedirectDisabled()) return;

  // 1) Main pages: redirect immediately without fetch
  const mainFileToKey = makeMainFileToKeyMap();
  const mainKey = mainFileToKey[file];

  if (mainKey) {
    const targetFile = MAIN_PAGES[mainKey][lang];
    if (targetFile && targetFile !== file) {
      const targetUrl = new URL(targetFile, rootBase);
      redirectTo(targetUrl, url);
      return;
    }
  }

  // 2) Articles: fallback first, then JSON
  const fallbackMaps = buildFallbackArticleMaps();

  // If the current file matches fallback, redirect immediately (no fetch)
  if (fallbackMaps.fileToSlug[file]) {
    const slug = fallbackMaps.fileToSlug[file];
    const targetFile = fallbackMaps.pagesBySlug[slug]?.[lang];
    if (targetFile && targetFile !== file) {
      const targetUrl = new URL(targetFile, articlesBase);
      redirectTo(targetUrl, url);
      return;
    }
  }

  // Otherwise, try JSON (cached). If it fails, do nothing.
  (async () => {
    try {
      const data = await loadArticleData(jsonUrl.href);
      const maps = buildArticleMaps(data);

      const slug = maps.fileToSlug[file];
      if (!slug) return;

      const targetFile = maps.pagesBySlug[slug]?.[lang];
      if (!targetFile || targetFile === file) return;

      const targetUrl = new URL(targetFile, articlesBase);
      redirectTo(targetUrl, url);
    } catch {
      // JSON failed; fallback already tried above
    }
  })();
})();