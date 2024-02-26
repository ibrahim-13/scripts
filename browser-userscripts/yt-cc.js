// ==UserScript==
// @name        YT CC
// @namespace   __personal_yt_cc
// @match       https://*.youtube.com/*
// @grant       none
// @noframes
// @version     2024.02.26
// @author      ibrahim.khan
// @description Enable CC
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    ccbtn: "#movie_player div.ytp-chrome-controls button.ytp-subtitles-button.ytp-button",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  preset: {
    // channel_relative_url: 'true'/'false',
    // ex: "/@yt": 'false',
  },
};

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
    clearTimeout(prev_timeout_id);
    prev_timeout_id = setTimeout(func, 500);
  };
}

function yt_enable_cc() {
  var elem_vid = document.querySelector(_conf.elem.video);
  var elem_ccbtn = document.querySelector(_conf.elem.ccbtn);
  var elem_channel = document.querySelector(_conf.elem.channel);
  if (elem_vid && elem_ccbtn && elem_channel) {
    var cc_status = _conf.preset[elem_channel.getAttribute("href")] || 'true';
    if(elem_ccbtn.getAttribute("aria-pressed") === cc_status) {
      return;
    }
    setTimeout(function() {
      var current_cc_status = _conf.preset[elem_channel.getAttribute("href")] || 'true';
      if(elem_ccbtn.getAttribute("aria-pressed") !== current_cc_status) {
        elem_ccbtn.click();
      }
    }, 1000);
  }
}

(function() {
  "use strict";

  const observer = new MutationObserver(with_debounce(yt_enable_cc));

  // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
