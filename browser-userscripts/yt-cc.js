// ==UserScript==
// @name        YT CC
// @namespace   __gh_ibrahim13_yt_cc
// @match       https://*.youtube.com/*
// @version     2024.12.16
// @author      github/ibrahim-13
// @description Enable CC on Youtube videos
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_unregisterMenuCommand
// @grant       GM_getValue
// @grant       GM_setValue
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    ccbtn: "#movie_player div.ytp-chrome-controls button.ytp-subtitles-button.ytp-button",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  enabled_storage_key: "isEnabled",
  last_set_cc: "",
  preset: {},
  preset_storage_key: "preset",
};

/**
 * App
**/

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
    clearTimeout(prev_timeout_id);
    if(!_conf.isEnabled) return;
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

function yt_enable_cc() {
  var elem_vid = document.querySelector(_conf.elem.video);
  var elem_ccbtn = document.querySelector(_conf.elem.ccbtn);
  var elem_channel = document.querySelector(_conf.elem.channel);
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
    let cc_status = _conf.preset[get_channel_id(elem_channel)] || 'true';
    if(elem_ccbtn.getAttribute("aria-pressed") === cc_status) {
      return;
    }
    setTimeout(function() {
      let current_cc_status = _conf.preset[get_channel_id(elem_channel)];
      _conf.last_set_cc = current_cc_status + " (channel)";
      if (!current_cc_status) {
        current_cc_status = 'true';
        _conf.last_set_cc = current_cc_status + " (global)";
      }
      if(elem_ccbtn.getAttribute("aria-pressed") !== current_cc_status) {
        elem_ccbtn.click();
      }
    }, 1000);
  }
}

/**
 * UI
**/

function action_toggle_pause() {
  if(_conf.isEnabled) {
    _conf.isEnabled = false;
    GM_unregisterMenuCommand("Pause");
    GM_registerMenuCommand("Resume", action_toggle_pause);
  } else {
    _conf.isEnabled = true;
    GM_unregisterMenuCommand("Resume");
    GM_registerMenuCommand("Pause", action_toggle_pause);
  }
  GM_setValue(_conf.enabled_storage_key, _conf.isEnabled);
  yt_enable_cc();
}

function action_set_channel_cc() {
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
  const enable = confirm(channel_id + " - Enable CC? :");
  _conf.preset[channel_id] = enable ? 'true' : 'false';
  GM_setValue(_conf.preset_storage_key, _conf.preset);
  yt_enable_cc();
}

function action_show_cc_status() {
  alert("CC Status: " + _conf.last_set_cc);
}

function menu() {
  GM_registerMenuCommand("Channel CC", action_set_channel_cc);
  GM_registerMenuCommand("Status", action_show_cc_status);
  GM_registerMenuCommand(_conf.isEnabled ? "Pause" : "Resume", action_toggle_pause);
}

/**
 * Main
**/

(function() {
  "use strict";

  _conf.isEnabled = GM_getValue(_conf.enabled_storage_key, _conf.isEnabled);

  const observer = new MutationObserver(with_debounce(yt_enable_cc));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  menu();
})();