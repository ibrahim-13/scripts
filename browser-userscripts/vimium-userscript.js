// ==UserScript==
// @name         Vimium Keybindings
// @namespace    __gh_ibrahim13_vimium_keybindings
// @version      1.0.0
// @author       github/ibrahim-13
// @description  Vim-like keyboard navigation: scroll, link hints, tab management, history, and more
// @match        *://*/*
// @noframes
// @grant        GM_registerMenuCommand
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_openInTab
// @run-at       document-start
// ==/UserScript==

(function () {
  'use strict';

  // ==================== Constants ====================

  const SCROLL_STEP = 60;                       // px per h/j/k/l (Vimium's scrollStepSize default)
  const HINT_CHARS = 'asdfghjklqwertyuiopzxcvbnm';
  const PREFIX_TIMEOUT_MS = 1500;               // ms to wait for 2nd key after 'g'
  const HUD_SHOW_MS = 2000;                     // default HUD display duration
  const NS = '__vimium_us';                     // element ID namespace

  // Elements considered "clickable" for link hints. Joined once at load.
  const CLICKABLE_SELECTOR = [
    'a[href]',
    'button:not([disabled])',
    'input:not([type="hidden"]):not([disabled])',
    'select:not([disabled])',
    'textarea:not([disabled])',
    'label[for]',
    'summary',
    '[onclick]',
    '[role="button"]',
    '[role="link"]',
    '[role="menuitem"]',
    '[contenteditable=""]',
    '[contenteditable="true"]',
    '[tabindex]:not([tabindex="-1"])',
  ].join(',');

  // ==================== State ====================

  let _enabled = typeof GM_getValue === 'function'
    ? GM_getValue('vimium_us_enabled', true)
    : true;
  let _prefixKey = null;
  let _prefixTimer = null;

  let _hintsActive = false;
  let _hintsNewTab = false;
  let _hintMarkers = [];     // { element, key, markerEl }
  let _hintInput = '';
  let _hintsContainer = null;

  let _helpVisible = false;
  let _frameIndex = -1;
  let _menuCmdId = null;

  // Cache for the resolved scroll container (used only when the document itself isn't scrollable).
  let _scrollerCache = null;
  let _scrollerCacheUrl = '';
  let _scrollerCacheAxis = '';

  // DOM refs
  let _hudEl = null;
  let _hudTimer = null;
  let _helpEl = null;

  // ==================== Key Bindings Table ====================

  const BINDINGS = [
    { key: '?',  desc: 'Show/hide this help dialog' },
    { key: 'h',  desc: 'Scroll left' },
    { key: 'j',  desc: 'Scroll down' },
    { key: 'k',  desc: 'Scroll up' },
    { key: 'l',  desc: 'Scroll right' },
    { key: 'd',  desc: 'Scroll down half a page' },
    { key: 'u',  desc: 'Scroll up half a page' },
    { key: 'f',  desc: 'Open a link in the current tab (link hints)' },
    { key: 'F',  desc: 'Open a link in a new tab (link hints)' },
    { key: 'r',  desc: 'Reload the page' },
    { key: 'R',  desc: 'Hard reload the page (skip cache)' },
    { key: 'gf', desc: 'Cycle forward to the next frame' },
    { key: 'gF', desc: 'Focus the main/top frame' },
    { key: 'H',  desc: 'Go back in history' },
    { key: 'L',  desc: 'Go forward in history' },
    { key: 'J',  desc: 'Go one tab left (uses browser shortcut)' },
    { key: 'K',  desc: 'Go one tab right (uses browser shortcut)' },
    { key: 't',  desc: 'Create a new tab' },
    { key: 'x',  desc: 'Close current tab' },
    { key: 'X',  desc: 'Restore closed tab (uses browser shortcut)' },
  ];

  // ==================== Event Suppression ====================

  // Stop the page (and the browser default) from also acting on a key we've handled.
  function _consume(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  // ==================== HUD ====================

  function _initHud() {
    _hudEl = document.createElement('div');
    _hudEl.id = NS + '_hud';
    Object.assign(_hudEl.style, {
      position: 'fixed',
      bottom: '0',
      left: '0',
      right: '0',
      padding: '4px 10px',
      background: 'rgba(0,0,0,0.88)',
      color: '#fff',
      fontFamily: 'monospace',
      fontSize: '13px',
      lineHeight: '1.6',
      zIndex: '2147483647',
      display: 'none',
      pointerEvents: 'none',
      userSelect: 'none',
    });
    document.body.appendChild(_hudEl);
  }

  function _showHud(msg, durationMs) {
    if (!_hudEl) return;
    _hudEl.textContent = msg;
    _hudEl.style.display = 'block';
    if (_hudTimer) clearTimeout(_hudTimer);
    _hudTimer = null;
    if (durationMs > 0) {
      _hudTimer = setTimeout(_hideHud, durationMs);
    }
  }

  function _hideHud() {
    if (_hudEl) _hudEl.style.display = 'none';
    if (_hudTimer) { clearTimeout(_hudTimer); _hudTimer = null; }
  }

  // ==================== Help Dialog ====================

  function _initHelp() {
    _helpEl = document.createElement('dialog');
    _helpEl.id = NS + '_help';
    Object.assign(_helpEl.style, {
      background: '#16213e',
      color: '#e0e0e0',
      border: '1px solid #3a3f6e',
      borderRadius: '8px',
      padding: '24px 28px',
      minWidth: '440px',
      maxWidth: '600px',
      fontFamily: 'monospace',
      fontSize: '14px',
      zIndex: '2147483646',
      boxShadow: '0 10px 40px rgba(0,0,0,0.7)',
    });

    const title = document.createElement('h2');
    title.textContent = 'Vimium Keybindings';
    Object.assign(title.style, {
      margin: '0 0 20px 0',
      color: '#7ec8e3',
      fontSize: '18px',
      fontWeight: 'bold',
      borderBottom: '1px solid #3a3f6e',
      paddingBottom: '10px',
    });
    _helpEl.appendChild(title);

    const table = document.createElement('table');
    Object.assign(table.style, { width: '100%', borderCollapse: 'collapse' });

    BINDINGS.forEach(({ key, desc }) => {
      const tr = document.createElement('tr');
      const tdKey = document.createElement('td');
      tdKey.textContent = key;
      Object.assign(tdKey.style, {
        padding: '5px 20px 5px 0',
        color: '#f4c842',
        fontWeight: 'bold',
        width: '72px',
        verticalAlign: 'top',
        letterSpacing: '1px',
        whiteSpace: 'nowrap',
      });
      const tdDesc = document.createElement('td');
      tdDesc.textContent = desc;
      Object.assign(tdDesc.style, { padding: '5px 0', color: '#c0c0c0' });
      tr.appendChild(tdKey);
      tr.appendChild(tdDesc);
      table.appendChild(tr);
    });
    _helpEl.appendChild(table);

    const footer = document.createElement('div');
    Object.assign(footer.style, { marginTop: '20px', textAlign: 'right' });

    const closeBtn = document.createElement('button');
    closeBtn.textContent = 'Close  [Esc / ?]';
    Object.assign(closeBtn.style, {
      padding: '6px 14px',
      background: '#2d3561',
      color: '#fff',
      border: '1px solid #4a508e',
      borderRadius: '4px',
      cursor: 'pointer',
      fontFamily: 'monospace',
      fontSize: '13px',
    });
    closeBtn.addEventListener('click', _toggleHelp);
    footer.appendChild(closeBtn);
    _helpEl.appendChild(footer);

    _helpEl.addEventListener('close', () => { _helpVisible = false; });
    document.body.appendChild(_helpEl);
  }

  function _toggleHelp() {
    if (!_helpEl) return;
    if (_helpVisible) {
      _helpEl.close();
      _helpVisible = false;
    } else {
      _helpEl.showModal();
      _helpVisible = true;
    }
  }

  // ==================== Scrolling ====================

  function _docScroller() {
    return document.scrollingElement || document.documentElement || document.body;
  }

  // True if `el` has its own overflow scrollbar and content to scroll, in the given axis.
  function _overflowScrolls(el, axis) {
    if (!el || el.nodeType !== 1) return false;
    const scrollSize = axis === 'y' ? el.scrollHeight : el.scrollWidth;
    const clientSize = axis === 'y' ? el.clientHeight : el.clientWidth;
    if (scrollSize <= clientSize + 1) return false;
    const cs = getComputedStyle(el);
    const overflow = axis === 'y' ? cs.overflowY : cs.overflowX;
    return overflow === 'auto' || overflow === 'scroll' || overflow === 'overlay';
  }

  // Find the element that should be scrolled, mirroring Vimium's behavior: prefer the nearest
  // scrollable ancestor of the focused element, then the document, then the largest scrollable
  // element on the page (e.g. single-page apps like Gmail where the window itself doesn't scroll).
  function _resolveScroller(axis) {
    const doc = _docScroller();

    // 1) Nearest scrollable ancestor of the focused element.
    let el = document.activeElement;
    while (el && el !== document.body && el !== document.documentElement) {
      if (_overflowScrolls(el, axis)) return el;
      el = el.parentElement;
    }

    // 2) The document's own scroller (the common case).
    const docScrolls = axis === 'y'
      ? doc.scrollHeight > doc.clientHeight
      : doc.scrollWidth > doc.clientWidth;
    if (docScrolls) return doc;

    // 3) Reuse the cached fallback if it's still valid.
    if (
      _scrollerCache && _scrollerCache.isConnected &&
      _scrollerCacheUrl === location.href && _scrollerCacheAxis === axis &&
      _overflowScrolls(_scrollerCache, axis)
    ) {
      return _scrollerCache;
    }

    // 4) Last resort: scan for the largest scrollable element. Only reached when the document
    //    isn't scrollable and there's no valid cache, so it runs rarely; the result is cached.
    let best = null;
    let bestArea = 0;
    // Include <body> itself — getElementsByTagName('*') only yields descendants,
    // and body is the actual scroller on pages that set html { overflow: hidden }.
    const all = document.body
      ? [document.body, ...document.body.getElementsByTagName('*')]
      : [];
    for (const node of all) {
      if (_overflowScrolls(node, axis)) {
        const r = node.getBoundingClientRect();
        const area = r.width * r.height;
        if (area > bestArea) { bestArea = area; best = node; }
      }
    }
    _scrollerCache = best;
    _scrollerCacheUrl = location.href;
    _scrollerCacheAxis = axis;
    return best || doc;
  }

  // axis: 'x' | 'y'. magnitude: number of px, or 'half' for half the viewport. sign: -1 | 1.
  function _scroll(axis, magnitude, sign) {
    const target = _resolveScroller(axis);
    if (!target) return;
    const isDoc = target === _docScroller();
    const viewSize = axis === 'y'
      ? (isDoc ? window.innerHeight : target.clientHeight)
      : (isDoc ? window.innerWidth : target.clientWidth);
    const px = (magnitude === 'half' ? viewSize / 2 : magnitude) * sign;

    if (isDoc) {
      window.scrollBy({ [axis === 'y' ? 'top' : 'left']: px, behavior: 'instant' });
    } else {
      target[axis === 'y' ? 'scrollTop' : 'scrollLeft'] += px;
    }
  }

  // ==================== Link Hints ====================

  function _genHintKeys(count) {
    const chars = HINT_CHARS;
    // Pick the smallest fixed width whose combinations cover `count`. Using a single fixed width
    // keeps every hint the same length, so no hint can be a prefix of another.
    let width = 1;
    while (Math.pow(chars.length, width) < count) width++;

    const keys = [];
    const build = (prefix, depth) => {
      if (keys.length >= count) return;
      if (depth === 0) { keys.push(prefix); return; }
      for (let i = 0; i < chars.length; i++) {
        build(prefix + chars[i], depth - 1);
        if (keys.length >= count) return;
      }
    };
    build('', width);
    return keys;
  }

  function _getClickable() {
    const result = [];
    document.querySelectorAll(CLICKABLE_SELECTOR).forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      if (rect.bottom < 0 || rect.top > window.innerHeight) return;
      if (rect.right < 0 || rect.left > window.innerWidth) return;
      const cs = window.getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden' || cs.opacity === '0') return;
      result.push(el);
    });
    return result;
  }

  function _startHints(newTab) {
    if (_hintsActive) return;
    if (!document.body) return; // page not ready yet
    _hintsActive = true;
    _hintsNewTab = newTab;
    _hintInput = '';

    const elements = _getClickable();
    if (elements.length === 0) {
      _hintsActive = false;
      _showHud('No clickable elements found', HUD_SHOW_MS);
      return;
    }

    const keys = _genHintKeys(elements.length);

    _hintsContainer = document.createElement('div');
    _hintsContainer.id = NS + '_hints';
    Object.assign(_hintsContainer.style, {
      position: 'fixed',
      top: '0',
      left: '0',
      width: '100%',
      height: '100%',
      pointerEvents: 'none',
      zIndex: '2147483645',
    });
    document.body.appendChild(_hintsContainer);

    _hintMarkers = elements.map((el, i) => {
      const key = keys[i];
      const rect = el.getBoundingClientRect();
      const marker = document.createElement('div');
      marker.textContent = key.toUpperCase();
      Object.assign(marker.style, {
        position: 'fixed',
        left: Math.max(0, rect.left) + 'px',
        top: Math.max(0, rect.top) + 'px',
        background: '#f4c842',
        color: '#000',
        fontFamily: 'monospace',
        fontSize: '11px',
        fontWeight: 'bold',
        padding: '1px 4px',
        border: '1px solid #a08000',
        borderRadius: '2px',
        lineHeight: '1.4',
        pointerEvents: 'none',
        userSelect: 'none',
        whiteSpace: 'nowrap',
        boxShadow: '0 1px 4px rgba(0,0,0,0.4)',
      });
      _hintsContainer.appendChild(marker);
      return { element: el, key, markerEl: marker };
    });

    _showHud(newTab
      ? 'HINTS (new tab): type the letters... [Esc = cancel]'
      : 'HINTS: type the letters... [Esc = cancel]');

    document.addEventListener('keydown', _handleHintKey, true);
  }

  function _handleHintKey(e) {
    e.preventDefault();
    e.stopImmediatePropagation();

    if (e.key === 'Escape') { _stopHints(); return; }

    if (e.key === 'Backspace') {
      _hintInput = _hintInput.slice(0, -1);
      _refreshHintMarkers();
      return;
    }

    const ch = e.key.length === 1 ? e.key.toLowerCase() : '';
    if (!ch || !HINT_CHARS.includes(ch)) return;

    _hintInput += ch;

    const match = _hintMarkers.find((m) => m.key === _hintInput);
    if (match) {
      const el = match.element;
      _stopHints();
      _activateHint(el, _hintsNewTab);
      return;
    }

    const remaining = _hintMarkers.filter((m) => m.key.startsWith(_hintInput));
    if (remaining.length === 0) {
      _stopHints();
      _showHud('No matching hint', HUD_SHOW_MS);
      return;
    }

    _refreshHintMarkers();
  }

  function _refreshHintMarkers() {
    _hintMarkers.forEach((m) => {
      if (!m.key.startsWith(_hintInput)) {
        m.markerEl.style.display = 'none';
        return;
      }
      m.markerEl.style.display = '';
      while (m.markerEl.firstChild) m.markerEl.removeChild(m.markerEl.firstChild);
      const matchedPart = m.key.slice(0, _hintInput.length).toUpperCase();
      const restPart = m.key.slice(_hintInput.length).toUpperCase();
      if (matchedPart) {
        const span = document.createElement('span');
        span.style.color = '#888';
        span.textContent = matchedPart;
        m.markerEl.appendChild(span);
      }
      m.markerEl.appendChild(document.createTextNode(restPart));
    });
  }

  function _stopHints() {
    _hintsActive = false;
    _hintInput = '';
    _hintMarkers = [];
    if (_hintsContainer) { _hintsContainer.remove(); _hintsContainer = null; }
    _hideHud();
    document.removeEventListener('keydown', _handleHintKey, true);
  }

  function _activateHint(el, newTab) {
    if (newTab) {
      const href = el.getAttribute('href');
      if (href && href !== '#' && !href.startsWith('javascript:')) {
        try {
          const url = new URL(href, window.location.href).href;
          if (typeof GM_openInTab === 'function') {
            GM_openInTab(url, { active: true });
          } else {
            window.open(url, '_blank');
          }
          return;
        } catch (_) { /* fall through to click */ }
      }
    }
    // A synthetic .click() does not move focus like a real click, so focus
    // text-entry elements explicitly before clicking.
    const tag = el.tagName ? el.tagName.toLowerCase() : '';
    if (tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable) {
      try { el.focus(); } catch (_) { /* ignore */ }
    }
    el.click();
  }

  // ==================== Frame Navigation ====================

  function _cycleFrame() {
    const frames = Array.from(document.querySelectorAll('iframe, frame'));
    if (frames.length === 0) {
      _showHud('No frames on this page', HUD_SHOW_MS);
      return;
    }
    _frameIndex = (_frameIndex + 1) % frames.length;
    const frame = frames[_frameIndex];
    try {
      // .focus() on a (even cross-origin) Window is permitted; touching its document is not.
      if (frame.contentWindow) frame.contentWindow.focus();
      frame.focus();
      _showHud('Frame ' + (_frameIndex + 1) + ' / ' + frames.length, HUD_SHOW_MS);
    } catch (_) {
      _showHud('Cannot focus frame ' + (_frameIndex + 1), HUD_SHOW_MS);
    }
  }

  function _focusMainFrame() {
    _frameIndex = -1;
    window.focus();
    if (document.body) {
      // Make sure keyboard focus leaves any child frame and returns to the top document.
      const prev = document.body.getAttribute('tabindex');
      document.body.setAttribute('tabindex', '-1');
      document.body.focus();
      if (prev === null) document.body.removeAttribute('tabindex');
      else document.body.setAttribute('tabindex', prev);
    }
    _showHud('Main frame focused', HUD_SHOW_MS);
  }

  // ==================== Tab Operations ====================

  function _newTab() {
    // Opens the browser's blank tab. Triggered inside a keydown (a user gesture), so window.open
    // is not blocked by the popup blocker if GM_openInTab is unavailable.
    try {
      if (typeof GM_openInTab === 'function') {
        GM_openInTab('about:blank', { active: true });
        return;
      }
    } catch (_) { /* fall through */ }
    window.open('about:blank', '_blank');
  }

  function _closeTab() {
    window.close();
    // If the browser refused to close the tab (it wasn't opened by a script), let the user know.
    setTimeout(() => {
      _showHud('Browser blocked closing this tab — use Ctrl+W', HUD_SHOW_MS);
    }, 150);
  }

  function _restoreTab() {
    _showHud('Use Ctrl+Shift+T (browser shortcut) to restore a closed tab', HUD_SHOW_MS * 2);
  }

  function _switchTab(direction) {
    // No userscript/GM API can switch to a sibling tab; point the user at the native shortcut.
    const shortcut = direction < 0 ? 'Ctrl+Shift+Tab' : 'Ctrl+Tab';
    const which = direction < 0 ? 'left' : 'right';
    _showHud('Use ' + shortcut + ' to go one tab ' + which, HUD_SHOW_MS * 2);
  }

  // ==================== Input Detection ====================

  function _isEditable() {
    const el = document.activeElement;
    if (!el || el === document.body || el === document.documentElement) return false;
    const tag = el.tagName.toLowerCase();
    if (tag === 'input' || tag === 'textarea' || tag === 'select') return true;
    if (el.isContentEditable) return true;
    return false;
  }

  // ==================== Key Handler ====================

  function _onKeydown(e) {
    if (!_enabled) return;
    if (_hintsActive) return; // _handleHintKey (capture) owns the event while hints are shown.

    // While the help dialog is open, only ? and Esc are meaningful; let everything else through
    // so the dialog stays interactive (Tab, button activation, etc.).
    if (_helpVisible) {
      if (e.key === '?' || e.key === 'Escape') {
        _consume(e);
        _toggleHelp();
      }
      return;
    }

    if (_isEditable()) return;

    // Resolve a pending 'g' prefix. gf / gF take no modifiers; anything else cancels the prefix
    // and is then handled as a fresh key press below.
    if (_prefixKey === 'g') {
      clearTimeout(_prefixTimer);
      _prefixTimer = null;
      _prefixKey = null;
      _hideHud();

      if (!e.ctrlKey && !e.metaKey && !e.altKey) {
        if (e.key === 'f') { _consume(e); _cycleFrame(); return; }
        if (e.key === 'F') { _consume(e); _focusMainFrame(); return; }
      }
      // fall through: handle this key normally
    }

    // We never use ctrl/meta/alt combos, so leave those for the page and browser.
    if (e.ctrlKey || e.metaKey || e.altKey) return;

    const k = e.key;

    // Start the 'g' prefix sequence.
    if (k === 'g') {
      _consume(e);
      _prefixKey = 'g';
      _showHud('g');
      _prefixTimer = setTimeout(() => { _prefixKey = null; _hideHud(); }, PREFIX_TIMEOUT_MS);
      return;
    }

    switch (k) {
      case '?': _consume(e); _toggleHelp(); break;

      // Scrolling
      case 'h': _consume(e); _scroll('x', SCROLL_STEP, -1); break;
      case 'l': _consume(e); _scroll('x', SCROLL_STEP, 1); break;
      case 'j': _consume(e); _scroll('y', SCROLL_STEP, 1); break;
      case 'k': _consume(e); _scroll('y', SCROLL_STEP, -1); break;
      case 'd': _consume(e); _scroll('y', 'half', 1); break;
      case 'u': _consume(e); _scroll('y', 'half', -1); break;

      // Link hints
      case 'f': _consume(e); _startHints(false); break;
      case 'F': _consume(e); _startHints(true); break;

      // Reload
      case 'r': _consume(e); location.reload(); break;
      // Hard reload. The legacy forceReload arg to location.reload() is ignored by modern
      // browsers (and removed from Firefox), so this degrades to a normal reload there.
      case 'R':
        _consume(e);
        try { location.reload(true); } catch (_) { location.reload(); }
        break;

      // History
      case 'H': _consume(e); history.back(); break;
      case 'L': _consume(e); history.forward(); break;

      // Tabs
      case 'J': _consume(e); _switchTab(-1); break;
      case 'K': _consume(e); _switchTab(1); break;
      case 't': _consume(e); _newTab(); break;
      case 'x': _consume(e); _closeTab(); break;
      case 'X': _consume(e); _restoreTab(); break;
    }
  }

  // ==================== Menu ====================

  function _updateMenu() {
    // The toggle menu is optional — skip it if the manager doesn't expose the API.
    if (typeof GM_registerMenuCommand !== 'function') return;
    const label = '[Vimium] ' + (_enabled ? '🟥 Disable' : '✅ Enable');
    _menuCmdId = GM_registerMenuCommand(label, function () {
      _enabled = !_enabled;
      if (typeof GM_setValue === 'function') GM_setValue('vimium_us_enabled', _enabled);
      if (!_enabled && _hintsActive) _stopHints();
      _updateMenu();
      _showHud('Vimium ' + (_enabled ? 'enabled' : 'disabled'), HUD_SHOW_MS);
    }, { id: _menuCmdId });
  }

  // ==================== Init ====================

  function _initUI() {
    _initHud();
    _initHelp();
  }

  function _init() {
    // Attach the key listener as early as possible (capture phase), so we intercept keys before
    // the page's own handlers — mirroring Vimium's document-start interception. The handlers guard
    // against UI elements that don't exist yet, so this is safe before the DOM is ready.
    document.addEventListener('keydown', _onKeydown, true);
    _updateMenu();

    if (document.body) {
      _initUI();
    } else {
      document.addEventListener('DOMContentLoaded', _initUI);
    }
  }

  _init();

})();
