// ==UserScript==
// @name        YT Playback
// @namespace   __gh_ibrahim13_yt_playback_rate
// @match       https://*.youtube.com/*
// @version     2024.12.15
// @author      github/ibrahim-13
// @description Increase playback rate of YouTube
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_unregisterMenuCommand
// @grant       GM_getValue
// @grant       GM_setValue
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  default_playback_rate: 1,
  playback_rate: 1,
  last_set_playback_speed: "",
  palyback_storage_key: "palyback_rate",
  playback_opt: [0.75, 1, 1.25, 1.5, 2],
  preset: {},
  preset_storage_key: "preset",
};

/**
 * App
**/

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
    if(!_conf.isEnabled) return;
    clearTimeout(prev_timeout_id);
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
  const elem_vid = document.querySelector(_conf.elem.video);
  const elem_channel = document.querySelector(_conf.elem.channel);
  if (elem_vid && elem_channel) {
    let pbr = _conf.preset[get_channel_id(elem_channel)];
    _conf.last_set_playback_speed = pbr + " (channel)";
    if (!pbr) {
      pbr = _conf.playback_rate;
      _conf.last_set_playback_speed = pbr + " (global)";
    }
    if(pbr != elem_vid.playbackRate) {
      elem_vid.playbackRate = pbr;
    }
  }
}

/**
 * UI
**/

function action_toggle_pause() {
  if(_conf.isEnabled) {
    _conf.isEnabled = false;
    _conf.playback_rate = 1;
    yt_set_playback_rate();
    GM_unregisterMenuCommand("Pause");
    GM_registerMenuCommand("Resume", action_toggle_pause);
  } else {
    _conf.isEnabled = true;
    _conf.playback_rate = GM_getValue(_conf.palyback_storage_key, _conf.default_playback_rate);
    yt_set_playback_rate();
    GM_unregisterMenuCommand("Resume");
    GM_registerMenuCommand("Pause", action_toggle_pause);
  }
}

function action_set_playback_rate() {
  const spd_str = prompt("Speed (" + _conf.playback_opt.join(",") + ") :");
  if (isNaN(spd_str)) {
    alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (!_conf.playback_opt.includes(spd)) {
    alert("Speed " + spd + " is not allowed, allowed: " + _conf.playback_opt.join(","));
    return;
  }
  _conf.playback_rate = spd;
  GM_setValue(_conf.palyback_storage_key, spd);
  yt_set_playback_rate();
}

function action_set_channel_playback_rate() {
  const elem_channel = document.querySelector(_conf.elem.channel);
  if (!elem_channel) {
    alert("could not find channel element");
    return;
  }
  const channel_id = get_channel_id(elem_channel);
  if (!channel_id) {
    alert("could not find channel id");
    return;
  }
  const spd_str = prompt("Speed (" + _conf.playback_opt.join(",") + "), -1 to remove :");
  if (isNaN(spd_str)) {
    alert("invalid playback speed");
    return;
  }
  const spd = parseFloat(spd_str)
  if (spd == -1) {
    delete _conf.preset[channel_id];
  } else if (!_conf.playback_opt.includes(spd)) {
    alert("Speed " + spd + " is not allowed, allowed: " + _conf.playback_opt.join(","));
    return;
  } else {
    _conf.preset[channel_id] = spd;
  }
  GM_setValue(_conf.preset_storage_key, _conf.preset);
  yt_set_playback_rate();
}

function action_show_playback_rate() {
  alert("Playback speed: " + _conf.last_set_playback_speed);
}

function menu() {
  GM_registerMenuCommand("Default Speed", action_set_playback_rate);
  GM_registerMenuCommand("Channel Speed", action_set_channel_playback_rate);
  GM_registerMenuCommand("Show Speed", action_show_playback_rate);
  GM_registerMenuCommand(_conf.isEnabled ? "Pause" : "Resume", action_toggle_pause);
}

/**
 * Main
**/

(function() {
  "use strict";

  _conf.playback_rate = GM_getValue(_conf.palyback_storage_key, _conf.default_playback_rate);
  _conf.preset = GM_getValue(_conf.preset_storage_key, {});

  const observer = new MutationObserver(with_debounce(yt_set_playback_rate));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  menu();
})();