# JavaScript Proxy — Patterns from app.js and proxy-examples

`app.js` uses a `makeProxy` factory to wrap groups of DOM elements behind a clean property API. The `proxy-examples/` directory shows the same idea taken further: full self-contained components whose entire lifecycle — DOM creation, event wiring, and state management — is mediated through a Proxy.

---

## Part 1 — Element-facade pattern (app.js)

### The makeProxy factory

```js
function makeProxy(elements, schema) {
  return new Proxy(elements, {
    get(target, prop) {
      if (prop in schema && schema[prop].get) {
        return schema[prop].get(target);
      }
    },
    set(target, prop, value) {
      if (prop in schema && schema[prop].set) {
        schema[prop].set(target, value);
      }
      return true;
    },
  });
}
```

`elements` is the raw target (a bag of DOM refs or plain values). `schema` defines virtual properties with `get`/`set` handlers. Callers never touch the raw target; they only read and write the virtual properties.

---

### 1. Single element — show/hide toggle

**Before**

```js
var btn = document.getElementById('install-btn');

btn.style.display = 'none';
btn.style.display = '';
var isVisible = btn.style.display !== 'none';
```

**After**

```js
var installBtn = makeProxy(
  { btn: document.getElementById('install-btn') },
  {
    visible: {
      get(els)       { return els.btn.style.display !== 'none'; },
      set(els, show) { els.btn.style.display = show ? '' : 'none'; },
    },
  }
);

installBtn.visible = false;
installBtn.visible = true;
var isVisible = installBtn.visible;
```

---

### 2. Multiple elements controlled by one property

**Before**

```js
var full = document.getElementById('header-full');
var btn  = document.getElementById('header-btn');

function showHeader(show) {
  full.style.display = show ? '' : 'none';
  btn.style.display  = show ? 'none' : '';
}
```

**After**

```js
var header = makeProxy(
  { full: document.getElementById('header-full'),
    btn:  document.getElementById('header-btn') },
  {
    visible: {
      get(els) { return els.full.style.display !== 'none'; },
      set(els, show) {
        els.full.style.display = show ? '' : 'none';
        els.btn.style.display  = show ? 'none' : '';
      },
    },
  }
);

header.visible = false;  // hides full, shows btn
header.visible = true;   // shows full, hides btn
```

---

### 3. Form state read/write

**Before**

```js
var form = document.getElementById('lang-form');

function getLang() {
  var checked = form.querySelector('input[type="radio"]:checked');
  return checked ? checked.value : null;
}
function setLang(value) {
  form.querySelectorAll('input[type="radio"]').forEach(function (r) {
    r.checked = r.value === value;
  });
}
```

**After**

```js
var langForm = makeProxy(
  { form: document.getElementById('lang-form') },
  {
    lang: {
      get(els) {
        var checked = els.form.querySelector('input[type="radio"]:checked');
        return checked ? checked.value : null;
      },
      set(els, value) {
        els.form.querySelectorAll('input[type="radio"]').forEach(function (r) {
          r.checked = r.value === value;
        });
      },
    },
  }
);

langForm.lang = 'bn';
var current = langForm.lang;
```

---

### 4. Write-only and read-only virtual properties

Omit `get` to make a property write-only; omit `set` to make it read-only.

**Before**

```js
var el = document.getElementById('text-area');

function setCaret(pos) {
  el.focus();
  el.selectionStart = pos;
  el.selectionEnd   = pos;
}
var pos = el.selectionStart;
```

**After**

```js
var textArea = makeProxy(
  { el: document.getElementById('text-area') },
  {
    value: {
      get(els)    { return els.el.value; },
      set(els, v) { els.el.value = v; },
    },
    selectionStart: {
      get(els) { return els.el.selectionStart; },
      // no set — read-only virtual property
    },
    caret: {
      // no get — write-only virtual property
      set(els, pos) {
        els.el.focus();
        els.el.selectionStart = pos;
        els.el.selectionEnd   = pos;
      },
    },
  }
);

textArea.value = 'hello';
textArea.caret = 5;
var pos = textArea.selectionStart;
```

---

### 5. Plain object — validated property

The factory works on any target, not just DOM elements.

**Before**

```js
var config = { volume: 0.8 };

function setVolume(v) {
  if (v < 0 || v > 1) throw new RangeError('volume must be 0–1');
  config.volume = v;
}
```

**After**

```js
var config = makeProxy(
  { volume: 0.8 },
  {
    volume: {
      get(t)    { return t.volume; },
      set(t, v) {
        if (v < 0 || v > 1) throw new RangeError('volume must be 0–1');
        t.volume = v;
      },
    },
  }
);

config.volume = 0.5;
config.volume = 1.5;  // throws RangeError
```

---

### 6. Derived / computed read-only property

**Before**

```js
var cart = { items: [] };

function totalPrice() {
  return cart.items.reduce((sum, item) => sum + item.price * item.qty, 0);
}
```

**After**

```js
var cart = makeProxy(
  { items: [] },
  {
    items: {
      get(t)    { return t.items; },
      set(t, v) { t.items = v; },
    },
    total: {
      get(t) {
        return t.items.reduce((sum, item) => sum + item.price * item.qty, 0);
      },
    },
  }
);

cart.items = [{ price: 10, qty: 2 }, { price: 5, qty: 1 }];
console.log(cart.total); // 25
```

---

### 7. Side-effect on set (localStorage mirror)

**Before**

```js
function saveLang(v) {
  if (v === null) localStorage.removeItem('app/lang');
  else            localStorage.setItem('app/lang', v);
}
function loadLang() {
  return localStorage.getItem('app/lang');
}
```

**After**

```js
var store = makeProxy(
  {},
  {
    lang: {
      get()     { return localStorage.getItem('app/lang'); },
      set(_, v) {
        if (v === null) localStorage.removeItem('app/lang');
        else            localStorage.setItem('app/lang', v);
      },
    },
  }
);

store.lang = 'bn';
var lang = store.lang;
store.lang = null;
```

---

## Part 2 — Self-contained component pattern

The three files in `proxy-examples/` push the pattern further. Instead of wrapping pre-existing elements, each factory function **creates its own DOM**, manages its own event listeners, and returns a single Proxy as the only public interface. Setting a property on the returned object is the entire API.

The core differences from Part 1:

| Aspect | Part 1 (makeProxy) | Part 2 (component factories) |
|---|---|---|
| DOM source | Pre-existing elements passed in | Created inside the factory |
| Proxy target | Bag of element refs | Plain state object with defaults |
| `get` trap | Virtual computed properties | Pass-through to backing state |
| `set` trap | Dispatches to schema handlers | Switch on `prop`, sync DOM, then `Reflect.set` |
| Backing state in sync | Not kept (no `Reflect.set`) | Always kept via `Reflect.set` at the end |
| Multiple instances | One proxy per call | Unique IDs per instance via `prefix` |

---

### 8. Component factory — confirm dialog

`CreateConfirmDialog` creates a `<dialog>` element, injects it into the document, and returns a Proxy. Callers only ever touch the proxy.

```js
function CreateConfirmDialog(prefix) {
  // --- unique IDs so multiple instances don't collide ---
  const _prefix   = String(prefix || Math.floor(Math.random() * 10e7));
  const idDialog  = 'confirmDialog_' + _prefix;
  const idMsg     = 'message_'       + _prefix;
  const idYes     = 'yesBtn_'        + _prefix;
  const idNo      = 'noBtn_'         + _prefix;

  let elemDialog, elemMsg, elemYes, elemNo;
  let hasLoaded = false;

  // --- backing state with sensible defaults ---
  const dialogState = {
    show: false,
    message: 'Are you sure?',
    textYes: 'Yes',
    textNo: 'No',
    noOp: false,
    callback: () => {},
    exec(result) {
      if (typeof this.callback === 'function') this.callback(result);
    },
  };

  // --- proxy: each set syncs to DOM, then updates backing state ---
  const dialogProxy = new Proxy(dialogState, {
    set(target, prop, value) {
      // Before DOM exists, write only to state (replayed on init)
      if (!hasLoaded) return Reflect.set(target, prop, value);

      if (prop === 'message' && elemMsg)  elemMsg.innerText = String(value);
      if (prop === 'textYes' && elemYes)  elemYes.innerText = String(value);
      if (prop === 'textNo'  && elemNo)   elemNo.innerText  = String(value);

      if (prop === 'noOp' && elemNo)
        elemNo.style.display = value ? 'none' : 'initial';

      if (prop === 'show' && elemDialog) {
        value ? elemDialog.showModal() : elemDialog.close();
      }

      return Reflect.set(target, prop, value); // keep backing state current
    },
  });

  // --- init: create DOM, wire events, replay buffered state ---
  const init = () => {
    if (hasLoaded) return;
    if (document.readyState !== 'complete' && document.readyState !== 'interactive') return;

    elemDialog = document.createElement('dialog');
    elemDialog.id = idDialog;
    elemDialog.innerHTML = `
      <p id="${idMsg}"></p>
      <button id="${idNo}"></button>
      <button id="${idYes}"></button>
    `;
    document.body.appendChild(elemDialog);
    elemMsg = document.getElementById(idMsg);
    elemYes = document.getElementById(idYes);
    elemNo  = document.getElementById(idNo);
    hasLoaded = true;

    elemYes.addEventListener('click', () => {
      dialogProxy.show = false;
      if (!dialogProxy.noOp) dialogProxy.exec.apply(dialogProxy, [true]);
    });
    elemNo.addEventListener('click', () => {
      dialogProxy.show = false;
      if (!dialogProxy.noOp) dialogProxy.exec.apply(dialogProxy, [false]);
    });

    // replay state that was buffered before DOM was ready
    dialogProxy.message = dialogProxy.message;
    dialogProxy.textYes = dialogProxy.textYes;
    dialogProxy.textNo  = dialogProxy.textNo;
    dialogProxy.noOp    = dialogProxy.noOp;
    dialogProxy.show    = dialogProxy.show;
  };

  document.readyState === 'complete' || document.readyState === 'interactive'
    ? init()
    : document.addEventListener('readystatechange', init);

  return dialogProxy;
}
```

**Usage**

```js
const confirm = CreateConfirmDialog('delete');

confirm.message  = 'Delete this file?';
confirm.textYes  = 'Delete';
confirm.textNo   = 'Keep';
confirm.callback = (ok) => { if (ok) deleteFile(); };
confirm.show     = true;
```

---

### 9. `hasLoaded` guard — buffering writes before DOM exists

A component returned before `DOMContentLoaded` must accept configuration immediately. The guard lets callers set properties at any time; the `init` replay applies them to the DOM once elements exist.

```js
// Pattern skeleton
const state   = { title: 'Default', visible: false };
let   domElem = null;
let   ready   = false;

const ctrl = new Proxy(state, {
  set(target, prop, value) {
    if (!ready) return Reflect.set(target, prop, value); // buffer

    if (prop === 'title'   && domElem) domElem.textContent      = value;
    if (prop === 'visible' && domElem) domElem.style.display = value ? '' : 'none';

    return Reflect.set(target, prop, value);
  },
});

function init() {
  if (ready) return;
  domElem = document.createElement('div');
  document.body.appendChild(domElem);
  ready = true;

  // replay everything that was written before DOM existed
  ctrl.title   = ctrl.title;
  ctrl.visible = ctrl.visible;
}

// Configure before DOM is ready — safely buffered
ctrl.title   = 'My widget';
ctrl.visible = true;

document.addEventListener('DOMContentLoaded', init);
```

---

### 10. `Reflect.set` — keeping backing state in sync

Without `Reflect.set`, reads from the proxy after a write return stale values.

```js
const state = { count: 0 };

// Wrong — backing state never updated
const broken = new Proxy(state, {
  set(target, prop, value) {
    if (prop === 'count') console.log('count changed to', value);
    return true; // forgot Reflect.set
  },
});
broken.count = 5;
console.log(broken.count); // 0 — stale!

// Correct — sync DOM/side-effects AND update backing state
const correct = new Proxy(state, {
  set(target, prop, value) {
    if (prop === 'count') console.log('count changed to', value);
    return Reflect.set(target, prop, value); // state.count = value
  },
});
correct.count = 5;
console.log(correct.count); // 5
```

---

### 11. Array property that rebuilds DOM

Setting `options` or `actions` to a new array tears down and rebuilds child elements entirely. The caller simply replaces the array; DOM reconstruction is hidden in the `set` trap.

**Before**

```js
function renderOptions(container, options) {
  container.innerHTML = '';
  options.forEach(opt => {
    const input = document.createElement('input');
    input.type  = 'radio';
    input.value = opt.value;
    const label = document.createElement('label');
    label.appendChild(input);
    label.append(opt.label);
    container.appendChild(label);
  });
}

renderOptions(formDiv, [{ value: 'a', label: 'Option A' }]);
renderOptions(formDiv, [{ value: 'b', label: 'Option B' }]); // must call again to update
```

**After**

```js
const state = { options: [] };
let   container = document.getElementById('options-container');

const ctrl = new Proxy(state, {
  set(target, prop, value) {
    if (prop === 'options' && Array.isArray(value)) {
      container.innerHTML = '';
      value.forEach(opt => {
        const input = document.createElement('input');
        input.type  = 'radio';
        input.value = opt.value;
        const label = document.createElement('label');
        label.appendChild(input);
        label.append(opt.label);
        container.appendChild(label);
      });
    }
    return Reflect.set(target, prop, value);
  },
});

ctrl.options = [{ value: 'a', label: 'Option A' }];
ctrl.options = [{ value: 'b', label: 'Option B' }]; // DOM rebuilt automatically
```

---

### 12. Bounds clamping — silent discard of invalid writes

`ui-floating-menu.js` uses `x` and `y` setters to keep a draggable element inside the viewport. Out-of-range values are silently dropped by returning `true` without calling `Reflect.set`.

**Before**

```js
function moveMenu(el, x, y) {
  if (x < 0 || x > window.innerWidth  - el.clientWidth)  return;
  if (y < 0 || y > window.innerHeight - el.clientHeight) return;
  el.style.left = x + 'px';
  el.style.top  = y + 'px';
}
```

**After**

```js
const state   = { x: 100, y: 100 };
let   elemMenu = document.getElementById('floating-menu');

const menuCtrl = new Proxy(state, {
  set(target, prop, value) {
    if (prop === 'x') {
      if (value < 0 || value > window.innerWidth - elemMenu.clientWidth) return true; // discard
      elemMenu.style.left = value + 'px';
    }
    if (prop === 'y') {
      if (value < 0 || value > window.innerHeight - elemMenu.clientHeight) return true; // discard
      elemMenu.style.top = value + 'px';
    }
    return Reflect.set(target, prop, value);
  },
});

menuCtrl.x = 200;    // applies
menuCtrl.x = -50;    // silently ignored
menuCtrl.x = 99999;  // silently ignored
```

---

### 13. Component self-control via its own proxy

In `ui-floating-menu.js`, the drag event handlers write back to `menuState.x` / `menuState.y` rather than directly to `elemMenu.style`. The component's own internal logic goes through the same proxy as external callers, so bounds clamping and state sync apply automatically.

```js
const state    = { x: 100, y: 100, dragging: false, offsetX: 0, offsetY: 0 };
let   elemMenu = document.getElementById('floating-menu');

const menuState = new Proxy(state, {
  set(target, prop, value) {
    if (prop === 'x' && elemMenu) {
      if (value < 0 || value > window.innerWidth - elemMenu.clientWidth) return true;
      elemMenu.style.left = value + 'px';
    }
    if (prop === 'y' && elemMenu) {
      if (value < 0 || value > window.innerHeight - elemMenu.clientHeight) return true;
      elemMenu.style.top = value + 'px';
    }
    return Reflect.set(target, prop, value);
  },
});

// Internal drag handler — goes through the proxy, not around it
function onDrag(clientX, clientY) {
  if (menuState.dragging) {
    menuState.x = clientX - menuState.offsetX; // clamping applies here too
    menuState.y = clientY - menuState.offsetY;
  }
}

elemMenu.addEventListener('mousedown', e => {
  menuState.dragging = true;
  menuState.offsetX  = e.clientX - elemMenu.offsetLeft;
  menuState.offsetY  = e.clientY - elemMenu.offsetTop;
});
document.addEventListener('mousemove', e => onDrag(e.clientX, e.clientY));
document.addEventListener('mouseup',   () => { menuState.dragging = false; });
```

---

### 14. Behavioral flags — changing component mode

`noOp` in `ui-confirm-dialog.js` switches the dialog into an informational mode: the Cancel button disappears and the callback is not invoked on confirmation. A single boolean property changes both the visual and functional behaviour.

```js
const confirm = CreateConfirmDialog('alert');

// Informational mode — only "Ok", no callback
confirm.noOp    = true;
confirm.message = 'Your file has been saved.';
confirm.textYes = 'OK';
confirm.show    = true;

// Back to confirmation mode
confirm.noOp     = false;
confirm.message  = 'Delete this file?';
confirm.callback = (ok) => { if (ok) deleteFile(); };
confirm.show     = true;
```

Pattern in the `set` trap:

```js
if (prop === 'noOp' && elemNo) {
  elemNo.style.display = value ? 'none' : 'initial';
}
```

One flag write drives both the DOM change (hiding the button) and the behavioural change (skipping `exec` in the click handler), with no extra API surface.

---

### 15. Multiple independent instances

Because each factory generates unique element IDs from the `prefix` argument, you can create as many independent instances as needed. Each instance has its own DOM, its own state object, and its own Proxy — they share no mutable state.

```js
const deleteConfirm = CreateConfirmDialog('delete');
const logoutConfirm = CreateConfirmDialog('logout');
const optionPicker  = CreateOptionDialog('theme');

deleteConfirm.message  = 'Delete this file?';
deleteConfirm.callback = (ok) => { if (ok) deleteFile(); };

logoutConfirm.message  = 'Log out of all devices?';
logoutConfirm.callback = (ok) => { if (ok) logoutAll(); };

optionPicker.message  = 'Choose a theme:';
optionPicker.options  = [
  { label: 'Light', value: 'light' },
  { label: 'Dark',  value: 'dark'  },
];
optionPicker.callback = (v) => applyTheme(v);

deleteConfirm.show = true; // only this dialog opens
```

---

## Summary of all patterns

| # | Pattern | Key mechanism |
|---|---|---|
| 1 | Single element toggle | `get`/`set` in schema; no raw ref escapes |
| 2 | Multi-element coordination | One virtual property drives multiple elements |
| 3 | Form state read/write | `get` queries DOM; `set` updates DOM |
| 4 | Write-only / read-only | Omit `get` or `set` from schema entry |
| 5 | Property validation | Throw or guard inside `set` before mutating |
| 6 | Derived computed property | `get`-only schema entry, no stored value |
| 7 | Storage mirror | `get`/`set` delegate to `localStorage` |
| 8 | Component factory | Factory creates DOM, returns Proxy as sole API |
| 9 | Pre-DOM buffering | `hasLoaded` guard + state replay in `init` |
| 10 | `Reflect.set` sync | Always call at end of `set` trap so reads stay accurate |
| 11 | Array → DOM rebuild | `set` trap detects array, tears down and rebuilds children |
| 12 | Bounds clamping | Return `true` without `Reflect.set` to silently discard |
| 13 | Self-control via proxy | Internal event handlers write through the proxy, not around it |
| 14 | Behavioral flags | One boolean property changes both visual and functional mode |
| 15 | Multiple instances | Unique `prefix` → unique IDs → no shared state between instances |
