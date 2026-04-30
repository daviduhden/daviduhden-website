/*!
 * Language Switch Helper
 *
 * Copyright (c) 2024-2026 David David Uhden Collado <david@uhden.dev>
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
  "use strict";

  function preferredLang() {
    const langs = (navigator.languages && navigator.languages.length)
      ? navigator.languages
      : [navigator.language || "en"];
    return langs.some((l) => String(l).toLowerCase().startsWith("es"))
      ? "es"
      : "en";
  }

  function currentLang() {
    return String(document.documentElement.lang || "en")
        .toLowerCase()
        .startsWith("es")
      ? "es"
      : "en";
  }

  const pageLang = currentLang();
  const targetLang = preferredLang();

  // No-op when current page already matches user preference.
  if (pageLang === targetLang) return;

  // Keep behavior non-invasive:
  // - Never override URLs with hash/query context.
  // - Never redirect when navigating within the same site.
  const url = new URL(window.location.href);
  if (url.search || url.hash) return;
  if (document.referrer) {
    try {
      const ref = new URL(document.referrer);
      if (ref.origin === url.origin) return;
    } catch {
      // ignore invalid referrer
    }
  }

  // Use the explicit alternate language link already present on the page.
  const switchLink = document.querySelector(
    `a.lang-switch[hreflang="${targetLang}"]`,
  );
  if (!switchLink) return;

  const href = switchLink.getAttribute("href");
  if (!href) return;
  const targetUrl = new URL(href, url);
  if (targetUrl.href !== url.href) {
    window.location.replace(targetUrl.href);
  }
})();
