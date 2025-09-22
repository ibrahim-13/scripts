/**
 * @typedef {object} FloatingMenuAction actions for floating menu
 * @property {string} label label for action
 * @property {() => void} handler callback executed when action clicked
 */
/**
 * @typedef {object} FloatingMenuCtrl controller proxy for floating menu
 * @property {number} x x-axis position
 * @property {number} y y-axis position
 * @property {number} offsetX x-axis offset
 * @property {number} offsetY y-axis offset
 * @property {string} text text to display in the floating menu
 * @property {Array<FloatingMenuAction>} actions actions for floating menu
 */
/**
 * Create floating menu
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {FloatingMenuCtrl} Proxy to control floating menu
 */
function CreateFloatingMenu(prefix) {
  const __menuStyleInner = `
#{{idMenu}} {
  padding: 5px;
  position: absolute;
  border: 1px solid cyan;
  border-radius: 7px;
  background-color: crimson;
  box-shadow: 0 4px 10px rgba(0,0,0,0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-family: sans-serif;
  font-size: 16px;
  user-select: none;
  cursor: grab;
}

#{{idMenu}}:active {
  cursor: grabbing;
}

#{{idContextMenu}} {
  position: absolute;
  background-color: black;
  color: white;
  border: 1px solid #ccc;
  padding: 8px;
  border-radius: 4px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.2);
  display: none;
  z-index: 999;
}

#{{idContextMenu}} div {
  padding: 4px 8px;
  cursor: pointer;
}

#{{idContextMenu}} div:hover {
  background-color: #eee;
}
`;

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idMenu = "menu_" + _prefix;
  const idContextMenu = "contextMenu_" + _prefix;
  /**
   * @type {HTMLDivElement}
   */
  let elemMenu = undefined;
  /**
   * @type {HTMLDivElement}
   */
  let elemCtxMenu = undefined;
  let hasLoaded = false;

  /**
   * @type {Array<FloatingMenuAction>}
   */
  const defaultActions = [{ label: 'Hello world', handler: () => alert('hello world!') }];
  /**
   * @type {FloatingMenuCtrl}
   */
  const state = { x: 100, y: 100, offsetX: 0, offsetY: 0, text: 'Menu', actions: defaultActions };

  /**
   * @type {FloatingMenuCtrl}
   */
  const menuState = new Proxy(state, {
    set(target, prop, value) {
      if (prop === 'x') {
        if (value < 0 || value > window.innerWidth - elemMenu.clientWidth) {
          return true;
        }
        if (!!elemMenu) {
          elemMenu.style.left = value + 'px';
        }
      }

      if (prop === 'y') {
        if (value < 0 || value > window.innerHeight - elemMenu.clientHeight) {
          return Reflect.set(target, prop, 0);
        }
        if (!!elemMenu) {
          elemMenu.style.top = value + 'px';
        }
      }

      if (prop === 'text' && !!elemMenu) {
        elemMenu.textContent = String(value);
      }

      if (prop === 'actions' && !!elemCtxMenu) {
        // Refresh with new actions
        elemCtxMenu.innerHTML = '';
        value.forEach(action => {
          const item = document.createElement('div');
          item.textContent = action.label;
          item.onclick = (e) => {
            e.stopPropagation(); // prevent closing before action
            elemCtxMenu.style.display = 'none';
            action.handler();
          };
          elemCtxMenu.appendChild(item);
        });
      }

      return Reflect.set(target, prop, value);
    }
  });

  const init = () => {
    if (hasLoaded) return;
    if (!(document.readyState === 'complete' || document.readyState === 'interactive')) return;

    elemMenu = document.createElement('div');
    elemCtxMenu = document.createElement('div');
    const elemStyle = document.createElement('style');
    elemMenu.id = idMenu;
    elemCtxMenu.id = idContextMenu;
    elemStyle.innerHTML = __menuStyleInner.replaceAll("{{idContextMenu}}", idContextMenu)
      .replaceAll("{{idMenu}}", idMenu);

    document.body.appendChild(elemMenu);
    document.body.appendChild(elemCtxMenu);
    document.body.appendChild(elemStyle);
    hasLoaded = true;

    function startDrag(clientX, clientY) {
      menuState.dragging = true;
      menuState.offsetX = clientX - elemMenu.offsetLeft;
      menuState.offsetY = clientY - elemMenu.offsetTop;
    }

    function onDrag(clientX, clientY) {
      if (menuState.dragging) {
        menuState.x = clientX - menuState.offsetX;
        menuState.y = clientY - menuState.offsetY;
      }
    }

    // Touch drag
    elemMenu.addEventListener('touchstart', e => {
      const touch = e.touches[0];
      startDrag(touch.clientX, touch.clientY);
    });

    // Mouse drag
    elemMenu.addEventListener('mousedown', e => {
      if (e.button !== 2) {
        startDrag(e.clientX, e.clientY);
      }
    });

    document.addEventListener('mousemove', e => onDrag(e.clientX, e.clientY));
    document.addEventListener('mouseup', () => menuState.dragging = false);
    document.addEventListener('touchmove', e => {
      if (menuState.dragging) {
        const touch = e.touches[0];
        onDrag(touch.clientX, touch.clientY);
      }
    });
    document.addEventListener('touchend', () => menuState.dragging = false);

    // Show context menu on right click
    elemMenu.addEventListener('contextmenu', e => {
      e.preventDefault();
      showContextMenu(e.clientX, e.clientY);
    });

    function showContextMenu(x, y) {
      elemCtxMenu.style.left = (x - (elemMenu.clientWidth / 2)) + 'px';
      elemCtxMenu.style.top = y + 'px';
      elemCtxMenu.style.display = 'block';
    }

    // Hide menu on outside click
    document.addEventListener('click', () => {
      elemCtxMenu.style.display = 'none';
    });
    document.addEventListener('contextmenu', e => {
      if (e.target !== elemMenu) {
        elemCtxMenu.style.display = 'none';
      }
    });

    menuState.x = state.x;
    menuState.y = state.y;
    menuState.text = state.text;
    menuState.actions = state.actions;
  };

  if (document.readyState === 'complete' || document.readyState == 'interactive') {
    init();
  } else {
    document.addEventListener('readystatechange', init);
  }

  return menuState;
}