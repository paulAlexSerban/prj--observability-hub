# How to add Cloudflare Web Analytics

**Phase:** 0b (no VPS, $0 hosting)  
**Decision:** [`ADR-003`](../02%20architecture-knowledge-management/adr--003--cloudflare-web-analytics.md)  
**Code lives in:** `prj--personal-portfolio--v3` (layouts), not this repo  
**Dashboard lives in:** Cloudflare → Analytics & Logs → Web Analytics  

Sites are on **CloudFront, not Cloudflare proxy**. Automatic snippet injection will not run. Use the **manual JS snippet** path.

Official docs: [Enable Web Analytics](https://developers.cloudflare.com/web-analytics/get-started/) (section *Sites not proxied through Cloudflare*), [SPA](https://developers.cloudflare.com/web-analytics/get-started/web-analytics-spa/).

---

## 1. Create four Web Analytics sites

In the Cloudflare dashboard: **Analytics & Logs → Web Analytics → Add a site**.

Add **one site per production hostname** (do not share a token across surfaces):

| Hostname                  | App                             | SPA?                  |
| ------------------------- | ------------------------------- | --------------------- |
| `paulserban.eu`           | `frontend/sites/portfolio-site` | no                    |
| `blog.paulserban.eu`      | `frontend/sites/blog-site`      | no                    |
| `news-feed.paulserban.eu` | `frontend/sites/news-feed-site` | no                    |
| `quiz.paulserban.eu`      | `frontend/apps/quiz-web-app`    | **yes** (`spa: true`) |

For each: hostname → Done → **Manage site** → copy the JS snippet / token.

Do **not** add `local.*`, `test.*`, or `stage.*`. Those environments must ship with the token unset.

Free-plan site limits are well above four. If Cloudflare asks about automatic vs JS-snippet setup, pick **JS snippet installation**.

---

## 2. Store tokens (production only)

Snippets are already in the four apps. Tokens end up in public HTML — still do not commit them.

GitHub → `prj--personal-portfolio--v3` → Settings → Environments → **`production`** → Environment **variables** (not secrets):

| Variable                    | App                                       |
| --------------------------- | ----------------------------------------- |
| `CF_BEACON_TOKEN_PORTFOLIO` | portfolio-site → `PUBLIC_CF_BEACON_TOKEN` |
| `CF_BEACON_TOKEN_BLOG`      | blog-site → `PUBLIC_CF_BEACON_TOKEN`      |
| `CF_BEACON_TOKEN_NEWS`      | news-feed-site → `PUBLIC_CF_BEACON_TOKEN` |
| `CF_BEACON_TOKEN_QUIZ`      | quiz-web-app → `VITE_CF_BEACON_TOKEN`     |

Leave all four **unset** on `dev`, `test`, `stage`. Unset = no script tag = no pollution.

CI wiring is in `_build-site.yaml` + `release.yaml` (`read-prod-cf-beacon-tokens` → prod build inputs). Tokens inject only when `environment == production`.

---

## 3. Astro sites — already in `BaseTemplate.astro`

There is **no** shared layout package. Repeat the same block in all three templates (single include *per app*, not per page):

- `frontend/sites/portfolio-site/src/core/system/templates/BaseTemplate.astro`
- `frontend/sites/blog-site/src/core/system/templates/BaseTemplate.astro`
- `frontend/sites/news-feed-site/src/core/system/templates/BaseTemplate.astro`

Place **immediately before** `</body>`:

```astro
---
const cfBeaconToken = import.meta.env.PUBLIC_CF_BEACON_TOKEN;
---
<!-- existing footer / ImageZoomRoot -->

{cfBeaconToken && (
    <script
        is:inline
        defer
        src="https://static.cloudflareinsights.com/beacon.min.js"
        data-cf-beacon={JSON.stringify({ token: cfBeaconToken })}
    />
)}
</body>
```

Rules:

- `is:inline` — do not let Vite bundle the beacon
- `defer` — do not compete with first paint more than necessary
- omit `spa` (defaults on; Astro MPA navigations are full loads). If a site later becomes a client router, set `"spa": true` explicitly
- empty token → render nothing. Do not ship a script with `token: ""`

---

## 4. Quiz PWA — already in `main.tsx` (`spa: true`)

TanStack Router uses the History API (not hash routes). Cloudflare SPA mode hooks `pushState` / `popstate`.

Do **not** only drop a static tag in `index.html` unless you also set `"spa": true`. Prefer `frontend/apps/quiz-web-app/src/main.tsx` (runs once at boot):

```ts
const token = import.meta.env.VITE_CF_BEACON_TOKEN as string | undefined;
if (token) {
  const script = document.createElement("script");
  script.defer = true;
  script.src = "https://static.cloudflareinsights.com/beacon.min.js";
  script.setAttribute("data-cf-beacon", JSON.stringify({ token, spa: true }));
  document.body.appendChild(script);
}
```

Hash routing is **not** supported by the beacon. Do not switch the quiz to hash URLs without revisiting this.

---

## 5. Local Traefik / Docker Compose

Do **not** add `PUBLIC_CF_BEACON_TOKEN` / `VITE_CF_BEACON_TOKEN` to `infrastructure/local/docker-compose.local.yml`. Local HTTPS mesh traffic must not land in the production Cloudflare site.

---

## 6. CSP / headers (today: nothing to change)

CloudFront `static-site` response headers are HSTS + `X-Content-Type-Options` + `Referrer-Policy: strict-origin-when-cross-origin`. **No CSP.** The beacon will load.

If a CSP is added later, the beacon dies silently unless:

```
script-src  https://static.cloudflareinsights.com
connect-src https://cloudflareinsights.com
```

`Cache-Control: public, no-transform` only matters for Cloudflare **proxy** auto-inject. Irrelevant here (manual snippet, CloudFront origin).

---

## 7. Verify

1. Production deploy after the snippet ships.
2. Open a prod page, DevTools → Network: `beacon.min.js` from `static.cloudflareinsights.com`, then a POST/GET to `cloudflareinsights.com`.
3. Cloudflare dashboard → that hostname → data within a few minutes.
4. Confirm **no** beacon on `local.*`, `test.*`, `stage.*`, or GitHub Pages.
5. Quiz: client-side route change (e.g. `/` → a set) should show as a page view, not only the first load.

Exit gate for Phase 0b: **one real page view visible per production hostname**, and zero views from non-prod hosts.

---

## 8. What you can observe (and what you cannot)

**Can:** visits, page views, referrers, browsers/OS, countries, visit duration; page load (FP/FCP); Core Web Vitals (LCP, INP, CLS) with element debug — Chromium-first.

**Cannot:** bots that never run JS; CloudFront 5xx that never returned HTML; cache hit ratio; unique IPs; anything in Grafana (no API). Numbers will **not** match access logs. If they do, something is wrong.

**Will not replace Phase 0.** Turn off CloudFront logging after this and you have lost CDN truth.

---

## 9. Later phases

- **Phase 2 Umami:** still the path to own event data. Expect disagreement with Cloudflare. Decide keep/drop CF after Umami has a week of overlap.
- **Phase 3 web-vitals:** skip or shrink until there is a reason Cloudflare's CWV view is insufficient (owned histograms, non-Chromium, Grafana overlay).
