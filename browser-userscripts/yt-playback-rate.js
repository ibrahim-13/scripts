// ==UserScript==
// @name        YT Playback
// @namespace   __personal_yt_playback_rate
// @match       https://*.youtube.com/*
// @grant       none
// @version     2024.02.26
// @author      ibrahim.khan
// @description Increase playback rate of YouTube
// @noframes
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  default_playback_rate: 1.5,
  preset: {
    // channel_relative_url: playback_rate,
    // ex: "/@yt": 1.25,
  },
};

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
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
})();
