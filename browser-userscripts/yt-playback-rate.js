// ==UserScript==
// @name        YT Playback
// @namespace   __gh_ibrahim13_yt_playback_rate
// @match       https://*.youtube.com/*
// @version     2025.5.31
// @author      github/ibrahim-13
// @description Control playback speed of YouTube
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_unregisterMenuCommand
// @grant       GM_getValue
// @grant       GM_setValue
// ==/UserScript==

const _ytpb_conf_init = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  playback_rate: 1,
  last_set_playback_speed: "",
  playback_opt: [0.75, 1, 1.25, 1.5, 2],
  preset: {},
  enabled_storage_key: "ytpb__isEnabled",
  preset_storage_key: "ytpb__preset",
  palyback_storage_key: "ytpb__palyback_rate",
};

const _ytpb_conf_handler = {
  get(target, prop, receiver) {
    return Reflect.get(...arguments);
  },
  set(obj, prop, value) {
    if (prop === "isEnabled") {
      GM_setValue(_ytpb_conf.enabled_storage_key, value);
    } else if (prop === "preset") {
      GM_setValue(_ytpb_conf.preset_storage_key, value);
    } else if (prop === "playback_rate") {
      GM_setValue(_ytpb_conf.palyback_storage_key, value);
    }
    return Reflect.set(...arguments);
  },
};

var _ytpb_conf = new Proxy(_ytpb_conf_init, _ytpb_conf_handler);

/**
 * Utils
**/

const _$ = function(query) { return document.querySelector(query); };

function migrate_storage() {
    for (const k of ["isEnabled", "preset", "palyback_rate"]) {
        const prevVal = GM_getValue(k, null);
        if (!!prevVal) {
            GM_setValue("ytpb__"+k, prevVal);
            GM_setValue(k, null);
            console.log("yt_playback: migrating: "+k);
        }
    }
}

/**
 * App
**/

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

function yt_set_playback_rate() {
  const elem_vid = _$(_ytpb_conf.elem.video);
  const elem_channel = _$(_ytpb_conf.elem.channel);
  if (elem_vid && elem_channel) {
    let pbr = _ytpb_conf.preset[get_channel_id(elem_channel)];
    if (!_ytpb_conf.isEnabled) {
        pbr = 1;
        _ytpb_conf.last_set_playback_speed = pbr + " (paused)";
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

/**
 * UI
**/

let _ytpb_toggle_menu_id;

function action_toggle_pause() {
  if(_ytpb_conf.isEnabled) {
    _ytpb_conf.isEnabled = false;
    GM_unregisterMenuCommand(_ytpb_toggle_menu_id);
    _ytpb_toggle_menu_id = GM_registerMenuCommand("[Stopped] Toggle", action_toggle_pause);
  } else {
    _ytpb_conf.isEnabled = true;
    GM_unregisterMenuCommand(_ytpb_toggle_menu_id);
    _ytpb_toggle_menu_id = GM_registerMenuCommand("[Running] Toggle", action_toggle_pause);
  }
  yt_set_playback_rate();
}

function action_set_playback_rate() {
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

function action_set_channel_playback_rate() {
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
    //_ytpb_conf.preset[channel_id] = spd;
    _ytpb_conf.preset[channel_id] = spd;
  }
  yt_set_playback_rate();
}

function action_show_playback_rate() {
  alert("Playback speed: " + _ytpb_conf.last_set_playback_speed);
}

function menu() {
  GM_registerMenuCommand("Default Speed", action_set_playback_rate);
  GM_registerMenuCommand("Channel Speed", action_set_channel_playback_rate);
  GM_registerMenuCommand("Show Speed", action_show_playback_rate);
  _ytpb_toggle_menu_id = GM_registerMenuCommand(_ytpb_conf.isEnabled ? "[Running] Toggle" : "[Stopped] Toggle", action_toggle_pause);
}

/**
 * Main
**/

(function() {
  "use strict";

  migrate_storage();

  _ytpb_conf.isEnabled = GM_getValue(_ytpb_conf.enabled_storage_key, _ytpb_conf.isEnabled);
  _ytpb_conf.playback_rate = GM_getValue(_ytpb_conf.palyback_storage_key, 1);
  _ytpb_conf.preset = GM_getValue(_ytpb_conf.preset_storage_key, {});

  function ytpb_check() { return _ytpb_conf.isEnabled; };
  const observer = new MutationObserver(with_debounce(yt_set_playback_rate, ytpb_check));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  menu();
})();