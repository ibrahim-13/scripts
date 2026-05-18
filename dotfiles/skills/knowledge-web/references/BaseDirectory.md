# Implementing a Sub-Directory Page with `<base>` in a Vanilla JS HTML Project

This document uses the avro-writer project (deployed at `/avro-writer/`) as the running example throughout.

---

## What `<base>` does

The `<base>` tag sets the base URL that the browser uses to resolve every relative URL in the document. It must be the first element inside `<head>` before any element that has a URL attribute.

```html
<head>
  <meta charset="utf-8" />
  <base href="/avro-writer/" />   <!-- everything below resolves from here -->
  <link rel="icon" href="assets/favicon.ico" />
  <link rel="stylesheet" href="style.css" />
  <script src="lib/comlink.min.js"></script>
</head>
```

Without `<base>`, the three asset paths above resolve relative to the page URL. If the page is served at `/avro-writer/`, they happen to work. But if the page is ever served from a deeper path (`/avro-writer/help/`) or a CDN sub-path, the paths break. `<base>` pins resolution to a fixed root so assets always resolve correctly regardless of the page's actual URL.

---

## Minimal working example

**File layout:**

```
/var/www/my-app/
  index.html
  app.js
  style.css
  assets/
    logo.png
```

**Deployed at:** `https://example.com/my-app/`

**index.html:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <base href="/my-app/" />
  <link rel="stylesheet" href="style.css" />        <!-- resolves to /my-app/style.css -->
  <script src="app.js" defer></script>               <!-- resolves to /my-app/app.js -->
</head>
<body>
  <img src="assets/logo.png" alt="logo" />           <!-- resolves to /my-app/assets/logo.png -->
  <a href="about.html">About</a>                     <!-- resolves to /my-app/about.html -->
</body>
</html>
```

Everything in the HTML that uses a relative URL now resolves from `/my-app/`.

---

## What `<base>` affects (HTML parser)

The HTML parser consults `<base>` when building URLs for these attributes:

| Element | Attribute |
|---------|-----------|
| `<link>` | `href` |
| `<script>` | `src` |
| `<img>` | `src`, `srcset` |
| `<a>` | `href` |
| `<form>` | `action` |
| `<video>`, `<audio>` | `src` |

**Example — all of these resolve correctly with `<base href="/my-app/">`:**

```html
<link rel="icon" href="assets/favicon.ico" />           <!-- /my-app/assets/favicon.ico -->
<link rel="manifest" href="manifest.json" />             <!-- /my-app/manifest.json -->
<link rel="apple-touch-icon" href="assets/logo192.png" /><!-- /my-app/assets/logo192.png -->
<script src="lib/comlink.min.js"></script>                <!-- /my-app/lib/comlink.min.js -->
<img src="assets/logo.png" alt="" />                     <!-- /my-app/assets/logo.png -->
<a href="help.html">Help</a>                             <!-- /my-app/help.html -->
<form action="submit">…</form>                           <!-- /my-app/submit -->
```

---

## What `<base>` does NOT affect (JavaScript)

The `<base>` tag is processed by the HTML parser. It has no effect on JavaScript string values passed to browser APIs. These must be constructed manually:

```js
// WRONG — the Worker constructor resolves this relative to the page URL, not <base>
var worker = new Worker('lib/avro.worker.js');

// CORRECT — construct the full path explicitly
var BASE_URL = '/my-app';
var worker = new Worker(BASE_URL + '/lib/avro.worker.js');
```

The same applies to service worker registration:

```js
// WRONG
navigator.serviceWorker.register('service-worker.js');

// CORRECT
var BASE_URL = '/my-app';
navigator.serviceWorker.register(BASE_URL + '/service-worker.js');
```

And to any other API that takes a URL string: `fetch()`, `XMLHttpRequest`, `new URL()`, `import()`.

**This is why the project keeps both in sync:**

```html
<!-- index.html -->
<base href="/avro-writer/" />
```

```js
// app.js
var BASE_URL = '/avro-writer';
var COMLINK_URL       = BASE_URL + '/lib/avro.worker.202301052101.js';
var SERVICEWORKER_URL = BASE_URL + '/service-worker.js';
```

---

## Trailing slash rule

`<base href>` must end with `/`. Without it, the browser treats the last segment as a filename and strips it when resolving relatives — the same way it handles a file URL.

```html
<!-- CORRECT: trailing slash — resolves style.css → /my-app/style.css -->
<base href="/my-app/" />

<!-- WRONG: no trailing slash — resolves style.css → /style.css (strips "my-app") -->
<base href="/my-app" />
```

The matching `BASE_URL` in JavaScript does NOT include a trailing slash, because it is used as a prefix with an explicit `/` in the concatenation:

```js
var BASE_URL = '/my-app';                          // no trailing slash
var url = BASE_URL + '/service-worker.js';         // → /my-app/service-worker.js
```

---

## Absolute URLs are not affected

`<base>` only affects relative URLs. An absolute URL (one that starts with `https://`, `http://`, or `/`) is used as-is.

```html
<base href="/my-app/" />

<!-- relative — affected by <base> -->
<link rel="stylesheet" href="style.css" />         <!-- → /my-app/style.css -->

<!-- absolute path — NOT affected -->
<link rel="stylesheet" href="/global.css" />        <!-- → /global.css -->

<!-- absolute URL — NOT affected -->
<a href="https://example.com/other">Other</a>      <!-- → https://example.com/other -->
```

---

## Deploying to the root

When the app is at `/`, set both to empty/root values:

```html
<!-- index.html -->
<base href="/" />
```

```js
// app.js
var BASE_URL = '';
var worker = new Worker(BASE_URL + '/lib/avro.worker.js');  // → /lib/avro.worker.js
```

---

## Deploying to a deeper sub-path

```html
<!-- index.html -->
<base href="/tools/text/avro/" />
```

```js
// app.js
var BASE_URL = '/tools/text/avro';
var worker = new Worker(BASE_URL + '/lib/avro.worker.js');
// → /tools/text/avro/lib/avro.worker.js
```

---

## Service worker scope and `<base>`

The service worker's scope is determined by the path of `service-worker.js` itself, not by `<base>`. The service worker file must live at or above the path it needs to intercept.

```
/my-app/service-worker.js    ← scope covers /my-app/ and below ✓
/service-worker.js           ← scope covers everything ✓ but too broad
/my-app/sub/service-worker.js ← scope only covers /my-app/sub/, misses /my-app/ ✗
```

Inside `service-worker.js`, asset paths in `PRECACHE_ASSETS` use `./` which resolves relative to the service worker file's own URL — not `<base>`:

```js
// service-worker.js located at /my-app/service-worker.js
const PRECACHE_ASSETS = [
  './',                  // → /my-app/
  './index.html',        // → /my-app/index.html
  './app.js',            // → /my-app/app.js
  './style.css',         // → /my-app/style.css
];
```

These paths are correct because the service worker file sits at `/my-app/`. No `<base>` involvement.

---

## Local development

When serving the app from root locally (e.g. `http://localhost:8080/`), the sub-path base breaks asset loading:

```html
<!-- breaks on localhost served at / -->
<base href="/avro-writer/" />
```

Two options:

**Option A — change `<base>` for local dev:**

```html
<base href="/" />
```

```js
var BASE_URL = '';
```

**Option B — serve locally under the same sub-path:**

```bash
# Python — serves at http://localhost:8080/avro-writer/
python3 -m http.server 8080 --directory /path/to/project/..
```

Or configure your dev server to mount the project at `/avro-writer/`.

---

## Checklist

When deploying a vanilla HTML/JS project to a sub-directory or sub-url `/my-app/`:

- `<base href="/my-app/" />` is the first significant element inside `<head>`, before any `<link>` or `<script>`
- All asset `href`/`src` attributes in HTML use paths relative to the project root (no leading `/`)
- A `BASE_URL` constant in JavaScript holds the path without a trailing slash (`'/my-app'`)
- `new Worker(...)`, `serviceWorker.register(...)`, `fetch(...)` all use `BASE_URL` as prefix
- `service-worker.js` lives at `/my-app/service-worker.js` (same level as `index.html`)
- `PRECACHE_ASSETS` in the service worker uses `./`-relative paths
- Both `<base href>` and `BASE_URL` are updated together whenever the deployment path changes
