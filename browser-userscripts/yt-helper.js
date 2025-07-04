// ==UserScript==
// @name        YT Helper
// @namespace   __gh_ibrahim13_yt_helper
// @match       https://*.youtube.com/*
// @version     2025.7.4
// @author      github/ibrahim-13
// @description Control playback speed and CC of YouTube videos
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_getValue
// @grant       GM_setValue
// ==/UserScript==

/**
  create proxy handler to store preset data
  presetKey (string): key used to store the preset data
**/
var _preset_hander = function (presetKey) {
  const _presetKey = presetKey || "";
  return {
    get(target, prop, receiver) {
      return Reflect.get(...arguments);
    },
    set(obj, prop, value) {
      const val = Reflect.set(...arguments);
      GM_setValue(_presetKey, obj);
      return val;
    },
    deleteProperty(obj, propKey) {
      const val = Reflect.deleteProperty(obj, propKey);
      GM_setValue(_presetKey, obj);
      return val;
    }
  };
}

/**
  create proxy handler to store specific keys in config object
  prefix (string): prefix added to the key to store value
  keys (string[]): list of keys which will be store
**/
var _value_hander = function (prefix, keys) {
  const _prefix = prefix || "";
  const _keys = keys || [];
  return {
    get(target, prop, receiver) {
      return Reflect.get(...arguments);
    },
    set(obj, prop, value) {
      if (_keys.includes(prop)) {
        GM_setValue(_prefix + "__" + prop, value);
      }
      return Reflect.set(...arguments);
    },
  }
}

const _ytpb_conf_init = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: GM_getValue("ytpb__isEnabled", true),
  playback_rate: GM_getValue("ytpb__palyback_rate", 1),
  last_set_playback_speed: "",
  playback_opt: [0.75, 1, 1.25, 1.5, 2],
  preset: {},
};

var _ytcc_conf_init = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    ccbtn: "#movie_player div.ytp-chrome-controls button.ytp-subtitles-button.ytp-button",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: GM_getValue("ytcc__isEnabled", true),
  last_set_cc: "",
  preset: {},
};

_ytpb_conf_init.preset = new Proxy(GM_getValue("ytpb__preset", {}), _preset_hander("ytpb__preset"));
var _ytpb_conf = new Proxy(_ytpb_conf_init, _value_hander("ytpb", ["isEnabled", "playback_rate"]));

_ytcc_conf_init.preset = new Proxy(GM_getValue("ytcc__preset", {}), _preset_hander("ytcc__preset"));
var _ytcc_conf = new Proxy(_ytpb_conf_init, _value_hander("ytcc", ["isEnabled"]));

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
  const elem_vid = _$(_ytpb_conf.elem.video);
  const elem_channel = _$(_ytpb_conf.elem.channel);
  if (elem_vid && elem_channel) {
    let pbr = _ytpb_conf.preset[get_channel_id(elem_channel)];
    if (!_ytpb_conf.isEnabled) {
        pbr = 1;
        _ytpb_conf.last_set_playback_speed = pbr + " (stopped)";
    } else {
        _ytpb_conf.last_set_playback_speed = pbr + " (channel)";
    }
    if (!pbr) {
      pbr = _ytpb_conf.playback_rate;
      _ytpb_conf.last_set_playback_speed = pbr + " (global)";
    }
    if(pbr != elem_vid.playbackRate) {
      elem_vid.playbackRate = pbr;
    }
  }
}

function yt_enable_cc() {
  var elem_vid = _$(_ytcc_conf.elem.video);
  var elem_ccbtn = _$(_ytcc_conf.elem.ccbtn);
  var elem_channel = _$(_ytcc_conf.elem.channel);
  if (elem_vid && elem_ccbtn && elem_channel) {
	// if video is paused, do nothing
    if (elem_vid.paused) return;
	// check if CC is unavailable
	// if so, then do nothing
    var title = elem_ccbtn.getAttribute("title") || "";
    if(title.toLowerCase().indexOf("unavailable") !== -1) {
      // return because there are no cc
      return;
    }
    let cc_status = _ytcc_conf.preset[get_channel_id(elem_channel)] || 'true';
    if (!_ytcc_conf.isEnabled) {
        cc_status = 'false';
    }
    if(elem_ccbtn.getAttribute("aria-pressed") === cc_status) {
      return;
    }
    setTimeout(function() {
      let current_cc_status = _ytcc_conf.preset[get_channel_id(elem_channel)];
      if (!_ytcc_conf.isEnabled) {
          current_cc_status = 'false';
          _ytcc_conf.last_set_cc = current_cc_status + " (stopped)";
      } else {
          _ytcc_conf.last_set_cc = current_cc_status + " (channel)";
      }
      if (!current_cc_status) {
        current_cc_status = 'true';
        _ytcc_conf.last_set_cc = current_cc_status + " (global)";
      }
      if(elem_ccbtn.getAttribute("aria-pressed") !== current_cc_status) {
        elem_ccbtn.click();
      }
    }, 1000);
  }
}

/**
 * Playback UI
**/

let _ytpb_toggle_menu_id;

function ytpb_action_toggle_pause() {
  if(_ytpb_conf.isEnabled) {
    _ytpb_conf.isEnabled = false;
    GM_registerMenuCommand("[Playback] ✅ Start", ytpb_action_toggle_pause, { id: _ytpb_toggle_menu_id });
  } else {
    _ytpb_conf.isEnabled = true;
    GM_registerMenuCommand("[Playback] 🟥 Stop", ytpb_action_toggle_pause, { id: _ytpb_toggle_menu_id });
  }
  yt_set_playback_rate();
}

function ytpb_action_set_playback_rate() {
  const spd_str = prompt("Speed (" + _ytpb_conf.playback_opt.join(",") + ") :");
  if (isNaN(spd_str)) {
    alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (!_ytpb_conf.playback_opt.includes(spd)) {
    alert("Speed " + spd + " is not allowed, allowed: " + _ytpb_conf.playback_opt.join(","));
    return;
  }
  _ytpb_conf.playback_rate = spd;
  yt_set_playback_rate();
}

function ytpb_action_set_channel_playback_rate() {
  const elem_channel = _$(_ytpb_conf.elem.channel);
  if (!elem_channel) {
    alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    alert("could not find channel id");
    return;
  }
  const spd_str = prompt("Speed (" + _ytpb_conf.playback_opt.join(",") + "), -1 to remove :");
  if (isNaN(spd_str)) {
    alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (spd == -1) {
    delete _ytpb_conf.preset[channel_id];
  } else if (!_ytpb_conf.playback_opt.includes(spd)) {
    alert("Speed " + spd + " is not allowed, allowed: " + _ytpb_conf.playback_opt.join(","));
    return;
  } else {
    _ytpb_conf.preset[channel_id] = spd;
  }
  yt_set_playback_rate();
}

function ytpb_action_show_playback_rate() {
  alert("Playback speed: " + _ytpb_conf.last_set_playback_speed);
}

function ytpb_menu() {
  GM_registerMenuCommand("[Playback] Default Speed", ytpb_action_set_playback_rate);
  GM_registerMenuCommand("[Playback] Channel Speed", ytpb_action_set_channel_playback_rate);
  GM_registerMenuCommand("[Playback] Show Speed", ytpb_action_show_playback_rate);
  _ytpb_toggle_menu_id = GM_registerMenuCommand(_ytpb_conf.isEnabled ? "[Playback] 🟥 Stop" : "[Playback] ✅ Start", ytpb_action_toggle_pause);
}

/**
 * Playback UI
**/

let _ytcc_toggle_menu_id;

function ytcc_action_toggle_pause() {
  if(_ytcc_conf.isEnabled) {
    _ytcc_conf.isEnabled = false;
    GM_registerMenuCommand("[CC] ✅ Start", ytcc_action_toggle_pause, { id: _ytcc_toggle_menu_id });
  } else {
    _ytcc_conf.isEnabled = true;
    GM_registerMenuCommand("[CC] 🟥 Stop", ytcc_action_toggle_pause, { id: _ytcc_toggle_menu_id });
  }
  yt_enable_cc();
}

function ytcc_action_set_channel_cc() {
  const elem_channel = _$(_ytcc_conf.elem.channel);
  if (!elem_channel) {
    alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    alert("could not find channel id");
    return;
  }
  const enable = confirm(channel_id + " - Enable CC? :");
  _ytcc_conf.preset[channel_id] = enable ? 'true' : 'false';
  yt_enable_cc();
}

function ytcc_action_show_cc_status() {
  alert("CC Status: " + _ytcc_conf.last_set_cc);
}

function ytcc_menu() {
  GM_registerMenuCommand("[CC] Channel CC", ytcc_action_set_channel_cc);
  GM_registerMenuCommand("[CC] Status", ytcc_action_show_cc_status);
  _ytcc_toggle_menu_id = GM_registerMenuCommand(_ytcc_conf.isEnabled ? "[CC] 🟥 Stop" : "[CC] ✅ Start", ytcc_action_toggle_pause);
}

/**
 * Main
**/

(function() {
  "use strict";

  function ytpb_check() { return _ytpb_conf.isEnabled; };
  function ytcc_check() { return _ytcc_conf.isEnabled; };
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