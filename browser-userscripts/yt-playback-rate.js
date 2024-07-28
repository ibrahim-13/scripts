// ==UserScript==
// @name        YT Playback
// @namespace   __gh_ibrahim13_yt_playback_rate
// @match       https://*.youtube.com/*
// @version     2024.07.27
// @author      github/ibrahim-13
// @description Increase playback rate of YouTube
// @noframes
// @grant       GM_registerMenuCommand
// @grant       GM_addElement
// @grant       GM_addStyle
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  default_playback_rate: 1.5,
  override_playback: false,
  override_playback_rate: 1,
  preset: {
    // channel_relative_url: playback_rate,
    // ex: "/@yt": 1.25,
  },
};

/**
 * UI
**/

function inject_ui() {
  let isDragging = false;
  GM_addStyle(`
.__us_settings_view{background:black;color:green;font-size: 13px;border:1px solid yellow;padding:7px;position:absolute;top:0px;width:150px;height:150px;z-index:99993;display:none;}
.__us_pb_rate{font-weight:bold;}
.__us_btn{background:green;}
.__us_overlay {position:absolute;cursor:pointer;top:0px;left:0px;width:100%;height:100%;z-index:99992;opacity:0.7;background:black;display:none;}
`)

  const settings = GM_addElement("div", {class: "__us_settings_view"});
  GM_addElement(settings, "h2", { textContent: "settings"});
  GM_addElement(settings, "label", { textContent: "monitor: "});

  const settings_input_monitor = GM_addElement(settings, "input", {
    type: "checkbox",
    checked: _conf.isEnabled,
  });
  settings_input_monitor.addEventListener("change", function(e) {_conf.isEnabled = e.target.checked;});
  GM_addElement(settings, "br", {});

  GM_addElement(settings, "label", { textContent: "default speed: "});
  const settings_span_playback_rate = GM_addElement(settings, "label", {
    class: "__us_pb_rate",
    textContent: String(_conf.override_playback ? _conf.override_playback_rate : _conf.default_playback_rate),
  });
  GM_addElement(settings, "br", {});

  function action_set_rate(rate) {
    if(typeof rate == "string" && rate == "reset") {
      _conf.override_playback_rate = _conf.default_playback_rate;
      _conf.override_playback = false;
      settings_span_playback_rate.innerText = _conf.default_playback_rate;
    } else if(typeof rate == "number") {
      _conf.override_playback_rate = rate;
      _conf.override_playback = true;
      settings_span_playback_rate.innerText = _conf.override_playback_rate;
    }
  }

  GM_addElement(settings, "label", { textContent: "override: "});
  ["reset", 0.75, 1, 1.25, 1.5, 1.75].forEach(function(r) {
    const btn = GM_addElement(settings, "button", {
      class: "__us_btn",
      textContent: String(r),
    });
    btn.onclick = function() {action_set_rate(r);}
  });

  const overlay = GM_addElement("div", { class: "__us_overlay"});
  overlay.addEventListener("click", function() {
    settings.style.display = "none";
    overlay.style.display = "none";
  });

  function action_show_settings() {
    settings.style.left = String((innerWidth - 150) / 2) + "px";
    settings.style.display = "block";
    overlay.style.display = "block";
  }
  GM_registerMenuCommand("Settings", action_show_settings);
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
    if(_conf.override_playback) {
      pbr = _conf.override_playback_rate;
    }
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

  inject_ui();
})();
