// ==UserScript==
// @name         YT Helper
// @namespace    __gh_ibrahim13_yt_helper
// @match        https://*.youtube.com/*
// @version      2.5.6
// @author       github/ibrahim-13
// @description  Control playback speed and CC of YouTube videos
// @noframes
// @grant        GM_registerMenuCommand
// @grant        GM_getValue
// @grant        GM_setValue
// ==/UserScript==

/*****************************************
          START: UI Components
*******************************************/

/**
 * @typedef {object} Option Option for selection
 * @property {string} label Label for option
 * @property {string} value Value for option
 */
/**
 * @typedef {object} OptionCtrl controller proxy for selection dialog
 * @property {boolean} show show or hide dialog
 * @property {string} message message to show in the dialog
 * @property {Array<Option>} options list of options for selection
 * @property {(value: string | undefined) => void} callback callback function that will be triggered
 * @property {(value: string | undefined) => void} exec used internally to execute callback
 */
/**
 * Create confirmation dialog
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {OptionCtrl} Proxy to control confirm dialog
 */
function CreateOptionDialog(prefix) {
  const __confirmDialogInner = `
<style>
  #{{idDialog}} {
    position: fixed;
    top: -75%;
    background-color: black;
    color: white;
    border: 1px solid white;
    font-size: 1.5rem;
  }
  #{{idDialog}} button {
    margin: 7px;
  }
  #{{idMsg}} {
    margin-bottom: 5px;
  }
  #{{idForm}} label {
    padding: 3px;
  }
</style>
<p id="{{idMsg}}">Select an option:</p>
<form id="{{idForm}}">
  <div></div>
  <button id="{{idCancel}}">Cancel</button>
  <button type="submit">Ok</button>
</form>
`;

  const _htmlPolicy = trustedTypes.createPolicy("myEscapePolicy", {
    createHTML: (str) => str,
  });

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idDialog = "confirmDialog_" + _prefix;
  const idMsg = "message_" + _prefix;
  const idForm = "option_form_" + _prefix;
  const idCancel = "option_cancel_" + _prefix;
  const nameOption = "option_" + _prefix;
  /**
   * @type {HTMLDialogElement}
   */
  let elemDialog = undefined;
  /**
   * @type {HTMLParagraphElement}
   */
  let elemMsg = undefined;
  /**
   * @type {HTMLFormElement}
   */
  let elemForm = undefined;
  let elemCancel = undefined;
  let hasLoaded = false;

  /**
   * @type {OptionCtrl}
   */
  const dialogState = {
    show: false,
    message: "Select an option:",
    options: [],
    callback: () => { },
    exec: function (param) {
      if (typeof this.callback == 'function') {
        this.callback(param);
      }
    },
  };

  /**
   * @type {OptionCtrl}
   */
  const dialogProxy = new Proxy(dialogState, {
    set(target, prop, value) {
      if (!hasLoaded) return Reflect.set(target, prop, value);

      if (prop === 'message' && !!elemMsg) {
        elemMsg.innerText = String(value);
      }
      if (prop === 'show' && !!elemDialog) {
        if (!!value) {
          for(const elem of document.querySelectorAll('#' + idForm + ' div input')) {
            if(elem.checked) {
              elem.checked = false;
            }
          }
          elemDialog.showModal();
        } else {
          elemDialog.close();
        }
      }
      if (prop === 'options' && Array.isArray(value) && !!elemForm) {
        const div = document.querySelector('#' + idForm + ' div');
        div.innerHTML = _htmlPolicy.createHTML('');
        value.forEach(i => {
          const input = document.createElement('input');
          input.type = 'radio';
          input.name = nameOption;
          input.value = i.value;
          const label = document.createElement('label');
          label.appendChild(input);
          label.append(i.label);
          div.appendChild(label);
        });
      }

      return Reflect.set(target, prop, value);
    }
  });

  const init = () => {
    if (hasLoaded) return;
    if (!(document.readyState === 'complete' || document.readyState === 'interactive')) return;

    elemDialog = document.createElement('dialog');
    elemDialog.id = idDialog;
    elemDialog.innerHTML = _htmlPolicy.createHTML(__confirmDialogInner.replaceAll("{{idDialog}}", idDialog)
      .replaceAll("{{idMsg}}", idMsg)
      .replaceAll("{{idForm}}", idForm)
      .replaceAll("{{idCancel}}", idCancel));
    document.body.appendChild(elemDialog);
    elemMsg = document.getElementById(idMsg);
    elemForm = document.getElementById(idForm);
    elemCancel = document.getElementById(idCancel);

    hasLoaded = true;

    elemForm.addEventListener('submit', (e) => {
      dialogProxy.show = false;
      e.preventDefault();
      e.stopPropagation();
      const data = new FormData(e.target);
      dialogProxy.exec.apply(dialogProxy, [data.get(nameOption)]);
    });

    elemCancel.addEventListener('click', (e) => {
      dialogProxy.show = false;
      e.preventDefault();
      e.stopPropagation();
    });

    dialogProxy.message = dialogProxy.message;
    dialogProxy.show = dialogProxy.show;
    dialogProxy.options = dialogProxy.options;
  };

  if (document.readyState === 'complete' || document.readyState == 'interactive') {
    init();
  } else {
    document.addEventListener('readystatechange', init);
  }

  return dialogProxy;
}

/**
 * @typedef {object} ConfirmCtrl controller proxy for confirm dialog
 * @property {boolean} show show or hide dialog
 * @property {boolean} noOp no operation mode, only show Yes button and callback is not invoked
 * @property {string} message message to show in the dialog
 * @property {string} textYes text for button Yes
 * @property {string} textNo text for button No
 * @property {(confirm: boolean) => void} callback callback function that will be triggered
 * @property {(confirm: boolean) => void} exec used internally to execute callback
 */
/**
 * Create confirmation dialog
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {ConfirmCtrl} Proxy to control confirm dialog
 */
function CreateConfirmDialog(prefix) {
  const __confirmDialogInner = `
<style>
  #{{idDialog}} {
    position: fixed;
    top: -75%;
    background-color: black;
    color: white;
    border: 1px solid white;
    font-size: 1.5rem;
  }
  #{{idDialog}} button {
    margin: 7px;
  }
  #{{idMsg}} {
    margin-bottom: 5px;
  }
  #{{idForm}} button {
    padding: 3px;
  }
</style>
<p id="{{idMsg}}">Are you sure?</p>
<button id="{{idNo}}">Cancel</button>
<button id="{{idYes}}">Ok</button>
`;

  const _htmlPolicy = trustedTypes.createPolicy("myEscapePolicy", {
    createHTML: (str) => str,
  });

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idDialog = "confirmDialog_" + _prefix;
  const idMsg = "message_" + _prefix;
  const idYes = "yesBtn_" + _prefix;
  const idNo = "noBtn_" + _prefix;
  /**
   * @type {HTMLDialogElement}
   */
  let elemDialog = undefined;
  /**
   * @type {HTMLParagraphElement}
   */
  let elemMsg = undefined;
  /**
   * @type {HTMLButtonElement}
   */
  let elemYes = undefined;
  /**
   * @type {HTMLButtonElement}
   */
  let elemNo = undefined;
  let hasLoaded = false;

  /**
   * @type {ConfirmCtrl}
   */
  const dialogState = {
    show: false,
    message: "Are you sure?",
    textYes: "Yes",
    textNo: "No",
    noOp: false,
    callback: () => { },
    exec: function (param) {
      if (typeof this.callback == 'function') {
        this.callback(param);
      }
    },
  };

  /**
   * @type {ConfirmCtrl}
   */
  const dialogProxy = new Proxy(dialogState, {
    set(target, prop, value) {
      if (!hasLoaded) return Reflect.set(target, prop, value);

      if (prop === 'message' && !!elemMsg) {
        elemMsg.innerText = String(value);
      }
      if (prop === 'show' && !!elemDialog) {
        if (!!value) {
          elemDialog.showModal();
        } else {
          elemDialog.close();
        }
      }
      if (prop === 'textYes' && !!elemYes) {
        elemYes.innerText = String(value);
      }
      if (prop === 'textNo' && !!elemNo) {
        elemNo.innerText = String(value);
      }
      if (prop === 'noOp' && !!elemNo) {
        if(!!value) {
          elemNo.style.display = 'none';
        } else  {
          elemNo.style.display = 'initial';
        }
      }
      return Reflect.set(target, prop, value);
    }
  });

  const init = () => {
    if (hasLoaded) return;
    if (!(document.readyState === 'complete' || document.readyState === 'interactive')) return;

    elemDialog = document.createElement('dialog');
    elemDialog.id = idDialog;
    elemDialog.innerHTML = _htmlPolicy.createHTML(__confirmDialogInner.replaceAll("{{idDialog}}", idDialog)
      .replaceAll("{{idMsg}}", idMsg)
      .replaceAll("{{idYes}}", idYes)
      .replaceAll("{{idNo}}", idNo));
    document.body.appendChild(elemDialog);
    elemMsg = document.getElementById(idMsg);
    elemYes = document.getElementById(idYes);
    elemNo = document.getElementById(idNo);

    hasLoaded = true;

    elemYes.addEventListener('click', () => {
      dialogProxy.show = false;
      if (!dialogProxy.noOp) {
        dialogProxy.exec.apply(dialogProxy, [true]);
      }
    });

    elemNo.addEventListener('click', () => {
      dialogProxy.show = false;
      if (!dialogProxy.noOp) {
        dialogProxy.exec.apply(dialogProxy, [false]);
      }
    });

    dialogProxy.message = dialogProxy.message;
    dialogProxy.show = dialogProxy.show;
  };

  if (document.readyState === 'complete' || document.readyState == 'interactive') {
    init();
  } else {
    document.addEventListener('readystatechange', init);
  }

  return dialogProxy;
}

/**
 * @typedef {object} FloatingMenuAction actions for floating menu
 * @property {string} label label for action
 * @property {() => void} handler callback executed when action clicked
 */
/**
 * @typedef {object} FloatingMenuCtrl controller proxy for floating menu
 * @property {boolean} show show/hide menu
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
  z-index: 9999;
}

#{{idContextMenu}} div {
  padding: 4px 8px;
  cursor: pointer;
}

#{{idContextMenu}} div:hover {
  background-color: #eee;
}
`;

  const _htmlPolicy = trustedTypes.createPolicy("myEscapePolicy", {
    createHTML: (str) => str,
  });

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
      if (prop === 'show' && !!elemMenu) {
        elemMenu.style.display = value ? 'initial' : 'none';
      }

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
        elemCtxMenu.innerHTML = _htmlPolicy.createHTML('');
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
    elemStyle.innerHTML = _htmlPolicy.createHTML(__menuStyleInner.replaceAll("{{idContextMenu}}", idContextMenu)
      .replaceAll("{{idMenu}}", idMenu));

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

/*****************************************
          END: UI Components
*******************************************/

function GM_log(msg) {
  console.log("%c[ YT Helper ]%c " + msg, "color: black; background-color: cyan;", "color: yellow; background-color: red;");
}

/**
  * proxy handler to store data
  * storageKey (string): key used to store the data
**/
var __persistance_handler = function (storageKey) {
  const _key = storageKey || "";
  return {
    get(target, prop, receiver) {
      return Reflect.get(target, prop, receiver);
    },
    set(obj, prop, value) {
      const val = Reflect.set(obj, prop, value);
      GM_setValue(_key, obj);
      return val;
    },
    deleteProperty(obj, propKey) {
      const val = Reflect.deleteProperty(obj, propKey);
      GM_setValue(_key, obj);
      return val;
    },
  };
}

/**
  * create proxy to store data
  * storageKey (string): key used to store the data
  * defaultValue (any): default value to use if no stored value found
**/
var __create_persistant_value = function (storageKey, defaultValue) {
  return new Proxy(GM_getValue(storageKey || "", defaultValue || {}), __persistance_handler(storageKey));
}

const _ytpb_conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    //channel: "#owner #upload-info #channel-name yt-formatted-string a",
    channel: "ytd-structured-description-content-renderer #header.yt-simple-endpoint",
  },
  state: {
    isEnabled: true,
    playback_rate: 1,
  },
  last_set_playback_speed: "",
  playback_opt: [-1, 0.75, 1, 1.25, 1.5, 2],
  preset: {},
};
_ytpb_conf.state = __create_persistant_value("ytpb__state", _ytpb_conf.state);
_ytpb_conf.preset = __create_persistant_value("ytpb__preset", _ytpb_conf.preset);

const _ytcc_conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    ccbtn: "#movie_player div.ytp-chrome-controls button.ytp-subtitles-button.ytp-button",
    //channel: "#owner #upload-info #channel-name yt-formatted-string a",
    channel: "ytd-structured-description-content-renderer #header.yt-simple-endpoint",
  },
  state: {
    isEnabled: true,
  },
  isEnabled: GM_getValue("ytcc__isEnabled", true),
  last_set_cc: "",
  preset: {},
};
_ytcc_conf.state = __create_persistant_value("ytcc__state", _ytpb_conf.state);
_ytcc_conf.preset = __create_persistant_value("ytcc__preset", _ytpb_conf.preset);

const _ui_options = CreateOptionDialog();
_ui_options.show = false;
_ui_options.options = _ytpb_conf.playback_opt.map(i => ({ label: String(i), value: i }));

const _ui_confirm = CreateConfirmDialog();
const _ui_float_menu = CreateFloatingMenu();
_ui_float_menu.text = 'unknown';
_ui_float_menu.x = GM_getValue("yt_helper_menu_x", _ui_float_menu.x);
_ui_float_menu.y = GM_getValue("yt_helper_menu_y", _ui_float_menu.y);
_ui_float_menu.actions = [{
  label: "Save current position",
  handler: () => {
    GM_setValue("yt_helper_menu_x", _ui_float_menu.x);
    GM_setValue("yt_helper_menu_y", _ui_float_menu.y);
  },
}];
document.addEventListener('fullscreenchange', () => {
  if(document.fullscreenElement) {
    _ui_float_menu.show = false;
  } else {
    _ui_float_menu.show = true;
  }
});

const __show_alert = (msg) => {
  _ui_confirm.message = msg;
  _ui_confirm.noOp = true;
  _ui_confirm.textYes = 'Okey';
  _ui_confirm.show = true;
}
const __show_confirm = (msg) => {
  _ui_confirm.message = msg;
  _ui_confirm.noOp = false;
  _ui_confirm.textYes = 'Yes';
  _ui_confirm.textNo = 'No';
  _ui_confirm.show = true;
}

const __upd_menu = () => {
  const status = _ytpb_conf.last_set_playback_speed + " | " + _ytcc_conf.last_set_cc;
  if(_ui_float_menu.text !== status) {
    _ui_float_menu.text = status;
  }
}

/**
 * Utils
**/

const _$ = function(query) { return document.querySelector(query); };

function func_merge(funcs) {
    return function(mutations) {
        for (const f of funcs) {
            f(mutations);
        }
    }
}

function with_debounce(func, check) {
  var prev_timeout_id;
  return function(mutations) {
    clearTimeout(prev_timeout_id);
    if(!check()) return;
    prev_timeout_id = setTimeout(func, 500);
  };
}

function get_channel_id(elem) {
  const id = elem.getAttribute("href") || "";
  if (id.startsWith("/@")) {
    return id.replace("/@", "@");
  }
  return id;
}

/**
 * Core
**/

function yt_set_playback_rate() {
  if (window.location.pathname !== "/watch") {
    _ytpb_conf.last_set_playback_speed = "!page";
    __upd_menu();
    return;
  }

  const elem_vid = _$(_ytpb_conf.elem.video);
  const elem_channel = _$(_ytpb_conf.elem.channel);
  if (elem_vid && elem_channel) {
    const channelId = get_channel_id(elem_channel);
    let pbr = _ytpb_conf.preset[channelId];
    if (!_ytpb_conf.state.isEnabled) {
        pbr = 1;
        _ytpb_conf.last_set_playback_speed = "stopped";
    } else {
        _ytpb_conf.last_set_playback_speed = pbr + " (" + channelId + ")";
    }
    if (!pbr) {
      pbr = _ytpb_conf.state.playback_rate;
      _ytpb_conf.last_set_playback_speed = pbr + " (global)";
    }
    if(pbr != elem_vid.playbackRate) {
      elem_vid.playbackRate = pbr;
      __upd_menu();
    }
  } else {
    _ytpb_conf.last_set_playback_speed = "pb err: selector";
    GM_log("could not find element for vid/channel button selector");
    __upd_menu();
  }
}

function yt_enable_cc() {
  if (window.location.pathname !== "/watch") {
    _ytcc_conf.last_set_cc = "!page";
    __upd_menu();
    return;
  }

  var elem_vid = _$(_ytcc_conf.elem.video);
  var elem_ccbtn = _$(_ytcc_conf.elem.ccbtn);
  var elem_channel = _$(_ytcc_conf.elem.channel);
  if (elem_vid && elem_ccbtn && elem_channel) {
    // if video is paused, do nothing
    if (elem_vid.paused) return;
    // check if CC is unavailable
    // if so, then do nothing
    var airaLabel = elem_ccbtn.getAttribute("aria-label") || "";
    if(airaLabel.indexOf("caption") != -1 && airaLabel.indexOf("unavailable") != -1) {
      //GM_log("returning because there are no cc");
      return;
    }
    let cc_status = _ytcc_conf.preset[get_channel_id(elem_channel)] || 'true';
    if (!_ytcc_conf.state.isEnabled) {
        cc_status = 'false';
    }
    if(elem_ccbtn.getAttribute("aria-pressed") === cc_status) {
      //GM_log("returning because cc button is alread pressed");
      return;
    }
    setTimeout(function() {
      const channelId = get_channel_id(elem_channel);
      let current_cc_status = _ytcc_conf.preset[channelId];
      if (!_ytcc_conf.state.isEnabled) {
          current_cc_status = 'false';
          _ytcc_conf.last_set_cc = "stopped";
      } else {
          _ytcc_conf.last_set_cc = current_cc_status + " (" + channelId + ")";
      }
      if (!current_cc_status) {
        current_cc_status = 'true';
        _ytcc_conf.last_set_cc = current_cc_status + " (global)";
      }
      if(elem_ccbtn.getAttribute("aria-pressed") !== current_cc_status) {
        elem_ccbtn.click();
        __upd_menu();
      }
    }, 1000);
  } else {
    _ytcc_conf.last_set_cc = "cc err: selector";
    GM_log("could not find element for cc button selector");
    __upd_menu();
  }
}

/**
 * Playback UI
**/

let _ytpb_toggle_menu_id;

function ytpb_action_toggle_pause() {
  if(_ytpb_conf.state.isEnabled) {
    _ytpb_conf.state.isEnabled = false;
    GM_registerMenuCommand("[Playback] ✅ Start", ytpb_action_toggle_pause, { id: _ytpb_toggle_menu_id });
  } else {
    _ytpb_conf.state.isEnabled = true;
    GM_registerMenuCommand("[Playback] 🟥 Stop", ytpb_action_toggle_pause, { id: _ytpb_toggle_menu_id });
  }
  yt_set_playback_rate();
}

const __cb_palyback_rate = (spd_str) => {
  if (isNaN(spd_str)) {
    __show_alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (!_ytpb_conf.playback_opt.includes(spd)) {
    __show_alert("Speed " + spd + " is not allowed, allowed: " + _ytpb_conf.playback_opt.join(","));
    return;
  }
  if (spd == -1) {
    spd = 1.0;
  }
  _ytpb_conf.state.playback_rate = spd;
  yt_set_playback_rate();
}

function ytpb_action_set_playback_rate() {
  _ui_options.callback = __cb_palyback_rate;
  _ui_options.message = "Select video speed (global):";
  _ui_options.show = true;
}

const __cb_channel_speed = (spd_str) => {
  const elem_channel = _$(_ytpb_conf.elem.channel);
  const channel_id = get_channel_id(elem_channel);
  if (!spd_str || isNaN(spd_str)) {
    __show_alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (spd == -1) {
    delete _ytpb_conf.preset[channel_id];
  } else {
    _ytpb_conf.preset[channel_id] = spd;
  }
  yt_set_playback_rate();
}

function ytpb_action_set_channel_playback_rate() {
  const elem_channel = _$(_ytpb_conf.elem.channel);
  if (!elem_channel) {
    __show_alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    __show_alert("could not find channel id");
    return;
  }
  _ui_options.callback = __cb_channel_speed;
  _ui_options.message = "Select video speed (" + channel_id + "):";
  _ui_options.show = true;
}

function ytpb_action_show_playback_rate() {
  if (!_ytpb_conf.state.isEnabled) {
    __show_alert("Playback speed: stopped");
    return;
  }
  __show_alert("Playback speed: " + _ytpb_conf.last_set_playback_speed);
}

function ytpb_menu() {
  GM_registerMenuCommand("[Playback] Default Speed", ytpb_action_set_playback_rate);
  GM_registerMenuCommand("[Playback] Channel Speed", ytpb_action_set_channel_playback_rate);
  GM_registerMenuCommand("[Playback] Show Speed", ytpb_action_show_playback_rate);
  _ytpb_toggle_menu_id = GM_registerMenuCommand(_ytpb_conf.state.isEnabled ? "[Playback] 🟥 Stop" : "[Playback] ✅ Start", ytpb_action_toggle_pause);
}

/**
 * Playback UI
**/

let _ytcc_toggle_menu_id;

function ytcc_action_toggle_pause() {
  if(_ytcc_conf.state.isEnabled) {
    _ytcc_conf.state.isEnabled = false;
    GM_registerMenuCommand("[CC] ✅ Start", ytcc_action_toggle_pause, { id: _ytcc_toggle_menu_id });
  } else {
    _ytcc_conf.state.isEnabled = true;
    GM_registerMenuCommand("[CC] 🟥 Stop", ytcc_action_toggle_pause, { id: _ytcc_toggle_menu_id });
  }
  yt_enable_cc();
}

const __cb_channel_cc = (enable) => {
  const elem_channel = _$(_ytcc_conf.elem.channel);
  if (!elem_channel) {
    __show_alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    __show_alert("could not find channel id");
    return;
  }
  _ytcc_conf.preset[channel_id] = enable ? 'true' : 'false';
  yt_enable_cc();
}

function ytcc_action_set_channel_cc() {
  const elem_channel = _$(_ytcc_conf.elem.channel);
  if (!elem_channel) {
    __show_alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    __show_alert("could not find channel id");
    return;
  }
  _ui_confirm.callback = __cb_channel_cc;
  __show_confirm("Enable CC for channel id : " + channel_id);
}

function ytcc_action_show_cc_status() {
  if (!_ytcc_conf.state.isEnabled) {
    __show_alert("CC Status: stopped");
    return;
  }
  __show_alert("CC Status: " + _ytcc_conf.last_set_cc);
}

function ytcc_menu() {
  GM_registerMenuCommand("[CC] Channel CC", ytcc_action_set_channel_cc);
  GM_registerMenuCommand("[CC] Status", ytcc_action_show_cc_status);
  _ytcc_toggle_menu_id = GM_registerMenuCommand(_ytcc_conf.state.isEnabled ? "[CC] 🟥 Stop" : "[CC] ✅ Start", ytcc_action_toggle_pause);
}

/**
 * Main
**/

(function() {
  "use strict";

  function ytpb_check() { return _ytpb_conf.state.isEnabled; }
  function ytcc_check() { return _ytcc_conf.state.isEnabled; }
  const listeners = [with_debounce(yt_set_playback_rate, ytpb_check), with_debounce(yt_enable_cc, ytcc_check)];
  const observer = new MutationObserver(func_merge(listeners));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  ytcc_menu();
  ytpb_menu();
})();