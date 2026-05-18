# PWA Implementation Guide (Vanilla JS)

## 1. Web App Manifest

Create `manifest.json` at the root of your site.

```json
{
  "short_name": "Avro Writer",
  "name": "Avro Writer - Phonetic Bangla",
  "icons": [
    {
      "src": "assets/favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    },
    {
      "src": "assets/logo192.png",
      "type": "image/png",
      "sizes": "192x192"
    },
    {
      "src": "assets/logo512.png",
      "type": "image/png",
      "sizes": "512x512"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
```

- `display: "standalone"` — app opens without browser UI (no address bar)
- `start_url: "."` — relative path; works correctly when the app is deployed in a subdirectory
- `icons` — required for installability; provide at least 192×192 and 512×512; a favicon entry covers smaller sizes
- `theme_color` / `background_color` — control the splash screen and browser toolbar tint

---

## 2. Link Manifest and Theme in HTML

```html
<head>
  <meta name="theme-color" content="#000000" />
  <meta name="description" content="A small PWA for writing Phonetic Bangla" />
  <link rel="apple-touch-icon" href="assets/logo192.png" />
  <link rel="manifest" href="manifest.json" />
</head>
```

- `theme-color` meta — colors the browser toolbar on mobile (should match `theme_color` in manifest)
- `apple-touch-icon` — used by iOS Safari for the home-screen icon; not covered by the manifest on iOS
- `manifest` link — tells the browser this site is a PWA; use a relative path when a `<base>` tag is present

### Subdirectory deployment with `<base>`

When the app is hosted at a subpath (e.g. `/avro-writer/`), add a `<base>` tag so all relative URLs resolve correctly:

```html
<head>
  <base href="/avro-writer/" />
  <!-- All relative hrefs/srcs below are now relative to /avro-writer/ -->
  <link rel="manifest" href="manifest.json" />
</head>
```

With `<base>` in place, `manifest.json`, asset paths, and the service worker URL can all be written as relative paths without duplicating the subpath string everywhere.

---

## 3. Service Worker File

Create `service-worker.js` at the root of the app scope.

### 3a. Define a cache name and asset list

```js
'use strict';

const CACHE_NAME = 'avro-writer-v1';

const PRECACHE_ASSETS = [
  './',
  './index.html',
  './app.js',
  './style.css',
  './manifest.json',
  './assets/favicon.ico',
  './assets/logo192.png',
  './assets/logo512.png',
  './assets/external-link.png',
  './assets/avro-keyboard-layout.png',
  './lib/avro.min.202102220019.js',
  './lib/avro.worker.202301052101.js',
  './lib/comlink.min.202301052101.js',
];
```

- Bump the version string (`v1` → `v2`) whenever assets change — this triggers the activate cleanup below
- List every file the app needs to work offline; a missing entry will cause a cache miss on that file
- Use relative paths (`./`) so the list works regardless of deployment subpath

### 3b. Install event — pre-cache all static assets

```js
self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(PRECACHE_ASSETS);
    })
  );
  self.skipWaiting();
});
```

- `event.waitUntil` — keeps the SW alive until the promise resolves
- `cache.addAll` — fetches and stores every listed URL atomically; if any request fails the whole install fails
- `self.skipWaiting()` — skips the waiting phase so the new SW activates immediately without waiting for existing tabs to close

### 3c. Activate event — delete stale caches and claim clients

```js
self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys
          .filter(function (key) { return key !== CACHE_NAME; })
          .map(function (key) { return caches.delete(key); })
      );
    })
  );
  self.clients.claim();
});
```

- Runs after the new SW takes control
- Deletes every cache whose name differs from `CACHE_NAME` (i.e., old versions)
- `self.clients.claim()` — makes the new SW take control of already-open pages immediately, without a reload

### 3d. Fetch event — cache-first with network fallback

```js
self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then(function (cached) {
      if (cached) {
        return cached;
      }
      return fetch(event.request).then(function (networkResponse) {
        if (networkResponse && networkResponse.status === 200) {
          var responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then(function (cache) {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      });
    })
  );
});
```

- Only `GET` requests are intercepted; `POST` and others bypass the SW entirely
- Cache hit → return cached asset immediately (works offline)
- Cache miss → fetch from network; if the response is `200`, store a clone in the cache for future requests
- The response must be cloned before passing to `cache.put` because a `Response` body can only be consumed once

### 3e. Message event — on-demand SW update

```js
self.addEventListener('message', function (event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
```

- Allows the main thread to trigger an immediate SW activation without the user closing all tabs
- Called from the page via: `navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' })`

---

## 4. Register the Service Worker in JavaScript

Registration lives in a dedicated function in `app.js` and runs on the `load` event.

```js
var BASE_URL = '/avro-writer';
var SERVICEWORKER_URL = BASE_URL + '/service-worker.js';

function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  window.addEventListener('load', function () {
    navigator.serviceWorker
      .register(SERVICEWORKER_URL)
      .then(function (registration) {
        registration.onupdatefound = function () {
          var installing = registration.installing;
          if (!installing) return;
          installing.onstatechange = function () {
            if (installing.state === 'installed') {
              if (navigator.serviceWorker.controller) {
                console.log('New content available; will be used when tabs are closed.');
              } else {
                console.log('Content cached for offline use.');
              }
            }
          };
        };
      })
      .catch(function (err) {
        console.error('Service worker registration failed:', err);
      });
  });
}
```

- `'serviceWorker' in navigator` — feature-detect before using; no-ops gracefully in unsupported browsers
- Register on `load` — avoids competing with page resources during initial load
- `onupdatefound` / `onstatechange` — detect when a new SW has been downloaded and is ready
  - `installing.state === 'installed'` with an existing `controller` → update is ready, will activate on next tab open
  - `installing.state === 'installed'` without a `controller` → first install, app is now cached for offline use
- Call `registerServiceWorker()` at the end of your `DOMContentLoaded` handler

---

## 5. Custom Buttons

### 5a. Custom Install Button (beforeinstallprompt)

The browser fires `beforeinstallprompt` when it decides the app is installable. Suppress the default mini-infobar and surface your own button instead.

```js
// In index.html — hidden by default; shown only when the app is installable
// <button id="install-btn" style="display:none"><b>Install</b></button>

var deferredInstallPrompt = null;

window.addEventListener('beforeinstallprompt', function (ev) {
  ev.preventDefault();           // suppress the browser's default prompt
  deferredInstallPrompt = ev;    // save for later
  installBtn.visible = true;     // reveal your own install button
});

installBtn.onclick = function () {
  if (!deferredInstallPrompt) return;
  deferredInstallPrompt.prompt();
  deferredInstallPrompt.userChoice.then(function () {
    deferredInstallPrompt = null;
    installBtn.visible = false;
  });
};

window.addEventListener('appinstalled', function () {
  deferredInstallPrompt = null;
  installBtn.visible = false;    // hide the button after install completes
});
```

- `ev.preventDefault()` — must be called synchronously in the handler to suppress the mini-infobar
- `deferredInstallPrompt` is single-use; clear it after `prompt()` is called
- `appinstalled` fires whether the user installed via your button or the browser's own UI — always hide the button in response

### 5b. Custom Service Worker Update Button

This triggers update for service worker in case the user want to update it explicitly.

The following examples add function to `onclick` event of a button instance `updateSWBtn`
```js
// Attach to existing button node instance variable `updateSWBtn`
updateSWBtn.onclick = function() {
  if ('serviceWorker' in navigator) {
  navigator.serviceWorker.ready.then((registration) => {
    registration.update();
  });
  }
}
```

The following example declares a function which is called when button is clicked:
```js
function updateSW() {
  if ('serviceWorker' in navigator) {
  navigator.serviceWorker.ready.then((registration) => {
    registration.update();
  });
  }
}
````

```html
<button onclick="updateSW()">Update Service Workder</button>
```

---

## 6. Subdirectory Deployment — Path Alignment

When the app lives at `/avro-writer/` instead of `/`, every path reference must be consistent:

| Location | Value |
|---|---|
| `<base href>` in HTML | `/avro-writer/` |
| `manifest.json` → `start_url` | `.` (resolves to `/avro-writer/`) |
| Icon paths in manifest | `assets/logo192.png` (relative, resolved via `start_url`) |
| `SERVICEWORKER_URL` in JS | `/avro-writer/service-worker.js` |
| `PRECACHE_ASSETS` in SW | `./` prefixed paths (relative to SW scope) |

The SW file must sit at or above the scope it controls. With `<base>`, the manifest link and icon paths all resolve through the base URL automatically, so only the JS registration URL needs to be an explicit absolute path.

---

## 7. Additional Manifest Fields

The manifest supports optional fields beyond the core set:

```json
{
  "lang": "en-us",
  "description": "Search on websites with DuckDuckGo's bangs",
  "orientation": "any"
}
```

- `lang` — declares the primary language of the app; used by assistive technologies and app stores
- `description` — a human-readable description; shown in some browser install UIs and app stores
- `orientation` — locks or allows screen orientation; `"any"` lets the OS decide; other values: `"portrait"`, `"landscape"`

---

## 8. Subdirectory Deployment — Absolute Paths (No `<base>` Tag)

An alternative to the `<base>` approach is to write absolute paths everywhere and skip the `<base>` tag entirely. This avoids `<base>` side-effects (e.g. anchor `#` links or `target` behavior changing).

**HTML** — every path is an explicit absolute URL from the root:

```html
<head>
  <meta name="theme-color" content="#1a1a1a"/>
  <link rel="manifest" href="/search_bang/manifest.json">
  <link rel="icon" type="image/svg+xml" href="/search_bang/assets/search.svg" />
</head>
```

**SW registration with explicit `scope`** — because there is no `<base>` tag, the scope cannot be inferred from it; pass it explicitly:

```js
window.addEventListener('load', () => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker
      .register('/search_bang/sw.js', { scope: '/search_bang/' })
      .then(() => console.log('Service worker registered!'))
      .catch((error) => console.warn('Error registering service worker:', error));
  }
});
```

- `scope` — restricts which URLs the SW controls; must be at or below the SW script's path
- Without a `<base>` tag the browser cannot derive the intended scope, so stating it explicitly avoids accidental root-scope registration

**PRECACHE_ASSETS in SW** — use the same absolute paths:

```js
cache.addAll([
  '/search_bang/',
  '/search_bang/assets/script.js',
  '/search_bang/assets/styles.css',
]);
```

| Approach | Trade-off |
|---|---|
| `<base>` + relative paths | One place to change the subpath; `<base>` affects all relative URLs on the page |
| Absolute paths everywhere | No `<base>` side-effects; subpath string is repeated in every reference |

---

## 9. Service Worker Variations

### 9a. `skipWaiting()` before `event.waitUntil`

`self.skipWaiting()` does not need to be inside `event.waitUntil`. Calling it synchronously at the top of the install handler is equivalent — it queues the skip regardless of cache completion:

```js
self.addEventListener('install', (event) => {
  self.skipWaiting();           // queued immediately
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_ASSETS))
  );
});
```

### 9b. Activate with an allowlist array

Instead of filtering caches by key inequality, maintain an explicit allowlist array. This is useful when multiple named caches coexist and only some should be cleared:

```js
self.addEventListener('activate', (event) => {
  const cacheAllowList = [CACHE_NAME];

  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => {
          if (!cacheAllowList.includes(key)) {
            return caches.delete(key);
          }
        })
      )
    )
  );
});
```

### 9c. Fetch handler with async/await

The fetch event handler can use `async/await` instead of `.then()` chains. Also note that caching the network response on miss is optional — omitting it limits caching strictly to pre-cached assets:

```js
self.addEventListener('fetch', (event) => {
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(event.request);
    if (cachedResponse) {
      return cachedResponse;
    }
    try {
      const fetchResponse = await fetch(event.request);
      // Optionally cache the response for future requests:
      // cache.put(event.request, fetchResponse.clone());
      return fetchResponse;
    } catch (e) {
      // Network failed and no cache hit — request will fail
    }
  })());
});
```

- Omitting `cache.put` means only pre-cached assets are ever served from cache; dynamic/uncached requests always go to the network
- Wrap the async IIFE in `event.respondWith(...)` so the browser waits for the promise

---

## 10. Triggering SW Updates from the UI via `registration.update()`

Instead of the `SKIP_WAITING` message pattern, you can expose a button that calls `registration.update()` to force the browser to check for a new SW version immediately:

```js
// In your app JS — e.g. bound to a "Trigger SW Update" button
function doUpdate() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.ready.then((registration) => {
      registration.update();
    });
  }
}
```

- `navigator.serviceWorker.ready` resolves with the active registration (waits until a SW is controlling the page)
- `registration.update()` bypasses the browser's 24-hour update throttle and fetches the SW script immediately
- If a new SW is found it goes through install → waiting → activate; combine with `skipWaiting()` in the SW to activate without a tab reload
- This approach is simpler than the `SKIP_WAITING` message pattern when you just want to check for updates on demand rather than auto-activate a waiting worker

---

## Checklist

| Item | Required for install prompt |
|---|---|
| `manifest.json` linked in `<head>` | Yes |
| `name` and `short_name` in manifest | Yes |
| At least one icon ≥ 192×192 | Yes |
| `start_url` in manifest | Yes |
| Service worker registered | Yes |
| Served over HTTPS (or localhost) | Yes |
| `apple-touch-icon` link in `<head>` | Recommended (iOS) |
| `onupdatefound` / `onstatechange` handlers | Recommended |
| `beforeinstallprompt` handling | Recommended (custom install UX) |
| Explicit `scope` in SW registration (when not using `<base>`) | Recommended (subdirectory) |
| `lang`, `description`, `orientation` in manifest | Optional |
| `registration.update()` UI trigger for on-demand SW refresh | Optional |
