// ==UserScript==
// @name        YT Playback
// @namespace   __gh_ibrahim13_yt_playback_rate
// @match       https://*.youtube.com/*
// @version     2024.07.30
// @author      github/ibrahim-13
// @description Increase playback rate of YouTube
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_unregisterMenuCommand
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  default_playback_rate: 1.5,
  preset: {
    // channel_relative_url: playback_rate,
    // ex: "/@yt": 1.25,
  },
};

/**
 * UI
**/

function menu() {
  const init_playback_rate = _conf.default_playback_rate;
  function action_toggle_pause() {
    if(_conf.isEnabled) {
      _conf.isEnabled = false;
      _conf.default_playback_rate = 1;
      yt_set_playback_rate();
      GM_unregisterMenuCommand("Pause");
      GM_registerMenuCommand("Resume", action_toggle_pause);
    } else {
      _conf.isEnabled = true;
      _conf.default_playback_rate = init_playback_rate;
      yt_set_playback_rate();
      GM_unregisterMenuCommand("Resume");
      GM_registerMenuCommand("Pause", action_toggle_pause);
    }
  }
  GM_registerMenuCommand(_conf.isEnabled ? "Pause" : "Resume", action_toggle_pause);
}

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
    if(!_conf.isEnabled) return;
    clearTimeout(prev_timeout_id);
    prev_timeout_id = setTimeout(func, 500);
  };
}

function yt_set_playback_rate() {
  var elem_vid = document.querySelector(_conf.elem.video);
  var elem_channel = document.querySelector(_conf.elem.channel);
  if (elem_vid && elem_channel) {
    var pbr = _conf.preset[elem_channel.getAttribute("href")] || _conf.default_playback_rate;
    if(pbr != elem_vid.playbackRate) {
      elem_vid.playbackRate = pbr;
    }
  }
}

(function() {
  "use strict";

  const observer = new MutationObserver(with_debounce(yt_set_playback_rate));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  menu();
})();
